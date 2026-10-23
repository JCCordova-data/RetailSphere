# RetailSphere

**End-to-End E-Commerce Data Engineering & Analytics Project**

## Overview

RetailSphere is a portfolio project focused on designing and building an end-to-end data engineering pipeline using the Brazilian E-Commerce Public Dataset by Olist.

The goal is to transform raw e-commerce data into reliable analytical datasets and business intelligence dashboards.

**Current status:** Project scaffolding completed. Local PostgreSQL 18 infrastructure is operational through Docker Compose. Data ingestion and transformation pipelines are pending implementation.

## Business Objectives

- Analyze monthly sales performance.
- Identify orders delivered later than expected.
- Explore sales by product category.
- Analyze returning customers.
- Evaluate customer satisfaction.

## Planned Architecture

Olist CSV Files → Python Ingestion → PostgreSQL RAW → SQL/dbt CLEAN → PostgreSQL ANALYTICS → Power BI

## Technology Stack

- **Python:** Data ingestion and validation.
- **PostgreSQL:** Data storage and analytical queries.
- **SQL and dbt:** Data transformation and testing.
- **Docker Compose:** Local service management.
- **Power BI:** Business intelligence and visualization.
- **Prefect (planned for a later stage):** Pipeline orchestration.
- **Git and GitHub:** Version control.

## Project Structure

```text
RetailSphere/
├── data/
│   └── raw/
├── docs/
├── sql/
├── src/
├── tests/
├── .env.example
├── .gitignore
├── compose.yaml
└── README.md
```

## Local PostgreSQL Setup

**Prerequisites:** Docker Desktop with WSL2 integration and Docker Compose.

1. Create your local environment file:

   ```bash
   cp .env.example .env
   ```

2. Open `.env` and replace `CHANGE_ME_TO_A_STRONG_PASSWORD` with your own strong password. Never commit `.env` to Git.

3. Start PostgreSQL:

   ```bash
   docker compose up -d
   ```

4. Verify the service:

   ```bash
   docker compose ps
   docker compose exec postgres pg_isready -U retailsphere -d retailsphere
   ```

5. Run a test SQL query:

   ```bash
   docker compose exec postgres psql -U retailsphere -d retailsphere -c "SELECT current_database(), current_user;"
   ```

**Local connection:** `127.0.0.1:5432`

**Database:** `retailsphere`

**User:** `retailsphere`

PostgreSQL data is stored in the Docker named volume `retailsphere_postgres_data`. Restarting the container does not remove the volume. Avoid `docker compose down -v` unless you explicitly intend to delete the stored data.

## Dataset

RetailSphere uses the [Brazilian E-Commerce Public Dataset by Olist](https://www.kaggle.com/datasets/olistbr/brazilian-ecommerce).

The dataset contains nine CSV files covering orders, customers, order items, payments, reviews, products, sellers, geolocation, and product category translations.

### Raw Data Setup

1. Download the dataset ZIP archive from Kaggle.
2. Extract the nine CSV files into `data/raw/`, keeping their original filenames.
3. Verify the extracted files:

   ```bash
   ls -lh data/raw/
   wc -l data/raw/*.csv
   ```

4. Confirm that Git ignores the raw CSV files:

   ```bash
   git check-ignore -v data/raw/*.csv
   ```

The original CSV files are intentionally excluded from version control through `.gitignore`. They must be downloaded separately when setting up the project.

**Data integrity:** During initial dataset preparation, all nine extracted CSV files were verified against the downloaded ZIP archive using SHA-256 checksums. No differences were detected.

Raw source files should remain unchanged. Data cleaning and transformations will be implemented in subsequent pipeline stages.

## Development Status

The project environment and local PostgreSQL 18 infrastructure are operational.

All nine original Olist CSV files have been prepared and verified in the local RAW data directory. A basic Python CSV reading and validation exercise has also been completed.

The PostgreSQL ingestion pipeline, SQL/dbt transformation models, automated data quality tests, orchestration, and Power BI dashboards are pending implementation.
