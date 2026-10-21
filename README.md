# RetailSphere

**End-to-End E-Commerce Data Engineering & Analytics Project**

## Overview

RetailSphere is a portfolio project focused on designing and building an end-to-end data engineering pipeline using the Brazilian E-Commerce Public Dataset by Olist.

The goal is to transform raw e-commerce data into reliable analytical datasets and business intelligence dashboards.

**Current status:** Environment setup and project scaffolding.

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
├── .gitignore
└── README.md
```

## Dataset

Brazilian E-Commerce Public Dataset by Olist.

Source: https://www.kaggle.com/datasets/olistbr/brazilian-ecommerce

The dataset files are not included in this repository.

## Development Status

The project is currently in its initial environment preparation phase. Data ingestion, database infrastructure, transformation models, automated tests, and dashboards will be implemented incrementally.
