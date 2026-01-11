# Growth Budget Allocation

## Overview
This project evaluates whether and where an incremental $3M growth budget
should be deployed in 2015. Using a decision-gated framework, the analysis
screens markets, levers, and segments to identify options that are viable
under a risk-managed mandate and explicitly rules out paths that do not
demonstrate sufficient scale or structural demand.

The focus is not on optimizing allocation, but on protecting the decision
from weak, incentive-driven, or non-scalable narratives.

---

## What this repo demonstrates
- Decision-grade analytics
- Discipline-first problem framing
- Elimination over explanation
- Decisions protected against weak narratives

This work is structured to surface only signals that can materially
change allocation decisions.

---

## Decision context
**Decision:** How to allocate an incremental $3M growth budget  
**Scope:** 2015 planning cycle  

**Objectives:**
- Identify markets capable of absorbing the $3M 2015 growth budget and exclude those that cannot
- Distinguish structural demand drivers from incentive-driven levers
- Define conditions under which deploying the $3M budget would create unacceptable risk or future regret

> Executive deliverable (decision narrative + recommendations):  
> _Website version in progress_

---

## Deliverables
- **Decision narrative report** (Power BI, exported as static PDF)
- **Executive summary** (website format, WIP)
- **SQL analysis pipeline** supporting all conclusions
- **Documented assumptions, preprocessing decisions, and exclusions**

---

## Repository structure
- `data/`
  - `raw/` — original source data
  - `processed/` — cleaned and validated data
  - `exported_tables/` — reporting-ready extracts

- `sql/scripts/`
  - `01_data_cleaning.sql` — data validation and corrections
  - `02_exploratory_data_analysis.sql` — decision-gated analysis
  - `03_reporting_extract.sql` — final reporting outputs

- `docs/`
  - `analysis_decision_blueprint.md` — decision framework and gates
  - `analysis_pipeline.md` — analytical flow and logic
  - `data_dictionary.md` — field definitions
  - `preprocessing_log.md` — data handling decisions

- `power_bi/`
  - `artifacts/` —  exported decision artifacts (PDF and images)
    - `images/` — exported image previews of decision pages
  - `reports/` — Power BI reports and model files (PBIX)

---

## How the analysis is structured
- `01_data_cleaning.sql`
  - Ingest raw transactional data
  - Validate quality, consistency, and anomalies
  - Apply targeted corrections before analysis

- `02_exploratory_data_analysis.sql`
  - Screen budget allocation through demand, scale, and risk
  - Surface only signals that can change a deployment decision
  - Eliminate incentive-driven or non-scalable narratives
  - Produce decision inputs, not recommendations

- `03_reporting_extract.sql`
  - Extract reporting data derived from validated analysis outputs

---

## Scope boundaries
This project intentionally does **not**:
- Optimize spend mix or execution tactics
- Rank or prioritize within surviving options
- Recommend growth actions absent structural demand

Its purpose is to establish eligibility, exclusion, and risk boundaries.