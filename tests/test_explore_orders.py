import csv
import io
import unittest
from contextlib import redirect_stdout
from unittest.mock import mock_open, patch

from src.explore_orders import main


class LateDeliveryTests(unittest.TestCase):
    def run_records(self, records):
        dataset = io.StringIO()
        writer = csv.writer(dataset)
        writer.writerow([
            "order_id", "order_status", "order_purchase_timestamp",
            "order_delivered_customer_date", "order_estimated_delivery_date",
        ])
        for index, (status, actual, estimated) in enumerate(records):
            writer.writerow([str(index), status, "", actual, estimated])
        output = io.StringIO()
        with patch("builtins.open", mock_open(read_data=dataset.getvalue())):
            with redirect_stdout(output):
                main()
        return output.getvalue()

    def test_valid_invalid_missing_and_non_delivered_records(self):
        output = self.run_records([
            ("delivered", "2018-01-02 00:00:00", "2018-01-01 23:59:59"),
            ("delivered", "2018-01-01 23:59:59", "2018-01-01 00:00:00"),
            ("delivered", "2017-12-31 00:00:00", "2018-01-01 00:00:00"),
            ("delivered", "invalid", "2018-01-01 00:00:00"),
            ("delivered", "2018-01-01 00:00:00", "2018-02-30 00:00:00"),
            ("delivered", "invalid", "invalid"),
            ("delivered", "", "2018-01-01 00:00:00"),
            ("delivered", "2018-01-01 00:00:00", "   "),
            ("canceled", "invalid", "invalid"),
        ])
        self.assertIn("Eligible Deliveries: 3\n", output)
        self.assertIn("Late Deliveries: 1\n", output)
        self.assertIn("Late Delivery Rate: 33.33%\n", output)
        self.assertIn("Excluded Due to Invalid Dates: 3\n", output)

    def test_all_invalid_dates_leave_no_eligible_deliveries(self):
        output = self.run_records([
            ("delivered", "invalid", "2018-01-01 00:00:00"),
            ("delivered", "2018-01-01 00:00:00", "invalid"),
        ])
        self.assertIn("Eligible Deliveries: 0\n", output)
        self.assertIn("Late Deliveries: 0\n", output)
        self.assertIn("Late Delivery Rate: 0.00%\n", output)
        self.assertIn("Excluded Due to Invalid Dates: 2\n", output)


if __name__ == "__main__":
    unittest.main()
