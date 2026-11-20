# RetailSphere dbt project

dbt Core project that turns the RAW Olist tables in PostgreSQL into the CLEAN (silver) and ANALYTICS (gold) layers consumed by Power BI. For the full pipeline, see the [root README](../../README.md).

## Models

| Layer | Schema | Models |
|---|---|---|
| CLEAN | `clean` | `customers`, `orders`, `order_items`, `order_reviews`, `products` |
| ANALYTICS | `analytics` | `monthly_sales`, `delivery_performance`, `category_sales`, `repeat_customers`, `customer_satisfaction` |

All models are materialized as views. CLEAN models read from the `raw` source (`models/clean/sources.yml`). The macro `generate_schema_name` places ANALYTICS models in the literal `analytics` schema, so the profile's `schema` must be `clean`. Details: [`docs/RS-031.md`](../../docs/RS-031.md).

## Profile setup

The repository does not include a `profiles.yml` (it would hold credentials). Create `~/.dbt/profiles.yml` with the following content. It reads the connection settings from the same `PG*` environment variables used by the Python ingestion, so no password is written to disk:

```yaml
retailsphere:
  target: dev
  outputs:
    dev:
      type: postgres
      host: 127.0.0.1
      port: 5432
      user: "{{ env_var('PGUSER') }}"
      password: "{{ env_var('PGPASSWORD') }}"
      dbname: "{{ env_var('PGDATABASE') }}"
      schema: clean
      threads: 4
```

## Run

From the repository root, with `PGUSER`, `PGDATABASE` and `PGPASSWORD` exported and the RAW tables loaded:

```bash
cd dbt/retailsphere
dbt debug    # checks the profile and the database connection
dbt build    # runs the 10 models and all data tests
```

Last full build (2026-11-17): `PASS=118 WARN=0 ERROR=0 SKIP=0 TOTAL=118` — 10 views plus 108 data tests.

## Tests

- Schema tests are declared in `models/clean/schema.yml` and `models/analytics/schema.yml`.
- Singular tests live in `tests/` (`assert_*.sql`). They check row counts against RAW, key uniqueness, value ranges, column types, and reconciliation of each analytics model with the CLEAN layer.
- Run only the tests with `dbt test`.

## Documentation

Each analytics model has its own design and validation notes in the repository's `docs/` folder. See the Documentation table in the [root README](../../README.md#documentation).