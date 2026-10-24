"""Offline RS-021 tests: every database boundary is mocked."""

import csv
import io
import re
import tempfile
import unittest
from contextlib import redirect_stderr, redirect_stdout
from dataclasses import replace
from pathlib import Path
from types import SimpleNamespace
from unittest.mock import call, patch

import psycopg

from src.ingest_raw import ingest_dataset, main, validate_csv
from src.raw_datasets import DATASETS


class DatasetContractTests(unittest.TestCase):
    def test_all_nine_sources_targets_and_expected_counts(self):
        expected = {
            "customers": 99_441, "geolocation": 1_000_163,
            "order_items": 112_650, "order_payments": 103_886,
            "order_reviews": 99_224, "orders": 99_441,
            "products": 32_951, "sellers": 3_095,
            "product_category_name_translation": 71,
        }
        self.assertEqual({name: config.expected_rows for name, config in DATASETS.items()},
                         expected)
        for name, config in DATASETS.items():
            with self.subTest(dataset=name):
                filename = (f"olist_{name}_dataset.csv" if name != "product_category_name_translation"
                            else "product_category_name_translation.csv")
                self.assertEqual(config.source_csv, filename)
                self.assertEqual((config.target_schema, config.target_table), ("raw", name))
                self.assertEqual(len(set(config.columns)), len(config.columns))
        self.assertIn("product_name_lenght", DATASETS["products"].columns)
        self.assertIn("product_description_lenght", DATASETS["products"].columns)

    def test_versioned_ddl_matches_exactly_the_eight_missing_contracts(self):
        # Inspect SQL as text only; never execute it or connect to PostgreSQL.
        path = Path(__file__).resolve().parents[1] / "sql/021_create_raw_tables.sql"
        ddl = re.sub(r"--[^\n]*", "", path.read_text(encoding="utf-8"))
        tables = re.findall(r"CREATE TABLE raw\.(\w+)\s*\((.*?)\);", ddl, re.S)
        self.assertEqual(len(tables), 8)
        self.assertEqual({name for name, _ in tables}, set(DATASETS) - {"orders"})
        for name, definitions in tables:
            self.assertEqual(
                [column.split() for column in definitions.split(",")],
                [[column, "TEXT"] for column in DATASETS[name].columns],
            )
        self.assertTrue(ddl.strip().startswith("BEGIN;"))
        self.assertTrue(ddl.strip().endswith("COMMIT;"))
        self.assertNotRegex(ddl.upper(), r"\b(ALTER|DROP|TRUNCATE|INSERT|UPDATE|DELETE)\b")


class IngestRawTests(unittest.TestCase):
    def setUp(self):
        directory = tempfile.TemporaryDirectory()
        self.addCleanup(directory.cleanup)
        self.path = Path(directory.name) / "synthetic.csv"
        patcher = patch("src.ingest_raw.psycopg.connect")
        self.connect = patcher.start()
        self.addCleanup(patcher.stop)
        patcher = patch("src.ingest_raw.connection_settings", return_value={})
        self.settings = patcher.start()
        self.addCleanup(patcher.stop)
        self.connection = self.connect.return_value.__enter__.return_value
        self.cursor = self.connection.cursor.return_value.__enter__.return_value
        self.copy = self.cursor.copy.return_value.__enter__.return_value

    def prepare(self, dataset, content=None, count=2):
        self.cursor.description = [SimpleNamespace(name=name, type_code=25)
                                   for name in dataset.columns]
        self.cursor.fetchone.return_value = (count,)
        if content is None:
            record = ['00123', 'ação, "São Paulo"\r\n segunda linha']
            record += [" value ", "NULL", "", "0", "1.2300", "dup", "x"]
            output = io.StringIO(newline="")
            writer = csv.writer(output, lineterminator="\r\n")
            writer.writerow(dataset.columns)
            writer.writerows([record[:len(dataset.columns)]] * count)
            content = output.getvalue()
        self.path.write_bytes(content.encode("utf-8"))
        return content

    def statements(self):
        return [item.args[0].as_string() for item in self.cursor.execute.call_args_list]

    def test_every_dataset_replaces_repeatedly_and_streams_original_text(self):
        for dataset in DATASETS.values():
            with self.subTest(dataset=dataset.target_table):
                self.cursor.reset_mock()
                self.copy.reset_mock()
                content = self.prepare(dataset)
                for _ in range(2):
                    self.assertEqual(ingest_dataset(dataset, self.path, 2), 2)
                target = f'"raw"."{dataset.target_table}"'
                self.assertEqual(self.statements(), [
                    f"LOCK TABLE {target} IN ACCESS EXCLUSIVE MODE",
                    f"SELECT * FROM {target} LIMIT 0",
                    f"TRUNCATE TABLE {target}",
                    f"SELECT count(*) FROM {target}",
                ] * 2)
                self.assertEqual(self.copy.write.call_args_list, [call(content), call(content)])
                statement = self.cursor.copy.call_args.args[0].as_string()
                self.assertIn(f"COPY {target}", statement)
                for column in dataset.columns:
                    self.assertIn(f'"{column}"', statement)
                self.assertIn("FORMAT CSV, HEADER MATCH", statement)
                self.connect.assert_called_with(autocommit=False)
                self.assertEqual(self.connect.return_value.__exit__.call_args.args,
                                 (None, None, None))

    def test_invalid_csv_for_each_dataset_fails_before_settings_or_connection(self):
        for dataset in DATASETS.values():
            header = ",".join(dataset.columns) + "\n"
            valid_row = ",".join(["x"] * len(dataset.columns)) + "\n"
            cases = ("", "wrong\n", header, header + "short\n",
                     header + valid_row + "\n", header + '"unterminated\n',
                     header + valid_row.rstrip("\n") + ",extra\n",
                     ",".join(reversed(dataset.columns)) + "\n" + valid_row)
            for content in cases:
                with self.subTest(dataset=dataset.target_table, content=content):
                    self.prepare(dataset, content)
                    with self.assertRaises((ValueError, csv.Error)):
                        ingest_dataset(dataset, self.path, 2)
        self.settings.assert_not_called()
        self.connect.assert_not_called()

    def test_schema_mismatches_fail_before_truncate_and_copy(self):
        dataset = DATASETS["products"]
        for kind in ("order", "name", "type", "missing", "extra"):
            with self.subTest(kind=kind):
                self.cursor.reset_mock()
                self.prepare(dataset)
                if kind == "order":
                    self.cursor.description.reverse()
                elif kind == "name":
                    self.cursor.description[2].name = "product_name_length"
                elif kind == "type":
                    self.cursor.description[0].type_code = 23
                elif kind == "missing":
                    self.cursor.description.pop()
                else:
                    self.cursor.description.append(SimpleNamespace(name="extra", type_code=25))
                with self.assertRaises(ValueError):
                    ingest_dataset(dataset, self.path, 2)
                self.assertFalse(any("TRUNCATE" in query for query in self.statements()))
                self.cursor.copy.assert_not_called()
                self.assertIs(self.connect.return_value.__exit__.call_args.args[0], ValueError)

    def test_copy_or_final_count_error_propagates_to_transaction_context(self):
        dataset = DATASETS["order_reviews"]
        for failure in ("copy", "count", "count_query"):
            with self.subTest(failure=failure):
                self.cursor.reset_mock(side_effect=True)
                self.copy.reset_mock(side_effect=True)
                self.prepare(dataset)
                if failure == "copy":
                    self.copy.write.side_effect = psycopg.DataError("synthetic failure")
                elif failure == "count":
                    self.cursor.fetchone.return_value = (1,)
                else:
                    self.cursor.execute.side_effect = [None, None, None, psycopg.DataError()]
                error = ValueError if failure == "count" else psycopg.DataError
                with self.assertRaises(error):
                    ingest_dataset(dataset, self.path, 2)
                self.assertIs(self.connect.return_value.__exit__.call_args.args[0], error)

    def test_defaults_use_configured_source_and_count(self):
        dataset = replace(DATASETS["sellers"], expected_rows=2)
        self.prepare(dataset)
        with patch("src.ingest_raw.RAW_DIRECTORY", self.path.parent):
            self.path.rename(self.path.parent / dataset.source_csv)
            self.assertEqual(ingest_dataset(dataset), 2)

    def test_custom_target_quotes_identifiers_in_all_statements(self):
        dataset = DATASETS["sellers"]
        self.prepare(dataset)
        ingest_dataset(dataset, self.path, 2, 'test"schema', 'test"table')
        statements = self.statements() + [self.cursor.copy.call_args.args[0].as_string()]
        self.assertTrue(all('"test""schema"."test""table"' in query for query in statements))
        self.assertTrue(all('"raw".' not in query for query in statements))

    def test_large_bom_csv_is_streamed_without_rewriting_empty_fields(self):
        dataset = DATASETS["order_reviews"]
        content = (",".join(dataset.columns) + '\r\n001,"",, value ,NULL,"'
                   + "á" * 70_000 + '\r\nend",x\r\n')
        self.prepare(dataset, "\ufeff" + content, count=1)
        self.assertEqual(ingest_dataset(dataset, self.path, 1), 1)
        chunks = [item.args[0] for item in self.copy.write.call_args_list]
        self.assertGreater(len(chunks), 1)
        self.assertTrue(all(len(chunk) <= 64 * 1024 for chunk in chunks))
        self.assertEqual("".join(chunks), content)

    def test_negative_counts_and_missing_files_do_not_connect(self):
        dataset = DATASETS["customers"]
        with self.assertRaises(ValueError):
            ingest_dataset(dataset, self.path, -1)
        with self.assertRaises(FileNotFoundError):
            ingest_dataset(dataset, self.path)
        self.connect.assert_not_called()

    def test_validation_counts_logical_rows_and_rewinds(self):
        file = io.StringIO('a,b\n"line\nend", x \n"line\nend", x \n')
        validate_csv(file, 2, ("a", "b"))
        self.assertEqual(file.tell(), 0)
        validate_csv(io.StringIO("a,b\n"), 0, ("a", "b"))


class RawCLITests(unittest.TestCase):
    def setUp(self):
        directory = tempfile.TemporaryDirectory()
        self.addCleanup(directory.cleanup)
        self.directory = Path(directory.name)
        # Small contracts and synthetic files; never read data/raw in unit tests.
        self.datasets = {name: replace(config, expected_rows=2)
                         for name, config in DATASETS.items()}
        for config in self.datasets.values():
            (self.directory / config.source_csv).write_text(
                ",".join(config.columns) + "\n" + ",".join(["x"] * len(config.columns)) + "\n"
                + ",".join(["x"] * len(config.columns)) + "\n", encoding="utf-8")
        for name, value in (("DATASETS", self.datasets), ("RAW_DIRECTORY", self.directory)):
            patcher = patch("src.ingest_raw." + name, value)
            patcher.start()
            self.addCleanup(patcher.stop)
        patcher = patch("src.ingest_raw.psycopg.connect")
        self.connect = patcher.start()
        self.addCleanup(patcher.stop)

    def test_missing_replacement_flag_unknown_name_or_conflicting_modes_fail(self):
        for arguments in (["customers"], ["unknown", "--replace"],
                          ["all", "--replace", "--dry-run"]):
            with self.subTest(arguments=arguments), redirect_stderr(io.StringIO()):
                with self.assertRaises(SystemExit) as error:
                    main(arguments)
                self.assertEqual(error.exception.code, 2)
        self.connect.assert_not_called()

    def test_dry_run_validates_all_without_credentials_or_connection(self):
        output = io.StringIO()
        with patch.dict("os.environ", {}, clear=True), redirect_stdout(output):
            main(["all", "--dry-run", "--source-dir", str(self.directory)])
        self.connect.assert_not_called()
        for name in DATASETS:
            self.assertIn(f"raw.{name}", output.getvalue())
        self.assertEqual(output.getvalue().count("Validated 2 rows"), 9)

    def test_dry_run_actually_rejects_bad_input(self):
        (self.directory / self.datasets["customers"].source_csv).write_text("wrong\n")
        with redirect_stdout(io.StringIO()), self.assertRaises(SystemExit) as error:
            main(["customers", "--dry-run"])
        self.assertIn("no database connection", str(error.exception))
        self.connect.assert_not_called()

    def test_replace_dispatches_one_or_all_with_explicit_targets(self):
        for name in ("sellers", "all"):
            with self.subTest(name=name), patch("src.ingest_raw.ingest_dataset", return_value=2) as load:
                output = io.StringIO()
                with redirect_stdout(output):
                    main([name, "--replace"])
                selected = self.datasets if name == "all" else {name: self.datasets[name]}
                self.assertEqual(load.call_args_list, [
                    call(config, self.directory / config.source_csv) for config in selected.values()
                ])
                self.assertIn("REPLACE (TRUNCATE + COPY)", output.getvalue())
                for table in selected:
                    self.assertIn(f"raw.{table}", output.getvalue())
                self.assertEqual(output.getvalue().count("; committed."), len(selected))
        self.connect.assert_not_called()

    def test_all_stops_on_first_failure_and_redacts_driver_details(self):
        output = io.StringIO()
        failure = psycopg.DataError("sensitive connection or CSV details")
        with patch("src.ingest_raw.ingest_dataset", side_effect=[2, failure]) as load:
            with redirect_stdout(output), self.assertRaises(SystemExit) as error:
                main(["all", "--replace"])
        self.assertEqual(load.call_count, 2)
        self.assertIn("Earlier datasets may already be committed", str(error.exception))
        self.assertNotIn(str(failure), output.getvalue() + str(error.exception))
        self.assertEqual(output.getvalue().count("; committed."), 1)
        self.connect.assert_not_called()


if __name__ == "__main__":
    unittest.main()
