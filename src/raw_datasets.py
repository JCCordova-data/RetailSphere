"""Explicit source contracts for the nine original Olist CSV datasets."""

from dataclasses import dataclass
from pathlib import Path
from types import MappingProxyType


RAW_DIRECTORY = Path(__file__).resolve().parents[1] / "data/raw"


@dataclass(frozen=True)
class Dataset:
    source_csv: str
    target_table: str
    columns: tuple[str, ...]
    expected_rows: int
    target_schema: str = "raw"


DATASETS = MappingProxyType({
    "customers": Dataset(
        "olist_customers_dataset.csv", "customers",
        ("customer_id", "customer_unique_id", "customer_zip_code_prefix",
         "customer_city", "customer_state"),
        99_441,
    ),
    "geolocation": Dataset(
        "olist_geolocation_dataset.csv", "geolocation",
        ("geolocation_zip_code_prefix", "geolocation_lat", "geolocation_lng",
         "geolocation_city", "geolocation_state"),
        1_000_163,
    ),
    "order_items": Dataset(
        "olist_order_items_dataset.csv", "order_items",
        ("order_id", "order_item_id", "product_id", "seller_id",
         "shipping_limit_date", "price", "freight_value"),
        112_650,
    ),
    "order_payments": Dataset(
        "olist_order_payments_dataset.csv", "order_payments",
        ("order_id", "payment_sequential", "payment_type",
         "payment_installments", "payment_value"),
        103_886,
    ),
    "order_reviews": Dataset(
        "olist_order_reviews_dataset.csv", "order_reviews",
        ("review_id", "order_id", "review_score", "review_comment_title",
         "review_comment_message", "review_creation_date", "review_answer_timestamp"),
        99_224,
    ),
    "orders": Dataset(
        "olist_orders_dataset.csv", "orders",
        ("order_id", "customer_id", "order_status", "order_purchase_timestamp",
         "order_approved_at", "order_delivered_carrier_date",
         "order_delivered_customer_date", "order_estimated_delivery_date"),
        99_441,
    ),
    "products": Dataset(
        "olist_products_dataset.csv", "products",
        ("product_id", "product_category_name", "product_name_lenght",
         "product_description_lenght", "product_photos_qty", "product_weight_g",
         "product_length_cm", "product_height_cm", "product_width_cm"),
        32_951,
    ),
    "sellers": Dataset(
        "olist_sellers_dataset.csv", "sellers",
        ("seller_id", "seller_zip_code_prefix", "seller_city", "seller_state"),
        3_095,
    ),
    "product_category_name_translation": Dataset(
        "product_category_name_translation.csv", "product_category_name_translation",
        ("product_category_name", "product_category_name_english"),
        71,
    ),
})
