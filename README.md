# 🔍 Data Validation Pipelines (SQL) — Healthcare Analytics

## Overview
Analytics pipelines are only as strong as the data they ingest. This project demonstrates a **SQL-based data validation pipeline** designed to detect, classify, and quantify **data quality risks** in healthcare datasets before they reach downstream analytics and reporting layers.

Rather than treating data validation as a one-time check, this project models validation as a **repeatable pipeline**—producing analytics-ready outputs that support governance, trust, and executive decision-making.

---

## Business Problem
Healthcare analytics teams frequently face questions such as:

- *Can this data be trusted?*
- *Which data issues actually matter to leadership?*
- *How severe are the problems, not just how many?*

Traditional row-level error checks do not answer these questions. This project introduces **severity-weighted validation pipelines** that translate technical data failures into **business-relevant risk signals**.

---

## Dataset
**Type:** Synthetic healthcare claims data  
**Domain:** Claims processing / revenue cycle analytics  

The dataset intentionally includes both valid and invalid records to simulate real-world ingestion challenges.

---

## Pipeline Architecture

### Core Tables
- `claims_transactions` – transactional healthcare claims data  
- `provider_reference` – provider master reference  
- `validation_results` – rule execution output (one row per failure)  
- `severity_weights` – severity-to-risk mapping  

These tables form the foundation of a modular validation pipeline.

---

## Validation Rules Framework

### Validation Categories
Each rule belongs to a defined category:

- **Completeness** – missing required fields  
- **Validity** – invalid numeric or logical values  
- **Consistency** – conflicting fields or timelines  
- **Referential Integrity** – broken relationships  

### Example Rules
- Missing diagnosis code  
- Paid amount greater than claim amount  
- Service date after submission date  
- Denied claims with payment  
- Orphan provider references  

Rules are **idempotent**, allowing safe re-execution as part of a pipeline.

---

## Severity-Weighted Risk Scoring
Instead of treating all validation failures equally, the pipeline applies **severity weights** to reflect business impact.

| Severity | Weight |
|--------|--------|
| HIGH | 5 |
| MEDIUM | 2 |
| LOW | 1 |

This enables:
- Risk-based prioritization
- Executive-friendly scoring
- Focus on issues that meaningfully affect decisions

---

## Pipeline Outputs (Analytics-Ready Views)

The pipeline produces SQL views designed for BI and monitoring tools:

- **Rule-level summary**
  - Failure count and weighted impact per rule
- **Category risk summary**
  - Aggregated risk by validation category
- **Severity distribution**
  - Breakdown of HIGH / MEDIUM / LOW issues
- **Executive scorecard**
  - Total records processed
  - Claims with validation failures
  - High-severity issue count
  - Overall data quality score

These outputs answer the core question:
> *“Can leadership trust this data?”*

---

## Technology Stack
- SQL (PostgreSQL-compatible)
- Supabase (cloud database)
- Power BI (downstream visualization & monitoring)

---

## Why This Project Matters
This project demonstrates:
- Production-style SQL design
- Data governance and trust frameworks
- Pipeline thinking rather than ad-hoc validation
- Translation of technical issues into business risk
- Healthcare analytics domain awareness

It reflects how mature analytics teams operationalize **data quality as a first-class pipeline**, not an afterthought.

---

## Potential Extensions
- Automation via scheduled pipeline execution
- Historical trend tracking of data quality
- Alerting for high-severity rule breaches
- Integration with ingestion workflows
- Data quality SLAs and thresholds

---

## Author
**Mahesh Tanniru**  
Business Analyst | Healthcare Analytics | Data Quality & Governance  

