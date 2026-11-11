# Build a written description of the stratified results.
#
# Input : the list saved in output/stratified_table.rds
#         (created by code/stratified_analysis.R from config.yml)
# Output: a list of text pieces (overview, strata, interaction, caveat).
#         Every number and label comes from the saved results, so the text
#         changes automatically when config.yml selects a different
#         stratifying variable.
#
# Used by report_stratified_section.Rmd:
#   source(here::here("code", "describe_results.R"))
#   txt <- describe_results(readRDS(here::here("output", "stratified_table.rds")))

fmt_p <- function(p) if (p < 0.001) "p < 0.001" else sprintf("p = %.3f", p)

fmt_or <- function(or, lo, hi) {
  sprintf("OR %.2f, 95%% CI %.2f to %.2f", or, lo, hi)
}

join_and <- function(x) {
  if (length(x) <= 1) return(x)
  paste0(paste(x[-length(x)], collapse = ", "), " and ", x[length(x)])
}

describe_results <- function(strat) {
  alpha <- if (is.null(strat$alpha)) 0.05 else strat$alpha
  res <- strat$results
  res$Stratum <- as.character(res$Stratum)
  overall <- res[res$Stratum == "Overall", ]
  strata  <- res[res$Stratum != "Overall", ]

  trt <- strat$treatment
  ref <- strat$reference
  name <- strat$strat_name
  # Readable covariate names for the text (unknown names fall back to the
  # variable name with underscores replaced by spaces).
  cov_names <- c(sex = "sex", site = "site", hiv_results = "HIV status",
                 muac = "MUAC")
  cov_text <- ifelse(strat$covariates %in% names(cov_names),
                     cov_names[strat$covariates],
                     gsub("_", " ", strat$covariates))
  covs <- join_and(unname(cov_text))

  higher_lower <- function(or) if (or > 1) "higher" else "lower"
  signif_txt <- function(p) {
    if (p < alpha) "statistically significant" else "not statistically significant"
  }

  # ---- Overall -----------------------------------------------------------
  overview <- sprintf(
    paste0(
      "Overall, %d children were included and %d (%.1f%%) died. ",
      "Deaths occurred in %d of %d children (%.1f%%) in the %s arm and ",
      "%d of %d (%.1f%%) in the %s arm. After adjusting for %s, the odds ",
      "of death in the %s arm were %s than in the %s arm (%s; %s), which ",
      "was %s at the %g level."
    ),
    overall$n, overall$deaths, 100 * overall$deaths / overall$n,
    overall$deaths_intervention, overall$n_intervention,
    100 * overall$deaths_intervention / overall$n_intervention, trt,
    overall$deaths_reference, overall$n_reference,
    100 * overall$deaths_reference / overall$n_reference, ref,
    covs, trt, higher_lower(overall$OR), ref,
    fmt_or(overall$OR, overall$lower, overall$upper), fmt_p(overall$p_value),
    signif_txt(overall$p_value), alpha
  )

  # ---- One bullet per stratum -------------------------------------------
  bullets <- vapply(seq_len(nrow(strata)), function(i) {
    s <- strata[i, ]
    sprintf(
      "**%s** (%d children, %d deaths): %s odds of death in the %s arm (%s; %s), %s.%s",
      s$Stratum, s$n, s$deaths, higher_lower(s$OR), trt,
      fmt_or(s$OR, s$lower, s$upper), fmt_p(s$p_value), signif_txt(s$p_value),
      if (isTRUE(s$low_events) || isTRUE(s$unstable)) {
        paste0(" This group has few deaths (fewer than ", strat$min_events,
               ") or an unstable model fit, so the estimate is imprecise.")
      } else ""
    )
  }, character(1))

  # ---- Interaction -------------------------------------------------------
  hi <- strata[which.max(strata$OR), ]
  lo <- strata[which.min(strata$OR), ]
  range_txt <- sprintf(
    "The odds ratio was highest in %s (OR %.2f) and lowest in %s (OR %.2f).",
    hi$Stratum, hi$OR, lo$Stratum, lo$OR
  )
  interaction <- if (strat$p_interaction < alpha) {
    sprintf(
      paste0("The test of the arm by %s interaction gave %s, providing ",
             "evidence that the treatment effect differed by %s. %s"),
      name, fmt_p(strat$p_interaction), name, range_txt)
  } else {
    sprintf(
      paste0("The test of the arm by %s interaction gave %s, so a ",
             "statistically significant difference in the treatment effect ",
             "by %s was not detected. %s"),
      name, fmt_p(strat$p_interaction), name, range_txt)
  }

  caveat <- paste(
    "Subgroup estimates rest on small numbers of deaths and are imprecise;",
    "they are exploratory and no adjustment was made for multiple comparisons."
  )

  list(overview = overview, strata = bullets,
       interaction = interaction, caveat = caveat,
       covariates = covs)   # readable adjustment-set text, e.g. "sex, site and MUAC"
}
