# =============================================================================
# 01_clean_data.R
# Clean Mendeley district-level crime against women dataset for India
#
# Source dataset:
#   Patel, A. (2022). Crime Against Women Dataset for Dark Spot identification
#   in India. Mendeley Data, V1. https://doi.org/10.17632/whrdh8c5zb.1
#
# Raw data location:
#   gender_violence/data/mendeley_data/
#
# Output location:
#   data_processing/mendeley/output/
# =============================================================================

library(dplyr)
library(readr)
library(stringr)
library(tidyr)

# ---------------------------------------------------------------------------
# Paths
# ---------------------------------------------------------------------------
RAW_DIR    <- file.path("..", "..", "..", "..", "data", "mendeley_data")
OUTPUT_DIR <- file.path("..", "output")

CRIME_FILE  <- file.path(RAW_DIR, "women-crimedataset-India.csv")
CENSUS_FILE <- file.path(RAW_DIR, "Final-censusdataset-India.csv")

dir.create(OUTPUT_DIR, showWarnings = FALSE, recursive = TRUE)


# =============================================================================
# PART 1: CRIME DATASET  (women-crimedataset-India.csv)
# =============================================================================
# This file contains district × year panel data on 13 categories of crimes
# against women, sourced from NCRB annual reports 2001–2020.
# NCRB crime-head definitions: IPC sections documented at
#   https://www.indianbarassociation.org/crimes-against-women-a-legal-perspective/
#   https://www.ncrb.gov.in/uploads/2022/July/11/custom/crime-in-india/5-crime-against-women_2012.pdf

crime_raw <- read_csv(
  CRIME_FILE,
  col_types = cols(.default = "c"),  # read everything as character first
  show_col_types = FALSE
)
# readr preserves trailing whitespace in column names; trim them
names(crime_raw) <- trimws(names(crime_raw))

# ---------------------------------------------------------------------------
# Step 1: Rename columns to human-readable snake_case
#
# Column names in the raw file are all-caps prose strings with special chars.
# We rename to descriptive snake_case names that encode the IPC section where
# relevant. IPC section references from:
#   https://blog.ipleaders.in/offences-against-women/
# ---------------------------------------------------------------------------
crime_renamed <- crime_raw |>
  rename(
    state_ut                     = `STATE/UT`,
    district                     = `DISTRICT`,
    year                         = `YEAR`,
    # IPC 302/304: NCRB includes all murders in this column, not only those
    # with female victims. It is retained for covariate use.
    # Source: NCRB Crime in India 2012 methodology notes, Chapter 5
    murder_total                 = `MURDER`,
    attempt_to_murder            = `ATTEMPT TO MURDER`,
    # IPC 376 (pre-2013) / 376, 376A-E (post-2013 Criminal Law Amendment Act)
    rape_total                   = `RAPE`,
    # IPC 376C: rape by persons in authority (police, public servants, etc.)
    rape_custodial               = `CUSTODIAL RAPE`,
    # Derived sub-category: rape_total minus rape_custodial
    rape_other                   = `OTHER RAPE`,
    # IPC 363–373 (kidnapping), 366/366A (abduction of women for marriage)
    kidnapping_abduction_total   = `KIDNAPPING & ABDUCTION`,
    kidnapping_abduction_women   = `KIDNAPPING AND ABDUCTION OF WOMEN AND GIRLS`,
    kidnapping_abduction_others  = `KIDNAPPING AND ABDUCTION OF OTHERS`,
    # IPC 304-B: death of woman within 7 yrs of marriage linked to dowry demand
    dowry_deaths                 = `DOWRY DEATHS`,
    # IPC 354: assault or criminal force to outrage a woman's modesty
    assault_on_modesty           = `ASSAULT ON WOMEN WITH INTENT TO OUTRAGE HER MODESTY`,
    # IPC 509: word, gesture, or act insulting modesty of a woman
    insult_to_modesty            = `INSULT TO MODESTY OF WOMEN`,
    # IPC 498-A: husband or relative subjecting wife to cruelty
    cruelty_by_husband           = `CRUELTY BY HUSBAND OR HIS RELATIVES`,
    # IPC 366-B: importing a girl under 21 from outside India for illicit intercourse
    importation_of_girls         = `IMPORTATION OF GIRLS FROM FOREIGN COUNTRIES`
  )

# ---------------------------------------------------------------------------
# Step 2: Standardise state and district names
#
# Raw values are full uppercase. We convert to title case for readability.
# Leading/trailing whitespace is stripped.
# ---------------------------------------------------------------------------
crime_renamed <- crime_renamed |>
  mutate(
    state_ut = str_to_title(str_trim(state_ut)),
    district  = str_to_title(str_trim(district))
  )

# ---------------------------------------------------------------------------
# Step 3: Convert year and crime counts to numeric
#
# All columns were read as character to avoid silent coercion.
# Blank strings become NA; non-numeric strings will warn.
# ---------------------------------------------------------------------------
crime_renamed <- crime_renamed |>
  mutate(
    year = as.integer(year),
    across(
      murder_total:importation_of_girls,
      ~ suppressWarnings(as.integer(.x))
    )
  )

# ---------------------------------------------------------------------------
# Step 4a: Drop state-level "Total" district rows
#
# The raw NCRB source tables include one row per state per year where
# district = "Total" containing the state-level aggregate. If kept, summing
# by state+year double-counts every value (district rows + Total row = 2x true
# state figure). Verification against NCRB official rape totals confirmed
# exact 2x inflation when these rows are included; removing them yields
# state totals that match NCRB published figures within 0.02% for 2010/2012.
#
# Verification details: rape_total for Madhya Pradesh 2001 in source = 5,702
# (= 2,851 districts + 2,851 Total row); NCRB official = 2,851.
# After removing Total rows, national rape total matches NCRB within 2.4% for
# 2001 and within 0.02% for 2010/2012 (small residual from UT reporting gaps).
# ---------------------------------------------------------------------------
n_total_rows <- sum(str_to_lower(str_trim(crime_renamed$district)) == "total", na.rm = TRUE)
message("State 'Total' aggregate rows removed: ", n_total_rows)

crime_renamed <- crime_renamed |>
  filter(str_to_lower(str_trim(district)) != "total")

# ---------------------------------------------------------------------------
# Step 4b: Drop rows with missing year
#
# 10 rows have a blank YEAR field. Without a year these rows cannot be placed
# in the time series and are excluded. Inspecting these rows shows they appear
# to be header/subtotal artefacts from the original NCRB Excel exports.
# ---------------------------------------------------------------------------
n_missing_year <- sum(is.na(crime_renamed$year))
message("Rows dropped for missing year: ", n_missing_year)

crime_clean <- crime_renamed |>
  filter(!is.na(year))

# ---------------------------------------------------------------------------
# Step 5: Remove duplicate state × district × year rows
#
# 37 duplicate rows exist in the raw file. These arise from the original NCRB
# spreadsheets where some districts appear twice (e.g., sub-district splits or
# data-entry errors). We keep the first occurrence per key as the de-facto
# standard for NCRB district-level data.
# Reference: data quality note in Mendeley dataset description.
# ---------------------------------------------------------------------------
n_before <- nrow(crime_clean)
crime_clean <- crime_clean |>
  distinct(state_ut, district, year, .keep_all = TRUE)
n_after <- nrow(crime_clean)
message("Duplicate rows removed: ", n_before - n_after)

# ---------------------------------------------------------------------------
# Step 6: Add a unique composite key column
#
# A single string key combining state, district, and year identifies each row
# unambiguously. Format: "STATE|DISTRICT|YEAR"
# ---------------------------------------------------------------------------
crime_clean <- crime_clean |>
  mutate(
    obs_id = paste(
      str_to_upper(state_ut),
      str_to_upper(district),
      year,
      sep = "|"
    )
  ) |>
  select(obs_id, state_ut, district, year, everything())

# ---------------------------------------------------------------------------
# Step 7: Validate internal consistency of rape and kidnapping sub-totals
#
# CUSTODIAL RAPE + OTHER RAPE should equal RAPE TOTAL.
# KIDNAPPING WOMEN + KIDNAPPING OTHERS should equal KIDNAPPING TOTAL.
# We flag rows where this does not hold (likely data entry issues in NCRB source).
# We do NOT overwrite values — we expose the flag so analysts can decide.
# ---------------------------------------------------------------------------
crime_clean <- crime_clean |>
  mutate(
    flag_rape_subtotal_mismatch =
      (rape_custodial + rape_other) != rape_total,
    flag_kidnapping_subtotal_mismatch =
      (kidnapping_abduction_women + kidnapping_abduction_others) != kidnapping_abduction_total
  )

n_rape_flag      <- sum(crime_clean$flag_rape_subtotal_mismatch, na.rm = TRUE)
n_kidnap_flag    <- sum(crime_clean$flag_kidnapping_subtotal_mismatch, na.rm = TRUE)
message("Rows where rape sub-totals don't sum to total: ", n_rape_flag)
message("Rows where kidnapping sub-totals don't sum to total: ", n_kidnap_flag)

# ---------------------------------------------------------------------------
# Step 8: Note years with incomplete coverage
#
# The dataset covers 2001–2012, 2015, 2019, 2020.
# Years 2013, 2014, 2016, 2017, 2018 are absent — the NCRB changed its
# district-level reporting format in 2013 and the compiler did not include
# these transition years. Analysts should account for this gap.
# ---------------------------------------------------------------------------
covered_years <- sort(unique(crime_clean$year))
message("Years covered: ", paste(covered_years, collapse = ", "))
message("Note: 2013, 2014, 2016, 2017, 2018 are missing from this dataset.")


# =============================================================================
# PART 2: CENSUS DATASET  (Final-censusdataset-India.csv)
# =============================================================================
# This file contains district-level socioeconomic data from Census of India
# 2011, compiled by the dataset author.
# Census 2011 data source: https://censusindia.gov.in
# Census variable definitions: Census of India 2011 Primary Census Abstract,
#   available at https://censusindia.gov.in/nada/index.php/catalog/42679

census_raw <- read_csv(
  CENSUS_FILE,
  col_types = cols(.default = "c"),
  show_col_types = FALSE
)

# ---------------------------------------------------------------------------
# Step 1: Remove duplicate "urban" column
#
# The raw file has two columns both named "urban" (columns 9 and 10).
# read_csv auto-renames the second as "urban...10". We drop it — inspection
# shows it contains a different variable (likely a sub-category or ST urban pop)
# that is not documented in the dataset metadata. We rename the first "urban"
# to "urban_pop" for clarity.
# ---------------------------------------------------------------------------
census_raw <- census_raw |>
  rename(
    serial_number              = sr,
    state_name                 = state,
    district_raw               = District,
    population_total           = person,
    population_male            = Male,
    population_female          = Female,
    population_growth_pct      = growthinpopulation,
    population_rural           = rural,
    population_urban           = urban...9,    # first urban column = total urban pop
    # urban...10 appears to be an unlabelled sub-category; dropped below
    population_scheduled_tribe = STPop,
    literacy_rate_total        = Personlit_rate,
    literacy_rate_male         = Mlit_Rate,
    literacy_rate_female       = Flit_Rate,
    workers_total              = Totalworkers,
    workers_main               = Mainworkers,
    workers_marginal           = `Marginal workers`,
    non_workers                = Nonworkers,
    religion_1_name            = Religion1,
    religion_1_pop             = `religion1 population`,
    religion_2_name            = Religion2,
    religion_2_pop             = `Religion2 Population`,
    religion_3_name            = religion3name,
    religion_3_pop             = religion3poulation,
    inhabited_villages         = inhabitadevillages,
    hh_with_drinking_water     = drinkingwater,
    hh_with_electricity        = electricity,
    primary_schools            = `primary school`,
    medical_facilities         = `Medical facility`
  ) |>
  select(-`urban...10`)   # drop undocumented duplicate urban column

# ---------------------------------------------------------------------------
# Step 2: Clean district name — extract clean name from census coding format
#
# Raw district names have the format: "District Name (code), State Name (code)"
# e.g. "District Nicobars (01), Andaman & Nicobar Islands (35)"
# We extract only the district name portion before the first "(".
# ---------------------------------------------------------------------------
census_raw <- census_raw |>
  mutate(
    district = str_to_title(str_trim(str_extract(district_raw, "^[^(]+"))),
    state_ut  = str_to_title(str_trim(state_name))
  ) |>
  select(-district_raw, -state_name)

# ---------------------------------------------------------------------------
# Step 3: Clean religion name columns
#
# Raw values contain numbered prefixes: "1.Hindus", "2.Christians", etc.
# We strip the numeric prefix and standardise to plain religion names.
# ---------------------------------------------------------------------------
census_raw <- census_raw |>
  mutate(
    across(
      c(religion_1_name, religion_2_name, religion_3_name),
      ~ str_trim(str_replace(.x, "^[0-9]+\\.", ""))
    )
  )

# ---------------------------------------------------------------------------
# Step 4: Convert numeric columns
#
# "-" values (used for zero/missing) are coerced to NA.
# ---------------------------------------------------------------------------
num_cols <- c(
  "population_total", "population_male", "population_female",
  "population_growth_pct", "population_rural", "population_urban",
  "population_scheduled_tribe",
  "literacy_rate_total", "literacy_rate_male", "literacy_rate_female",
  "workers_total", "workers_main", "workers_marginal", "non_workers",
  "religion_1_pop", "religion_2_pop", "religion_3_pop",
  "inhabited_villages", "hh_with_drinking_water", "hh_with_electricity",
  "primary_schools", "medical_facilities"
)

census_clean <- census_raw |>
  mutate(
    serial_number = as.integer(serial_number),
    across(
      all_of(num_cols),
      ~ suppressWarnings(as.numeric(str_replace_all(.x, ",", "")))
    )
  )

# ---------------------------------------------------------------------------
# Step 5: Add unique key
#
# Census is a cross-section (single year: 2011), so key is state + district.
# ---------------------------------------------------------------------------
census_clean <- census_clean |>
  mutate(
    obs_id = paste(
      str_to_upper(state_ut),
      str_to_upper(district),
      sep = "|"
    )
  ) |>
  select(obs_id, state_ut, district, everything(), -serial_number)

# ---------------------------------------------------------------------------
# Step 6: Check for duplicates on state × district key
# ---------------------------------------------------------------------------
n_dup_census <- sum(duplicated(census_clean[c("state_ut", "district")]))
message("Census duplicate state×district rows: ", n_dup_census)


# =============================================================================
# PART 3: Save cleaned datasets
# =============================================================================

crime_output_path  <- file.path(OUTPUT_DIR, "crime_against_women_clean.csv")
census_output_path <- file.path(OUTPUT_DIR, "census_2011_district_clean.csv")

write_csv(crime_clean,  crime_output_path)
write_csv(census_clean, census_output_path)

message("\nCleaned files written:")
message("  ", crime_output_path,  "  (", nrow(crime_clean),  " rows x ", ncol(crime_clean),  " cols)")
message("  ", census_output_path, "  (", nrow(census_clean), " rows x ", ncol(census_clean), " cols)")

# =============================================================================
# PART 4: Summary of changes
# =============================================================================
message("\n--- CLEANING SUMMARY ---")
message("CRIME DATASET")
message("  Raw rows       : 11,709")
message("  Dropped (no year)  : ", n_missing_year)
message("  Dropped (duplicates): ", n_before - n_after)
message("  Final rows     : ", nrow(crime_clean))
message("  Columns raw    : 16  -->  Columns clean: ", ncol(crime_clean))
message("  Years covered  : ", paste(covered_years, collapse = ", "))
message("  Flag - rape subtotal mismatch    : ", n_rape_flag, " rows")
message("  Flag - kidnap subtotal mismatch  : ", n_kidnap_flag, " rows")
message("")
message("CENSUS DATASET")
message("  Raw rows       : 590")
message("  Final rows     : ", nrow(census_clean))
message("  Columns raw    : 29  -->  Columns clean: ", ncol(census_clean))
message("  Duplicate rows : ", n_dup_census)
