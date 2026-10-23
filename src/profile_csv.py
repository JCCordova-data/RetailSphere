"""Count rows and missing values in a CSV using only the standard library."""

import argparse
import csv


def profile_csv(file_path):
    """Return column names, row count, and missing counts without storing rows."""
    with open(file_path, encoding="utf-8-sig", newline="") as file:
        reader = csv.DictReader(file)
        columns = reader.fieldnames
        if not columns:
            raise ValueError("CSV is empty or has no header.")

        total_rows = 0
        missing_counts = {column: 0 for column in columns}
        for row in reader:
            total_rows += 1
            for column in columns:
                value = row[column]
                # DictReader supplies None when a row has fewer fields.
                if value is None or value.strip() == "":
                    missing_counts[column] += 1

    return {
        "total_rows": total_rows,
        "columns": columns,
        "missing_counts": missing_counts,
    }


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("file_path", help="Path to a UTF-8 CSV with a header row")
    args = parser.parse_args(argv)

    try:
        profile = profile_csv(args.file_path)
    except (OSError, ValueError, csv.Error) as error:
        parser.error(str(error))

    print(f"Total data rows: {profile['total_rows']}")
    print(f"Columns: {', '.join(profile['columns'])}")
    print("Missing values by column:")
    for column, count in profile["missing_counts"].items():
        print(f"  {column}: {count}")


if __name__ == "__main__":
    main()
