# Data Processing: Mendeley Crime Against Women Dataset

## Overview

This folder contains the cleaning pipeline for the Mendeley Data repository dataset:

> Patel, A. (2022). *Crime Against Women Dataset for Dark Spot identification in India*. Mendeley Data, V1.  
> DOI: [10.17632/whrdh8c5zb.1](https://doi.org/10.17632/whrdh8c5zb.1)  
> URL: https://data.mendeley.com/datasets/whrdh8c5zb/1

Raw files are stored at: `gender_violence/data/mendeley_data/`  
See that folder's README for full download instructions and raw variable documentation.

---

## Folder structure

```
data_processing/mendeley/
├── src/
│   └── 01_clean_data.R       # Cleaning script
├── output/
│   ├── crime_against_women_clean.csv
│   └── census_2011_district_clean.csv
└── README.md                 # This file
```

---

## Data documentation links

| Resource | URL |
|---|---|
| Dataset landing page | https://data.mendeley.com/datasets/whrdh8c5zb/1 |
| Dataset DOI | https://doi.org/10.17632/whrdh8c5zb.1 |
| NCRB crime-head definitions (IPC) | https://www.indianbarassociation.org/crimes-against-women-a-legal-perspective/ |
| NCRB Chapter 5 — Crime against Women (2012) | https://www.ncrb.gov.in/uploads/2022/July/11/custom/crime-in-india/5-crime-against-women_2012.pdf |
| IPC offences against women — full legal overview | https://blog.ipleaders.in/offences-against-women/ |
| Census 2011 Primary Census Abstract | https://censusindia.gov.in/nada/index.php/catalog/42679 |
| Census of India 2011 homepage | https://censusindia.gov.in |

---

## Script: `src/01_clean_data.R`

Run from the `src/` directory:
```r
Rscript 01_clean_data.R
```

Required R packages: `dplyr`, `readr`, `stringr`, `tidyr` (all in base R 4.x installs or standard tidyverse)

---

## Variables: raw vs. cleaned

### Crime dataset (`women-crimedataset-India.csv` → `crime_against_women_clean.csv`)

| Raw column | Cleaned column | Type | Notes |
|---|---|---|---|
| *(new)* | `obs_id` | chr | Unique key: `STATE\|DISTRICT\|YEAR` |
| `STATE/UT` | `state_ut` | chr | Title-cased, whitespace stripped |
| `DISTRICT` | `district` | chr | Title-cased, whitespace stripped |
| `YEAR` | `year` | int | 10 rows with blank year dropped |
| `MURDER` | `murder_total` | int | IPC 302/304 |
| `ATTEMPT TO MURDER` | `attempt_to_murder` | int | IPC 307 |
| `RAPE` | `rape_total` | int | IPC 376 (pre/post 2013 amendment) |
| `CUSTODIAL RAPE` | `rape_custodial` | int | IPC 376C — rape by authority |
| `OTHER RAPE` | `rape_other` | int | Rape excluding custodial |
| `KIDNAPPING & ABDUCTION` | `kidnapping_abduction_total` | int | IPC 363–373 |
| `KIDNAPPING AND ABDUCTION OF WOMEN AND GIRLS` | `kidnapping_abduction_women` | int | IPC 366/366A |
| `KIDNAPPING AND ABDUCTION OF OTHERS` | `kidnapping_abduction_others` | int | IPC 363 etc. |
| `DOWRY DEATHS` | `dowry_deaths` | int | IPC 304-B |
| `ASSAULT ON WOMEN WITH INTENT TO OUTRAGE HER MODESTY` | `assault_on_modesty` | int | IPC 354 |
| `INSULT TO MODESTY OF WOMEN` | `insult_to_modesty` | int | IPC 509 |
| `CRUELTY BY HUSBAND OR HIS RELATIVES` | `cruelty_by_husband` | int | IPC 498-A |
| `IMPORTATION OF GIRLS FROM FOREIGN COUNTRIES` | `importation_of_girls` | int | IPC 366-B |
| *(new)* | `flag_rape_subtotal_mismatch` | lgl | TRUE if rape_custodial + rape_other ≠ rape_total |
| *(new)* | `flag_kidnapping_subtotal_mismatch` | lgl | TRUE if sub-totals ≠ kidnapping total |

**Key cleaning decisions:**
- **455 state-level `district = 'Total'` rows dropped** — these are NCRB state-aggregate rows present alongside district rows. Keeping them causes exact 2× double-counting when aggregating by state. Verified by cross-checking rape totals against NCRB published state figures: uncorrected totals were exactly 2× official values (e.g., MP 2001: our raw = 5,702; NCRB official = 2,851). After removal, national totals match NCRB within 0.02% for 2010 and 2012.
- 2 duplicate `state_ut × district × year` rows removed (first occurrence kept)
- 1,573 rows flagged where rape sub-totals don't sum to total (retained, not overwritten)
- 2,031 rows flagged where kidnapping sub-totals don't sum to total (retained, not overwritten)
- Years 2013, 2014, 2016–2018 absent from source — not a cleaning artefact

**Final dimensions:** 11,220 rows × 19 columns  
**Years covered:** 2001–2012, 2015, 2019, 2020

---

### Census dataset (`Final-censusdataset-India.csv` → `census_2011_district_clean.csv`)

| Raw column | Cleaned column | Type | Notes |
|---|---|---|---|
| *(new)* | `obs_id` | chr | Unique key: `STATE\|DISTRICT` |
| `state` | `state_ut` | chr | Title-cased |
| `District` | `district` | chr | Extracted clean name from "Name (code), State (code)" format |
| `sr` | *(dropped)* | — | Serial number, redundant given obs_id |
| `person` | `population_total` | num | Total population |
| `Male` | `population_male` | num | Male population |
| `Female` | `population_female` | num | Female population |
| `growthinpopulation` | `population_growth_pct` | num | Growth rate since 2001 (%) |
| `rural` | `population_rural` | num | Rural population |
| `urban...9` | `population_urban` | num | Urban population (first of two duplicate columns) |
| `urban...10` | *(dropped)* | — | Undocumented duplicate column, dropped |
| `STPop` | `population_scheduled_tribe` | num | Scheduled Tribe population |
| `Personlit_rate` | `literacy_rate_total` | num | Overall literacy rate (%) |
| `Mlit_Rate` | `literacy_rate_male` | num | Male literacy rate (%) |
| `Flit_Rate` | `literacy_rate_female` | num | Female literacy rate (%) |
| `Totalworkers` | `workers_total` | num | Total workers |
| `Mainworkers` | `workers_main` | num | Main workers (worked 6+ months/year) |
| `Marginal workers` | `workers_marginal` | num | Marginal workers (worked <6 months/year) |
| `Nonworkers` | `non_workers` | num | Non-workers |
| `Religion1` | `religion_1_name` | chr | Largest religion (numeric prefix stripped) |
| `religion1 population` | `religion_1_pop` | num | Population of religion 1 |
| `Religion2` | `religion_2_name` | chr | Second-largest religion |
| `Religion2 Population` | `religion_2_pop` | num | Population of religion 2 |
| `religion3name` | `religion_3_name` | chr | Third-largest religion |
| `religion3poulation` | `religion_3_pop` | num | Population of religion 3 |
| `inhabitadevillages` | `inhabited_villages` | num | Number of inhabited villages |
| `drinkingwater` | `hh_with_drinking_water` | num | Households with drinking water access |
| `electricity` | `hh_with_electricity` | num | Households with electricity access |
| `primary school` | `primary_schools` | num | Number of primary schools |
| `Medical facility` | `medical_facilities` | num | Number of medical facilities |

**Key cleaning decisions:**
- Duplicate `urban` column dropped (second instance undocumented in dataset)
- District names parsed from format `"Name (code), State (code)"` — code stripped
- Religion name prefixes (`"1.Hindus"` → `"Hindus"`) stripped for clean categorical values
- `"-"` values converted to `NA` during numeric coercion

**Final dimensions:** 590 rows × 28 columns  
**Reference year:** Census of India 2011 (single cross-section)
