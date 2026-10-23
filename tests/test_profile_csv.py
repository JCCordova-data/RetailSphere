import io
import tempfile
import unittest
from contextlib import redirect_stderr, redirect_stdout
from pathlib import Path

from src.profile_csv import main, profile_csv


class CSVProfilerTests(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.directory.cleanup)
        self.path = Path(self.directory.name) / "sample.csv"

    def write_csv(self, content):
        self.path.write_text(content, encoding="utf-8")

    def test_dynamic_columns_and_all_missing_value_types(self):
        self.write_csv('sku,description,quantity\nA,Widget,0\nB,,2\nC, \t ,\nD\n')
        self.assertEqual(profile_csv(self.path), {
            "total_rows": 4,
            "duplicate_rows": 0,
            "columns": ["sku", "description", "quantity"],
            "missing_counts": {"sku": 0, "description": 3, "quantity": 2},
        })

    def test_quoted_commas_and_multiline_values(self):
        self.write_csv('name,note\n"Smith, Jane","first\nsecond"\n'
                       '"Smith, Jane","first\nsecond"\n'
                       '"Smith, Jane","first, second"\n')
        profile = profile_csv(self.path)
        self.assertEqual(profile["total_rows"], 3)
        self.assertEqual(profile["duplicate_rows"], 1)
        self.assertEqual(profile["missing_counts"], {"name": 0, "note": 0})

    def test_exact_duplicates_count_each_occurrence_after_first(self):
        self.write_csv("id,value\n1,apple\n2,pear\n1,apple\n1,apple\n2,pear\n")
        profile = profile_csv(self.path)
        self.assertEqual(profile["total_rows"], 5)
        self.assertEqual(profile["duplicate_rows"], 3)

    def test_repeated_primary_key_values_with_different_fields_are_unique(self):
        self.write_csv("id,value\n1,apple\n1,pear\n1,Apple\n1,apple \n")
        self.assertEqual(profile_csv(self.path)["duplicate_rows"], 0)

    def test_all_fields_participate_even_with_repeated_headers_or_extra_fields(self):
        for content in ("id,id\n1,A\n2,A\n1,A\n",
                        "id,value\n1,A,x\n1,A,y\n1,A,x\n"):
            with self.subTest(content=content):
                self.write_csv(content)
                self.assertEqual(profile_csv(self.path)["duplicate_rows"], 1)

    def test_missing_values_are_counted_on_duplicate_rows_without_normalizing(self):
        self.write_csv("id,value\n1,\n1,\n1, \n1\n\n")
        profile = profile_csv(self.path)
        self.assertEqual(profile["total_rows"], 4)
        self.assertEqual(profile["duplicate_rows"], 1)
        self.assertEqual(profile["missing_counts"], {"id": 0, "value": 4})

    def test_header_only_has_zero_rows_and_counts(self):
        self.write_csv("alpha,beta\n")
        self.assertEqual(profile_csv(self.path), {
            "total_rows": 0,
            "duplicate_rows": 0,
            "columns": ["alpha", "beta"],
            "missing_counts": {"alpha": 0, "beta": 0},
        })

    def test_empty_csv_is_rejected(self):
        self.write_csv("")
        with self.assertRaisesRegex(ValueError, "empty or has no header"):
            profile_csv(self.path)

    def test_missing_file_is_rejected(self):
        with self.assertRaises(FileNotFoundError):
            profile_csv(self.path)

    def test_cli_prints_summary(self):
        self.write_csv("color,size\nblue,\nblue,\n")
        output = io.StringIO()
        with redirect_stdout(output):
            main([str(self.path)])
        self.assertEqual(output.getvalue(), (
            "Total data rows: 2\nExact duplicate rows: 1\nColumns: color, size\n"
            "Missing values by column:\n  color: 0\n  size: 2\n"
        ))

    def test_cli_reports_input_errors_without_traceback(self):
        for content in (None, ""):
            with self.subTest(content=content):
                if content is not None:
                    self.write_csv(content)
                errors = io.StringIO()
                with redirect_stderr(errors), self.assertRaises(SystemExit) as raised:
                    main([str(self.path)])
                self.assertEqual(raised.exception.code, 2)
                self.assertIn("error:", errors.getvalue())
                self.assertNotIn("Traceback", errors.getvalue())


if __name__ == "__main__":
    unittest.main()
