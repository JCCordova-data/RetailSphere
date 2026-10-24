"""Opt-in RS-020 tests; these create, truncate and drop ONLY a unique test table.

Manual prerequisites: PostgreSQL 18, a dedicated database ending in _test,
a pre-created schema rs020_test, and a restricted login with USAGE/CREATE on
that schema and no table or column privileges on raw.orders. Do not use a
production database or login. No PG* application settings are used as fallback.
Set RS020_RUN_INTEGRATION=1 and all RS020_TEST_PG{HOST,PORT,DATABASE,USER,PASSWORD}
variables, then run this module explicitly with unittest discovery.
"""

import os
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch
from uuid import uuid4

import psycopg
from psycopg import sql

from src.ingest_orders import COLUMNS, ingest_orders


SCHEMA = "rs020_test"


def test_settings():
    settings = {}
    for field in ("host", "port", "database", "user", "password"):
        value = os.environ.get("RS020_TEST_PG" + field.upper())
        if not value or not value.strip():
            raise RuntimeError("All RS020_TEST_PG* connection settings are required.")
        settings["dbname" if field == "database" else field] = value
    if not settings["dbname"].endswith("_test"):
        raise RuntimeError("The dedicated database name must end in _test.")
    settings.update(connect_timeout=5, options="")
    return settings


@unittest.skipUnless(os.environ.get("RS020_RUN_INTEGRATION") == "1",
                     "RS-020 integration tests require explicit opt-in")
class IngestOrdersIntegrationTests(unittest.TestCase):
    def setUp(self):
        self.settings = test_settings()  # Missing configuration fails before connecting.
        self.table = "orders_" + uuid4().hex
        self.target = sql.Identifier(SCHEMA, self.table)
        # Complete safety checks before any DDL or data writes.
        with psycopg.connect(**self.settings) as connection:
            with connection.cursor() as cursor:
                cursor.execute("SET TRANSACTION READ ONLY")
                cursor.execute("SELECT current_database(), rolsuper FROM pg_roles "
                               "WHERE rolname = current_user")
                database, superuser = cursor.fetchone()
                if database != self.settings["dbname"] or superuser:
                    raise RuntimeError("Require the dedicated database and a non-superuser login.")
                cursor.execute("SELECT to_regclass('raw.orders')")
                raw_orders = cursor.fetchone()[0]
                if raw_orders is not None:
                    cursor.execute(
                        "SELECT has_table_privilege(%s, %s) OR "
                        "has_any_column_privilege(%s, 'SELECT,INSERT,UPDATE,REFERENCES')",
                        (raw_orders, "SELECT,INSERT,UPDATE,DELETE,TRUNCATE,REFERENCES,TRIGGER,MAINTAIN",
                         raw_orders))
                    if cursor.fetchone()[0]:
                        raise RuntimeError("Test login must have no privileges on raw.orders.")
                cursor.execute("SELECT has_schema_privilege(%s, 'USAGE') AND "
                               "has_schema_privilege(%s, 'CREATE')", (SCHEMA, SCHEMA))
                if not cursor.fetchone()[0]:
                    raise RuntimeError("Pre-create rs020_test with USAGE and CREATE for the test login.")

        directory = tempfile.TemporaryDirectory()
        self.addCleanup(directory.cleanup)
        self.path = Path(directory.name) / "orders.csv"
        columns = sql.SQL(", ").join(
            sql.SQL("{} TEXT").format(sql.Identifier(name)) for name in COLUMNS)
        with psycopg.connect(**self.settings) as connection:
            connection.execute(sql.SQL(
                "CREATE TABLE {} ({}, CHECK (order_id <> 'reject'))"
            ).format(self.target, columns))
        self.addCleanup(self.drop_table)

    def drop_table(self):
        # Exact object created by this test; never drop schemas or use CASCADE.
        with psycopg.connect(**self.settings) as connection:
            connection.execute(sql.SQL("DROP TABLE {}").format(self.target))

    def load(self, rows):
        self.path.write_text(",".join(COLUMNS) + "\n" + rows, encoding="utf-8")
        # Only configuration is patched; connections and PostgreSQL remain real.
        with patch("src.ingest_orders.connection_settings", return_value=self.settings):
            return ingest_orders(self.path, 2, target_schema=SCHEMA, target_table=self.table)

    def read_rows(self):
        # Independent connection verifies committed state, including after rollback.
        with psycopg.connect(**self.settings) as connection:
            return connection.execute(sql.SQL("SELECT * FROM {}").format(self.target)).fetchall()

    def test_success_repeat_and_copy_rollback(self):
        rows = 'same,"",, value ,NULL,"a,b","line\nend",x\n' * 2
        expected = [("same", "", None, " value ", "NULL", "a,b", "line\nend", "x")] * 2
        self.assertEqual(self.load(rows), 2)
        self.assertCountEqual(self.read_rows(), expected)
        self.assertEqual(self.load(rows), 2)
        self.assertCountEqual(self.read_rows(), expected)

        bad_rows = "new,c,s,t,a,b,d,e\nreject,c,s,t,a,b,d,e\n"
        with self.assertRaises(psycopg.errors.CheckViolation):
            self.load(bad_rows)
        self.assertCountEqual(self.read_rows(), expected)


if __name__ == "__main__":
    unittest.main()
