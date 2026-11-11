# Table 2: Logistic regression of mortality
# Author: Hannah Posluszny

rm(list = ls(all.names = TRUE))

here::i_am("code/02_table2.R")

library(tidyverse)
library(gtsummary)

# Load data
f75 <- read_csv(
  here::here("data", "f75_interim.csv"),
  show_col_types = FALSE
)

# Create binary mortality outcome
# 1 = died; 0 = discharged or other recorded withdrawal
analysis_data <- f75 %>%
  mutate(
    mortality = case_when(
      withdraw2 == "died" ~ 1L,
      discharged2 == "Yes" ~ 0L,
      !is.na(withdraw2) ~ 0L,
      TRUE ~ NA_integer_
    ),
    arm = factor(
      arm,
      levels = c(
        "Standard F75",
        "Modified F75 (intervention)"
      )
    )
  )

# Fit unadjusted logistic regression
model_unadjusted <- glm(
  mortality ~ arm,
  data = analysis_data,
  family = binomial
)

# Fit adjusted logistic regression
model_adjusted <- glm(
  mortality ~ arm + agemons + sex + site + muac + hiv_results,
  data = analysis_data,
  family = binomial
)

# Create unadjusted regression table
table_unadjusted <- tbl_regression(
  model_unadjusted,
  exponentiate = TRUE,
  label = list(
    arm ~ "Treatment arm"
  )
)

# Create adjusted regression table
table_adjusted <- tbl_regression(
  model_adjusted,
  exponentiate = TRUE,
  label = list(
    arm ~ "Treatment arm",
    agemons ~ "Age (months)",
    sex ~ "Sex",
    site ~ "Study site",
    muac ~ "MUAC (cm)",
    hiv_results ~ "HIV status"
  )
)

# Combine models into Table 2
table2 <- tbl_merge(
  tbls = list(
    table_unadjusted,
    table_adjusted
  ),
  tab_spanner = c(
    "**Unadjusted**",
    "**Adjusted**"
  )
) %>%
  modify_caption(
    paste0(
      "**Table 2. Association between F75 treatment arm and mortality**",
      " (Unadjusted N = ", nobs(model_unadjusted),
      "; Adjusted N = ", nobs(model_adjusted), ")"
    )
  ) %>%
  bold_labels()

# Save output
dir.create(
  here::here("output"),
  showWarnings = FALSE,
  recursive = TRUE
)

saveRDS(
  table2,
  here::here("output", "table2.rds")
)

# Display table
table2
