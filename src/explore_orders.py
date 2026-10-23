import csv
from datetime import datetime


def main():
    #Opening the orders data set as reader
    with open("data/raw/olist_orders_dataset.csv", "r", encoding="utf-8", newline="") as file:
        #Creating a DictReader
        reader = csv.DictReader(file)
        print(reader.fieldnames)

        #Creating a variables to catch the total orders, the unique statuses, how many times order_status appears, the unique orders by id, the missing orders by id, thw missing 
        # delivery dates, the delivered without dates
        total_orders = 0
        statuses = set()
        status_counts = {}
        order_ids = set()
        missing_order_ids = 0
        missing_delivery_dates = 0
        delivered_without_date = 0
        non_delivered_with_date = 0
        late_deliveries = 0
        eligible_deliveries = 0

        #Using a for loop to iterate for each row
        for row in reader:
            #Adding to total_orders
            total_orders += 1

            #Catching the unique statuses using the set statuses
            statuses.add(row["order_status"])

            #Create a status variable to catch the status, then with .get() function plus 1 to the status_counts
            status = row["order_status"]
            status_counts[status] = status_counts.get(status, 0) + 1

            #Adding to order_ids variable to count the unique ids using the set order_ids
            order_ids.add(row["order_id"])

            #Creating a if case to ensure that the IDs are not empty
            if row["order_id"] is None or row["order_id"].strip() == "":
                missing_order_ids += 1

            #Creating a if case to ensure that the dates are not empty
            if row["order_delivered_customer_date"] is None or row["order_delivered_customer_date"].strip() == "":
                missing_delivery_dates += 1
            
            #Creating a if case to ensure that orders with status delivered and don't have a order_delivered_customer_date
            if row["order_status"] == "delivered" and (row["order_delivered_customer_date"] is None or row["order_delivered_customer_date"].strip() == ""):
                delivered_without_date += 1
                #print(f"Delivered Without Date: {row["order_id"]}")
            
            #Creating a if case to catch the orders which their status is not delivered and still have a order_delivered_customer_date
            if row["order_status"] != "delivered" and row["order_delivered_customer_date"] is not None and row["order_delivered_customer_date"].strip():
                non_delivered_with_date += 1
                print(
                    row["order_id"],
                    row["order_status"],
                    row["order_purchase_timestamp"],
                    row["order_delivered_customer_date"],
                    row["order_estimated_delivery_date"]
                )
            
            #Read the original data values from the current CSV row
            delivery_raw = row["order_delivered_customer_date"]
            estimated_raw = row["order_estimated_delivery_date"]

            #Counts late deliveries only when both dates are available
            if (row["order_status"] == "delivered" and delivery_raw is not None and delivery_raw.strip() and estimated_raw is not None and estimated_raw.strip()):
                eligible_deliveries += 1

                delivery_date = datetime.strptime(
                    delivery_raw,
                    "%Y-%m-%d %H:%M:%S"
                )

                estimated_date = datetime.strptime(
                    estimated_raw,
                    "%Y-%m-%d %H:%M:%S"
                )

                if delivery_date.date() > estimated_date.date():
                    late_deliveries += 1


        #Calculating the late delivery rate
        late_delivery_rate = (late_deliveries / eligible_deliveries) * 100

        #Printing the results
        print(f"Total Orders: {total_orders}")
        print(f"Unique Statuses: {sorted(statuses)}")
        print(f"Status Counts: {status_counts}")
        print(f"Total Counted by Status: {sum(status_counts.values())}")
        print(f"Unique Order IDs: {len(order_ids)}")
        print(f"Missing Order IDs: {missing_order_ids}")
        print(f"Missing Delivery Dates: {missing_delivery_dates}")
        print(f"Delivered Without Date: {delivered_without_date}")
        print(f"Non-delivered With Date: {non_delivered_with_date}")
        print(f"Late Deliveries: {late_deliveries}")
        print(f"Eligible Deliveries: {eligible_deliveries}")
        print(f"Late Delivery Rate: {late_delivery_rate:.2f}%")


if __name__ == "__main__":
    main()