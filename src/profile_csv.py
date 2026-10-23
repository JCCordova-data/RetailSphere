"""Count rows, exact duplicates, and missing values in a CSV."""

import argparse
import csv


def profile_csv(file_path):
    """Profile parsed values, retaining each unique row for exact comparison.

    Memory grows with the number and size of unique rows: the set stores full
    tuples, not just hashes, so hash collisions cannot cause false duplicates.
    Values are not stripped or otherwise normalized for duplicate detection.
    """
    with open(file_path, encoding="utf-8-sig", newline="") as file:
        reader = csv.reader(file)
        columns = next(reader, None)
        if not columns:
            raise ValueError("CSV is empty or has no header.")

        total_rows = 0
        duplicate_rows = 0
        seen_rows = set()
        missing_counts = {column: 0 for column in columns}
        for values in reader:
            # Match DictReader's handling of blank physical records.
            if not values:
                continue
            total_rows += 1
            row_key = tuple(values)
            if row_key in seen_rows:
                duplicate_rows += 1
            else:
                seen_rows.add(row_key)
            # Keep the existing missing-value behavior for short records.
            padded_values = values + [None] * max(0, len(columns) - len(values))
            row = dict(zip(columns, padded_values))
            for column in columns:
                value = row[column]
                if value is None or value.strip() == "":
                    missing_counts[column] += 1

    return {
        "total_rows": total_rows,
        "duplicate_rows": duplicate_rows,
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
    print(f"Exact duplicate rows: {profile['duplicate_rows']}")
    print(f"Columns: {', '.join(profile['columns'])}")
    print("Missing values by column:")
    for column, count in profile["missing_counts"].items():
        print(f"  {column}: {count}")


if __name__ == "__main__":
    main()
