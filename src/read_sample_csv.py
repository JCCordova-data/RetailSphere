import csv

def main():
    with open("tests/sample_orders.csv", "r", encoding="utf-8", newline="") as file:
        reader = csv.DictReader(file)

        expected_columns = ["order_id", "customer_id", "order_status"]

        if reader.fieldnames == expected_columns:
            print("OK: Columns validated")
            for row in reader:
                if row['order_status'] is None or row['order_status'].strip() == "":
                    print(f"ERROR: {row['order_id']} has an empty status")
                    continue
                print(row)
        else:
            print("ERROR: The columns are different")
            return

if __name__ == "__main__":
    main()