# Stratified analysis of the treatment effect on mortality.
#
# Reads config.yml; for the stratifying variable chosen there
# (`stratify_by`), fits logistic regression of death on arm + covariates
# within each stratum and tests arm x stratum interaction.
#
# Inputs : config.yml, the dataset named in config `data_path`
# Outputs: output/stratified_table.rds, output/stratified_forest.png
#
# Run from the repository root:  Rscript code/stratified_analysis.R
# (or just `make`)

here::i_am("code/stratified_analysis.R")

suppressPackageStartupMessages({
  library(dplyr)
  library(ggplot2)
})

cfg <- yaml::read_yaml(here::here("config.yml"))

# ---- Read data and build analysis variables ---------------------------
d <- read.csv(here::here(cfg$data_path),
              na.strings = "NA", stringsAsFactors = FALSE)

d$died <- as.integer(d[[cfg$outcome$var]] %in% cfg$outcome$event_values)

arm_var <- cfg$exposure$var
d$arm <- relevel(factor(d[[arm_var]]), ref = cfg$exposure$reference)

# Stratum variable: either cut a continuous variable or use a factor.
if (!cfg$stratify_by %in% names(cfg$strata)) {
  stop("stratify_by = '", cfg$stratify_by, "' is not defined under `strata:` in config.yml")
}
spec <- cfg$strata[[cfg$stratify_by]]
if (!is.null(spec$breaks)) {
  d$stratum <- cut(d[[spec$var]], breaks = unlist(spec$breaks),
                   labels = unlist(spec$labels), right = FALSE)
} else {
  d$stratum <- factor(d[[spec$var]], levels = unlist(spec$levels))
}
if (anyNA(d$stratum)) {
  warning(sum(is.na(d$stratum)), " rows have no stratum and are excluded")
  d <- d[!is.na(d$stratum), ]
}

# Covariates (drop the stratifying variable itself if it is one)
cat_covs  <- setdiff(unlist(cfg$covariates$categorical), spec$var)
cont_covs <- setdiff(unlist(cfg$covariates$continuous),  spec$var)
for (v in cat_covs) d[[v]] <- factor(d[[v]])
covs <- c(cat_covs, cont_covs)
rhs  <- paste(c("arm", covs), collapse = " + ")

# ---- Helper: arm odds ratio from one logistic model --------------------
fit_arm_or <- function(dat) {
  warn <- character()
  fit <- withCallingHandlers(
    glm(as.formula(paste("died ~", rhs)), data = dat, family = binomial),
    warning = function(w) { warn <<- c(warn, conditionMessage(w)); invokeRestart("muffleWarning") }
  )
  cf <- summary(fit)$coefficients
  row <- grep("^arm", rownames(cf))
  est <- cf[row, "Estimate"]; se <- cf[row, "Std. Error"]
  data.frame(
    OR = exp(est), lower = exp(est - 1.96 * se), upper = exp(est + 1.96 * se),
    p_value = cf[row, "Pr(>|z|)"],
    unstable = length(warn) > 0 || !fit$converged || se > 10
  )
}

# ---- Stratum-specific and overall results ------------------------------
count_row <- function(dat) {
  data.frame(
    n = nrow(dat), deaths = sum(dat$died),
    n_intervention = sum(dat$arm != cfg$exposure$reference),
    deaths_intervention = sum(dat$died[dat$arm != cfg$exposure$reference]),
    n_reference = sum(dat$arm == cfg$exposure$reference),
    deaths_reference = sum(dat$died[dat$arm == cfg$exposure$reference])
  )
}

groups <- c(list(Overall = d), split(d, d$stratum))
res <- do.call(rbind, lapply(names(groups), function(g) {
  cbind(Stratum = g, count_row(groups[[g]]), fit_arm_or(groups[[g]]))
}))
rownames(res) <- NULL
res$low_events <- res$deaths < cfg$min_events_per_stratum
res$Stratum <- factor(res$Stratum, levels = rev(res$Stratum))

# ---- Interaction test (likelihood ratio) -------------------------------
rhs_strat <- paste(c("arm * stratum", covs), collapse = " + ")
rhs_add   <- paste(c("arm + stratum", covs), collapse = " + ")
full    <- glm(as.formula(paste("died ~", rhs_strat)), data = d, family = binomial)
reduced <- glm(as.formula(paste("died ~", rhs_add)),   data = d, family = binomial)
p_interaction <- anova(reduced, full, test = "LRT")[2, "Pr(>Chi)"]

# ---- Save results -------------------------------------------------------
out <- list(
  results = res,
  p_interaction = p_interaction,
  stratify_by = cfg$stratify_by,
  strat_label = spec$var,
  strat_name = if (is.null(spec$label)) cfg$stratify_by else spec$label,
  reference = cfg$exposure$reference,
  treatment = setdiff(levels(d$arm), cfg$exposure$reference)[1],
  alpha = cfg$alpha,
  covariates = covs,
  min_events = cfg$min_events_per_stratum
)
# ---- Forest plot --------------------------------------------------------
p <- ggplot(res, aes(x = OR, y = Stratum, xmin = lower, xmax = upper,
                     shape = low_events)) +
  geom_vline(xintercept = 1, linetype = "dashed", colour = "grey50") +
  geom_pointrange(orientation = "y") +
  scale_x_log10() +
  scale_shape_manual(values = c(`FALSE` = 16, `TRUE` = 1),
                     breaks = "TRUE",
                     labels = paste("Fewer than", cfg$min_events_per_stratum, "deaths"),
                     name = NULL) +
  labs(
    x = paste0("Adjusted odds ratio for death (log scale), vs ", cfg$exposure$reference),
    y = NULL,
    title = paste("Treatment effect on mortality by", cfg$stratify_by),
    subtitle = sprintf("Interaction p = %.3f; adjusted for %s",
                       p_interaction, paste(covs, collapse = ", "))
  ) +
  theme_minimal(base_size = 12)

ggsave(here::here("output", "stratified_forest.png"), p,
       width = 7, height = 3.5, dpi = 200, bg = "white")

saveRDS(out, here::here("output", "stratified_table.rds"))

message("Stratified analysis by '", cfg$stratify_by, "' complete.")
