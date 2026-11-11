# Table 1: Baseline characteristics by treatment arm
# Author: Hannah Posluszny

rm(list = ls(all.names = TRUE))

here::i_am("code/01_table1.R")

library(tidyverse)
library(gtsummary)

# Load data
f75 <- read_csv(
  here::here("data", "f75_interim.csv"),
  show_col_types = FALSE
)

# Select baseline characteristics
table1_data <- f75 %>%
  select(
    arm,
    agemons,
    sex,
    site,
    muac,
    weight,
    height,
    oedema,
    hiv_results,
    kwash
  )

# Generate Table 1
table1 <- table1_data %>%
  tbl_summary(
    by = arm,
    type = list(
      c(agemons, muac, weight, height) ~ "continuous"
    ),
    statistic = list(
      all_continuous() ~ "{mean} ({sd})",
      all_categorical() ~ "{n} ({p}%)"
    ),
    digits = all_continuous() ~ 1,
    missing = "ifany",
    label = list(
      agemons ~ "Age (months)",
      sex ~ "Sex",
      site ~ "Study site",
      muac ~ "MUAC (cm)",
      weight ~ "Weight (kg)",
      height ~ "Length/height (cm)",
      oedema ~ "Oedema",
      hiv_results ~ "HIV status",
      kwash ~ "Kwashiorkor"
    )
  ) %>%
  modify_header(
    label ~ "**Characteristic**"
  ) %>%
  modify_caption(
    paste0(
      "**Table 1. Baseline characteristics by treatment arm (N = ",
      nrow(table1_data),
      ")**"
    )
  ) %>%
  bold_labels()



  

# Save table for integration into the report
dir.create(
  here::here("output"),
  showWarnings = FALSE,
  recursive = TRUE
)

saveRDS(
  table1,
  here::here("output", "table1.rds")
)

# Display table
table1
