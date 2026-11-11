# DATA 550 Midterm Project: Analysis of f75 Dataset

This is the Github repository which contains all code for the midterm project analysis. The repository contains the following subfolders:

data: contains the f75 dataset.

code: includes R scripts to generate required tables and figures for report rendering.

output: contains outputted files from R scripts.

## Building with make

Run all commands from the repository root.

| Command | What it does |
|---|---|
| `make stratified` | Runs the parameterized stratified mortality analysis (`code/stratified_analysis.R`) and writes `output/stratified_table.rds` and `output/stratified_forest.png`. |
| `make report.pdf` | Renders `report.Rmd` to `report.pdf`. |
| `make clean` | Deletes the generated stratified outputs and `report.pdf`. |
| `make doctor` | Troubleshooting only (see below). Does not build anything. |

`make` only rebuilds a file when its inputs (the script, `config.yml` or the data) have changed. If it says "Nothing to be done", the outputs are already up to date; run `make clean` first to force a rebuild.

### Parameterized analysis (`config.yml`)

The stratified analysis is controlled by `config.yml`. Set `stratify_by` to `sex` or `age_cat` (age groups 6-11, 12-23 and 24+ months, defined by `breaks` and `labels` under `strata:`), then re-run `make stratified`. The same file sets the data path, outcome definition, reference arm and adjustment covariates.

### Requirements

- R, with the packages `here`, `yaml`, `dplyr` and `ggplot2`.
- GNU make 4.3 or newer.
- `Rscript` on your PATH, or a standard Windows R install (the Makefile looks for one automatically). To use a specific R, run `make RSCRIPT="path/to/Rscript" stratified`.

### Troubleshooting with `make doctor`

`make doctor` runs R the same way `make` does and prints:

1. which `Rscript` make is using (`RSCRIPT`),
2. the folders R searches for packages (`.libPaths()`) and the values of `R_LIBS_USER`, `LOCALAPPDATA` and `HOME`,
3. whether the `here` package can be found (`TRUE` or `FALSE`).

Use it when `make` fails with an error such as `there is no package called 'here'`. Compare its output with what R reports when you run it directly in your terminal; a difference (for example, a missing package folder) usually explains why make fails when running the script by hand works. On Windows with Git Bash, `make` can start R without the `LOCALAPPDATA` variable, which makes R look for packages in `/R/win-library/...` instead of your real library; the Makefile now restores that variable automatically. If `here` still shows `FALSE`, install the packages with `install.packages(c("here", "yaml", "dplyr", "ggplot2"))`.
