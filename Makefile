# Build the project from the repository root with `make`.
#
#   make stratified   run the parameterized stratified analysis
#   make report.pdf   render the full report (see note below)
#   make clean        delete generated stratified outputs
#
# Change what is analysed by editing config.yml (e.g. stratify_by) and
# re-running make; outputs rebuild automatically when config.yml changes.

# Locate Rscript automatically: use a standard Windows install if one exists
# (PROGRA~1 = "Program Files"), otherwise fall back to Rscript on the PATH
# (Mac/Linux). Override any time with: make RSCRIPT="path/to/Rscript"
WIN_R := $(lastword $(sort $(wildcard C:/PROGRA~1/R/R-*/bin/Rscript.exe)))
RSCRIPT ?= $(if $(WIN_R),$(WIN_R),Rscript)

# Windows + Git Bash: make can launch R without LOCALAPPDATA set, so R builds
# a wrong personal-library path (/R/win-library/...) and cannot find
# installed packages. Restore the variable when it is missing.
ifneq ($(WIN_R),)
ifeq ($(strip $(LOCALAPPDATA)),)
export LOCALAPPDATA := $(if $(USERPROFILE),$(USERPROFILE),$(HOME))/AppData/Local
endif
endif

# Input data. Update if the pipeline later produces a cleaned dataset
# (and update `data_path` in config.yml to match).
DATA = data/f75_interim.csv

.PHONY: all stratified clean doctor

all: report.pdf

# ---- Parameterized stratified analysis (hannah) ----------------------------
output/table1.rds: code/01_table1.R $(DATA)
	$(RSCRIPT) code/01_table1.R

output/table2.rds: code/02_table2.R $(DATA)
	$(RSCRIPT) code/02_table2.R

# ---- Parameterized stratified analysis (elaina) ----------------------------
# `&:` = one run of the script produces both files (needs GNU make >= 4.3).
output/stratified_table.rds output/stratified_forest.png &: \
		code/stratified_analysis.R config.yml $(DATA)
	$(RSCRIPT) code/stratified_analysis.R

stratified: output/stratified_table.rds output/stratified_forest.png

# ---- Other analysis scripts ------------------------------------------------
# Add rules here as teammates add scripts to code/, for example:
#   output/table1.rds: code/make_table1.R $(DATA)
#       $(RSCRIPT) code/make_table1.R

# ---- Report ---------------------------------------------------------------
# Add each teammate's outputs to the prerequisites as they are created.
report.html: report.Rmd report_stratified_section.Rmd \
		output/stratified_table.rds output/stratified_forest.png \
		output/table1.rds output/table2.rds
	$(RSCRIPT) -e "rmarkdown::render('report.Rmd', output_file = 'report.html')"

# Troubleshooting: show which R make uses and where it looks for packages.
doctor:
	@echo "RSCRIPT = $(RSCRIPT)"
	$(RSCRIPT) -e "print(.libPaths()); print(Sys.getenv(c('R_LIBS_USER','LOCALAPPDATA','HOME'))); print(requireNamespace('here', quietly = TRUE))"

clean:
	$(RSCRIPT) -e "unlink('output', recursive = TRUE); file.create('output/.gitkeep'); unlink('report.pdf')"
