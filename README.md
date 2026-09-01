# Statistic-analysis

# ATTICA Cardiovascular Risk Study - Statistics & Data Visualization

 Στατιστική & Οπτικοποίηση Δεδομένων (Statistics & Data Visualization)
**Title:** Ανάλυση και Οπτικοποίηση Προγνωστικών Παραγόντων Καρδιαγγειακής Νόσου: Δεκαετή και Εικοσαετή Μελέτη ("Analysis and Visualization of Predictive Factors of Cardiovascular Disease: a 10-Year and 20-Year Study")
**Author:** Σπυρίδων Τσιλιμπώκος

A single-script R analysis of ATTICA cohort data, examining which clinical and lifestyle factors predict cardiovascular disease (CVD) at 10-year and 20-year follow-up.

## Contents

| File | Role |
|---|---|
| [`stat-fin.R`](stat-fin.R) | The entire analysis (321 lines) - data prep, descriptives, hypothesis tests, regression, PCA/clustering. This is the actual "codebase." |
| [`ATTICA_FINAL_REPORT_WITH_STATS.pdf`](ATTICA_FINAL_REPORT_WITH_STATS.pdf) | Generated output of running `stat-fin.R` - every table and plot the script produces, as one multi-page PDF. Not a separately written report; it *is* the script's output. |
| [`Presentation.pptx`](Presentation.pptx) | 6-slide summary presentation of the findings. |

** source dataset, `ATTICA_20YS_STUDY.xlsx`.

## Dataset & variables

Inferred from the script and the generated report (sample size ≈142, from the logistic regression's residual degrees of freedom):

- **Quantitative:** `bmi` (derived in-script as `weight / (height/100)^2`), `sbp`, `dbp` (systolic/diastolic blood pressure), `hdl`, `ldl`, `age`.
- **Categorical:** `sex` (Male/Female), `physact_level` (Low/Moderate/High), `smoking_ever`, `htn` (hypertension), `diabetes` (used only if present in the data).
- **Outcomes (binary):** `cvd10` - CVD event within 10 years; `cvd20` - CVD event within 20 years.

## What the script does

`stat-fin.R` is organized into six labeled sections (Α–ΣΤ), all writing into one `pdf("ATTICA_FINAL_REPORT_WITH_STATS.pdf")` device:

- **A - Descriptives & visualization:** Pearson correlation heatmap across the quantitative variables; per-outcome mean/SD/median/skewness and boxplots for each quantitative variable.
- **B - Contingency tables:** crosstabs (counts + row %) and grouped barplots of each qualitative variable (`htn`, `smoking_ever`, `physact_level`) against each outcome.
- **C - Hypothesis testing:** Welch t-tests (each quantitative variable vs. each outcome), chi-square and proportion tests (`htn` vs. outcomes), one-way ANOVA + Tukey HSD (`sbp ~ physact_level`).
- **D - Multiple linear regression:** `sbp` regressed on age, sex, bmi, smoking, physical activity, dbp, hdl, ldl; includes a **hand-rolled VIF function** (regressing each predictor on the rest, `1/(1-R²)`) instead of depending on the `car` package, plus the standard 2×2 diagnostic plots.
- **E - Logistic regression:** `cvd10` and `cvd20` each regressed on age, sex, bmi, smoking, htn (and diabetes, if present); reports odds ratios with 95% CI and, when `pROC` is available, an ROC curve with AUC.
- **F - PCA & clustering:** PCA on the five cardiometabolic variables (`bmi`, `sbp`, `dbp`, `hdl`, `ldl`) with a scree plot; hierarchical clustering (single linkage, sub-sampled to 1000 rows if larger) plotted as a dendrogram and as clusters on the first two principal components.

**Defensive-coding choices worth noting** (the script's own comments explain the "why"):
- Packages are installed on demand with `if(!require(...)) install.packages(...)`; `pROC` specifically is wrapped in `try()` so the script keeps running - just skipping ROC plots - if it can't be installed (e.g. no admin rights to install as the primary user, which the header comment calls out as the actual reason).
- Every section checks column existence via `intersect(..., names(dataset))` before using a variable, so the script degrades gracefully instead of erroring if a column is absent.
- All console output (`summary()`, tables, test results) is funneled through a custom `print_text_to_pdf()` helper that captures `print()` output as text and draws it onto a blank PDF page - base R plotting devices have no built-in way to render a table/summary object as a page.

## Key results

From the generated report and the presentation:

- **Data-quality check:** the correlation heatmap shows the expected strong SBP↔DBP and weight↔BMI correlations.
- **T-tests:** almost every quantitative variable differs significantly (p<0.05) between outcome groups. For the 20-year outcome, **age** (p < 2.2×10⁻¹⁶) and **SBP** (p ≈ 1.0×10⁻⁷) are the strongest discriminators. BMI: 25.7 (no CVD10) vs. 30.2 (CVD10); SBP: 120.5 vs. 137.1.
- **Hypertension:** strongly associated with `cvd20` (χ² p = 1.4×10⁻⁴; 72% of CVD20 cases are hypertensive vs. 37% of controls), more weakly with `cvd10` (p = 0.027).
- **ANOVA:** SBP does not differ significantly across physical-activity levels in this sample (p = 0.58).
- **Multiple linear regression (SBP):** R² = 0.678 (adj. 0.604, n=49 complete cases); **DBP is the only significant independent predictor** (p ≈ 1.5×10⁻⁵); all VIFs < 2, so no multicollinearity concern.
- **Logistic regression:**
  - `cvd10` ~ age+sex+bmi+smoking+htn - **AUC = 0.765**; BMI is the only significant predictor (OR = 1.13/unit, p = 0.037).
  - `cvd20` ~ same predictors - **AUC = 0.917**; **age dominates** (OR = 1.23/year, p = 1.95×10⁻⁸).
- **PCA:** the first two components explain **68.5%** of variance in the five cardiometabolic variables; PC1 loads positively on bmi/sbp/dbp (a general "cardiometabolic burden" axis), PC2 separates HDL from LDL.
- **Overall conclusion** (per the presentation): the 20-year model outperforms the 10-year model, age and systolic blood pressure are the dominant risk factors, and the logistic model separates patients with >90% accuracy by AUC.

## How to run

Requirements: R with the `readxl` and `ggplot2` packages (both auto-installed by the script if missing); `pROC` is optional and only needed for the ROC/AUC plots.

1. Obtain `ATTICA_20YS_STUDY.xlsx` and place it in this folder (it is not included here).
2. From this directory, run:
   ```r
   Rscript "stat-fin.R"
   ```
   (or `source("stat-fin.R")` from an R session / RStudio with this folder as the working directory).
3. The script regenerates `ATTICA_FINAL_REPORT_WITH_STATS.pdf` in place.
 
