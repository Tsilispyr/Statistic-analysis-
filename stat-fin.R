# ==============================================================================
# ATTICA STUDY (2025)
# ΣΤΑΤΙΣΤΙΚΗ & ΟΠΤΙΚΟΠΟΙΗΣΗ ΔΕΔΟΜΕΝΩΝ
# ais25118
# ==============================================================================

# ------------------------------------------------------------------------------
# 1. PACKAGES & SETUP (SAFE MODE)
# ------------------------------------------------------------------------------
# Έγινε επιλογή για τέτοια υλοποίηση λόγω μεγάλου χρόνου εκτέλεσης και εγκατάστασης βιβλιοθηκών
# παράλληλα με σφάλματα π.χ. αδυναμία πρόσβασης ώς κύριος χρήστης για εγκατάσταση πακέτων
# η λύση αυτή αποδείχθηκε αποτελεσματική και ταχύτατη
# Τα αποτελέσματα βγαίνουν σε αρχείο PDF με όνομα ATTICA_FINAL_REPORT_WITH_STATS.pdf



if(!require(readxl)) install.packages("readxl")
if(!require(ggplot2)) install.packages("ggplot2")

has_proc <- FALSE
try({
  if(!require(pROC)) install.packages("pROC")
  library(pROC)
  has_proc <- TRUE
}, silent=TRUE)

library(readxl)
library(ggplot2)



# ------------------------------------------------------------------------------
# 2. CUSTOM FUNCTIONS
# ------------------------------------------------------------------------------

# --- Συνάρτηση για εκτύπωση κειμένου (πίνακες/stats) μέσα στο PDF ---
print_text_to_pdf <- function(output_object, title = "") {
  # Μετατροπή του αποτελέσματος σε κείμενο
  text_output <- capture.output(print(output_object))
  
  # Δημιουργία κενής σελίδας
  plot.new()
  
  # Τίτλος
  title(main = title, cex.main = 1.2, font.main = 2)
  
  # Εκτύπωση κειμένου (αν είναι πολύ μεγάλο, κόβουμε τις πρώτες 40 γραμμές)
  if(length(text_output) > 40) text_output <- c(text_output[1:40], "... [Output Truncated]")
  
  # Ζωγραφίζουμε το κείμενο
  text(x = 0, y = 1, 
       labels = paste(text_output, collapse = "\n"), 
       adj = c(0, 1), cex = 0.8, family = "mono")
}

# --- Skewness (Ασυμμετρία) ---
calc_skewness <- function(x){
  x <- na.omit(x)
  if(length(x) < 3) return(NA)
  m <- mean(x); s <- sd(x)
  if(s == 0) return(NA)
  return(mean((x - m)^3) / s^3)
}

# --- Manual VIF ---
calc_vif <- function(model){
  if(is.null(model$model)) return(NULL)
  X <- model$model[, -1] # Αφαίρεση εξαρτημένης
  if(ncol(X) < 2) return(NULL)
  
  vifs <- c()
  for(v in colnames(X)){
    try({
      # R^2 του predictor v ως προς τους υπόλοιπους
      frm <- as.formula(paste(v, "~ ."))
      r2 <- summary(lm(frm, data=X))$r.squared
      vifs[v] <- 1 / (1 - r2)
    }, silent=TRUE)
  }
  return(vifs)
}



# ------------------------------------------------------------------------------
# 3. DATA IMPORT & PREPARATION
# ------------------------------------------------------------------------------
cat("Loading Data...\n")
# Βεβαιωθείτε ότι το αρχείο είναι στο Working Directory
dataset <- read_excel("ATTICA_20YS_STUDY.xlsx")
names(dataset) <- tolower(names(dataset))


# Υπολογισμός BMI
if("weight" %in% names(dataset) & "height" %in% names(dataset)) {
  dataset$bmi <- dataset$weight / ((dataset$height/100)^2)
}

# Μετατροπή σε Factors
dataset$sex <- factor(dataset$sex, labels=c("Male","Female"))
if("physact_level" %in% names(dataset)) {
  dataset$physact_level <- factor(dataset$physact_level, levels=c(1,2,3), 
                                  labels=c("Low","Moderate","High"))
}
dataset$smoking_ever <- as.factor(dataset$smoking_ever)
dataset$htn <- as.factor(dataset$htn)
dataset$cvd10 <- as.factor(dataset$cvd10)
dataset$cvd20 <- as.factor(dataset$cvd20)
if("diabetes" %in% names(dataset)) dataset$diabetes <- as.factor(dataset$diabetes)

# Ορισμός μεταβλητών
quant_vars <- c("bmi","sbp","dbp","hdl","ldl")
# Προσθέτουμε age μόνο αν υπάρχει
if("age" %in% names(dataset)) quant_vars <- c(quant_vars, "age")
quant_vars <- intersect(quant_vars, names(dataset))

outcomes <- c("cvd10","cvd20")
outcomes <- intersect(outcomes, names(dataset))


# ------------------------------------------------------------------------------
# 4. START PDF OUTPUT
# ------------------------------------------------------------------------------
pdf("ATTICA_FINAL_REPORT_WITH_STATS.pdf", width=10, height=8)


# ==============================================================================
# ΕΝΟΤΗΤΑ Α: ΠΕΡΙΓΡΑΦΙΚΑ & ΟΠΤΙΚΟΠΟΙΗΣΗ
# ==============================================================================
# Heatmap
avail_q <- intersect(names(dataset), c(quant_vars, "age"))
if(length(avail_q) > 1) {
  num_data <- na.omit(dataset[, avail_q])
  heatmap(cor(num_data), main="Heatmap Συσχετίσεων (Pearson)", 
          col=cm.colors(256), scale="none")
}

# Descriptive Stats per Outcome
for(out in outcomes){
  for(v in quant_vars){
    g0 <- dataset[[v]][dataset[[out]]==0]
    g1 <- dataset[[v]][dataset[[out]]==1]
    
    # Υπολογισμός στατιστικών
    stats_mat <- rbind(
      No_CVD = c(Mean=mean(g0,na.rm=T), SD=sd(g0,na.rm=T), Median=median(g0,na.rm=T), Skew=calc_skewness(g0)),
      Yes_CVD = c(Mean=mean(g1,na.rm=T), SD=sd(g1,na.rm=T), Median=median(g1,na.rm=T), Skew=calc_skewness(g1))
    )
    
    # 1. Εκτύπωση πίνακα στο PDF
    print_text_to_pdf(round(stats_mat, 2), title = paste("Descriptives:", v, "by", out))
    
    # 2. Boxplot
    boxplot(dataset[[v]] ~ dataset[[out]], col=c("lightblue","salmon"), 
            main=paste("Boxplot:", v, "by", out), xlab=out, ylab=v)
  }
}


# ==============================================================================
# ΕΝΟΤΗΤΑ Β: ΠΙΝΑΚΕΣ ΣΥΝΑΦΕΙΑΣ
# ==============================================================================
qual_vars <- c("htn","smoking_ever","physact_level")
qual_vars <- intersect(qual_vars, names(dataset))

# Ορίζουμε μια παλέτα χρωμάτων (αρκετά για να καλύψουν μέχρι 4-5 κατηγορίες)
my_colors <- c("lightblue", "salmon", "lightgreen", "orange", "plum")

for(out in outcomes){
  for(q in qual_vars){
    tbl <- table(dataset[[q]], dataset[[out]])
    row_props <- round(prop.table(tbl, 1) * 100, 2)
    
    # Εκτύπωση πινάκων στο PDF
    print_text_to_pdf(list(Counts=addmargins(tbl), Row_Percentages=row_props), 
                      title = paste("Crosstab:", q, "vs", out))
    
    # Barplot
    barplot(prop.table(tbl, 1), beside=TRUE, 
            main=paste(q, "vs", out, "(Row %)"),
            col=my_colors[1:nrow(tbl)],
            legend=rownames(tbl),
            args.legend = list(x = "topright", bty = "n"))
  }
}


# ==============================================================================
# ΕΝΟΤΗΤΑ Γ: ΕΛΕΓΧΟΙ ΥΠΟΘΕΣΕΩΝ
# ==============================================================================

# T-tests results collector
ttest_results <- list()
for(out in outcomes){
  for(v in quant_vars){
    tt <- t.test(dataset[[v]] ~ dataset[[out]])
    ttest_results[[paste(v, "vs", out)]] <- c(p_value = format.pval(tt$p.value))
  }
}
print_text_to_pdf(do.call(rbind, ttest_results), title = "Summary of T-tests (P-values)")

# Chi-Square & Prop Tests
for(out in outcomes){
  if("htn" %in% names(dataset)){
    tbl <- table(dataset$htn, dataset[[out]])
    
    res_prop <- prop.test(tbl)
    res_chi <- chisq.test(tbl)
    
    print_text_to_pdf(list(Prop_Test = res_prop, Chi_Sq = res_chi), 
                      title = paste("HTN vs", out, "- Statistical Tests"))
  }
}

# ANOVA
if("sbp" %in% names(dataset) & "physact_level" %in% names(dataset)){
  anova_mod <- aov(sbp ~ physact_level, data=dataset)
  tukey_res <- TukeyHSD(anova_mod)
  
  print_text_to_pdf(summary(anova_mod), title = "ANOVA: SBP ~ Physical Activity")
  print_text_to_pdf(tukey_res, title = "Tukey Post-Hoc Test")
}


# ==============================================================================
# ΕΝΟΤΗΤΑ Δ: ΠΟΛΛΑΠΛΗ ΓΡΑΜΜΙΚΗ ΠΑΛΙΝΔΡΟΜΗΣΗ
# ==============================================================================
# Φτιάχνουμε δυναμικά τη φόρμουλα για να αποφύγουμε errors αν λείπουν στήλες
preds_lm <- intersect(c("age", "sex", "bmi", "smoking_ever", "physact_level", "dbp", "hdl", "ldl"), names(dataset))

if("sbp" %in% names(dataset) & length(preds_lm) > 0){
  f_lm <- as.formula(paste("sbp ~", paste(preds_lm, collapse=" + ")))
  lm_mod <- lm(f_lm, data=dataset)
  
  # Εκτύπωση αποτελεσμάτων στο PDF
  print_text_to_pdf(summary(lm_mod), title = "Multiple Linear Regression (SBP)")
  
  # VIF
  vifs <- calc_vif(lm_mod)
  print_text_to_pdf(round(vifs, 2), title = "VIF Values (Multicollinearity Check)")
  
  # Plots
  par(mfrow=c(2,2)); plot(lm_mod); par(mfrow=c(1,1))
}


# ==============================================================================
# ΕΝΟΤΗΤΑ Ε: ΛΟΓΙΣΤΙΚΗ ΠΑΛΙΝΔΡΟΜΗΣΗ
# ==============================================================================
preds_log <- intersect(c("age", "sex", "bmi", "smoking_ever", "htn", "diabetes"), names(dataset))

if(length(preds_log) > 0){
  for(out in outcomes){
    f_log <- as.formula(paste(out, "~", paste(preds_log, collapse=" + ")))
    
    log_mod <- glm(f_log, data=dataset, family=binomial)
    
    # Summary
    print_text_to_pdf(summary(log_mod), title = paste("Logistic Regression:", out))
    
    # Odds Ratios
    ors <- exp(coef(log_mod))
    ci <- exp(confint.default(log_mod))
    or_table <- cbind(OR = ors, ci)
    print_text_to_pdf(round(or_table, 3), title = paste("Odds Ratios & 95% CI:", out))
    
    # ROC Plot
    if(has_proc){
      try({
        prob <- fitted(log_mod)
        roc_obj <- roc(dataset[[out]], prob, quiet=TRUE)
        plot(roc_obj, main=paste("ROC Curve:", out), print.auc=TRUE, col="blue")
      }, silent=TRUE)
    }
  }
}


# ==============================================================================
# ΕΝΟΤΗΤΑ ΣΤ: PCA & CLUSTERING
# ==============================================================================
pca_vars <- intersect(c("bmi", "sbp", "dbp", "hdl", "ldl"), names(dataset))
pca_data <- na.omit(dataset[, pca_vars])

if(ncol(pca_data) >= 3){
  # PCA
  pca <- prcomp(scale(pca_data))
  
  print_text_to_pdf(summary(pca), title = "PCA Summary")
  print_text_to_pdf(round(pca$rotation[,1:2], 3), title = "PCA Loadings (First 2 Components)")
  
  # Scree Plot
  plot(pca, type="l", main="Scree Plot")
  abline(h=1, lty=2, col="red")
  
  # Clustering
  # Χρήση δείγματος αν είναι πολύ μεγάλο το dataset
  data_for_clust <- scale(pca_data)
  if(nrow(data_for_clust) > 1000) data_for_clust <- data_for_clust[sample(1:nrow(data_for_clust), 1000), ]
  
  hc <- hclust(dist(data_for_clust), method="single")
  plot(hc, main="Dendrogram (Single Linkage)", labels=FALSE, xlab="")
  
  # Scatterplot on PCA
  clusters <- cutree(hc, k=3)
  # Πρέπει να υπολογίσουμε τα scores ξανά για το δείγμα αν έγινε sampling
  if(nrow(data_for_clust) != nrow(pca_data)) {
    pca_samp <- prcomp(data_for_clust)
    scores <- as.data.frame(pca_samp$x)
  } else {
    scores <- as.data.frame(pca$x)
  }
  
  plot(scores$PC1, scores$PC2, col=clusters, pch=19, 
       xlab="PC1", ylab="PC2", 
       main="PCA Factors with Single Linkage Clusters")
legend("topright", legend=unique(clusters), col=unique(clusters), pch=19, title="Cluster")
  
}

dev.off()
cat("\nΟλοκληρώθηκε! Ανοίξτε το αρχείο 'ATTICA_FINAL_REPORT_WITH_STATS.pdf'.\n")