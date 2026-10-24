"""Focused offline tests: no database connections or writes are made."""

import csv
import io
import tempfile
import unittest
from pathlib import Path
from types import SimpleNamespace
from unittest.mock import patch

import psycopg

from src.ingest_orders import COLUMNS, connection_settings, ingest_orders, validate_csv


class IngestOrdersTests(unittest.TestCase):
    def setUp(self):
        directory = tempfile.TemporaryDirectory()
        self.addCleanup(directory.cleanup)
        self.path = Path(directory.name) / "orders.csv"
        self.content = ','.join(COLUMNS) + '\n' + 'same,"",, value ,NULL,"a,b","line\nend",x\n' * 2
        self.path.write_text(self.content, encoding="utf-8")
        self.connect_patch = patch("src.ingest_orders.psycopg.connect")
        self.connect = self.connect_patch.start()
        self.addCleanup(self.connect_patch.stop)
        settings_patch = patch("src.ingest_orders.connection_settings", return_value={})
        settings_patch.start()
        self.addCleanup(settings_patch.stop)
        self.connection = self.connect.return_value.__enter__.return_value
        self.cursor = self.connection.cursor.return_value.__enter__.return_value
        self.cursor.description = [SimpleNamespace(name=name, type_code=25) for name in COLUMNS]
        self.cursor.fetchone.return_value = (2,)
        self.copy = self.cursor.copy.return_value.__enter__.return_value

    def statements(self):
        return [call.args[0].as_string() for call in self.cursor.execute.call_args_list]

    def test_repeated_runs_replace_and_preserve_original_csv(self):
        for _ in range(2):
            self.assertEqual(ingest_orders(self.path, 2), 2)
        statements = self.statements()
        self.assertEqual(statements.count('TRUNCATE TABLE "raw"."orders"'), 2)
        self.assertFalse(any("INSERT INTO" in query for query in statements))
        self.assertEqual(self.copy.write.call_args_list[0].args[0], self.content)
        self.assertEqual(self.connect.return_value.__exit__.call_args.args, (None, None, None))
        self.connect.assert_called_with(autocommit=False)
        self.assertIn("HEADER MATCH", self.cursor.copy.call_args.args[0].as_string())

    def test_custom_target_is_used_in_every_statement(self):
        ingest_orders(self.path, 2, target_schema='test"schema', target_table='orders"test')
        target = '"test""schema"."orders""test"'
        statements = self.statements() + [self.cursor.copy.call_args.args[0].as_string()]
        self.assertEqual(len(statements), 5)
        self.assertTrue(all(target in statement for statement in statements))
        self.assertTrue(all('"raw"."orders"' not in statement for statement in statements))

    def test_bad_csv_is_rejected_before_connecting(self):
        header = ','.join(COLUMNS) + '\n'
        cases = ('wrong\n', header, header + 'short,row\n',
                 header + '"unterminated\n', header + ','.join(['x'] * 9) + '\n')
        for content in cases:
            with self.subTest(content=content):
                self.path.write_text(content, encoding="utf-8")
                with self.assertRaises((ValueError, csv.Error)):
                    ingest_orders(self.path, 2)
        self.connect.assert_not_called()

    def test_wrong_target_schema_is_rejected_before_truncate(self):
        self.cursor.description[0].type_code = 23
        with self.assertRaises(ValueError):
            ingest_orders(self.path, 2)
        self.assertFalse(any("TRUNCATE" in query for query in self.statements()))

    def test_count_mismatch_exits_transaction_with_error(self):
        self.cursor.fetchone.return_value = (1,)
        with self.assertRaises(ValueError):
            ingest_orders(self.path, 2)
        self.assertIs(self.connect.return_value.__exit__.call_args.args[0], ValueError)

    def test_copy_failure_exits_transaction_with_error(self):
        self.copy.write.side_effect = psycopg.DataError("synthetic failure")
        with self.assertRaises(psycopg.DataError):
            ingest_orders(self.path, 2)
        self.assertIs(self.connect.return_value.__exit__.call_args.args[0], psycopg.DataError)
        self.assertFalse(any("count(*)" in query for query in self.statements()))

    def test_validation_rewinds_and_counts_multiline_records(self):
        file = io.StringIO(self.content)
        validate_csv(file, 2)
        self.assertEqual(file.tell(), 0)


class ConnectionSettingsTests(unittest.TestCase):
    @patch.dict("os.environ", {
        "PGUSER": "synthetic_user", "PGDATABASE": "synthetic_db",
        "PGPASSWORD": "synthetic_password",
    }, clear=True)
    def test_environment_credentials_and_local_defaults(self):
        self.assertEqual(connection_settings(), {
            "user": "synthetic_user", "dbname": "synthetic_db",
            "password": "synthetic_password", "host": "127.0.0.1", "port": "5432",
        })


if __name__ == "__main__":
    unittest.main()
