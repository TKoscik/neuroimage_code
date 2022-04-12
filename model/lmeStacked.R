stackedRegression <- function(FUNC, FIXED, RANDOM, DATA) {
  #-------------------------------------------------------------------------------------
  # Copyright (C) 2017 Koscik, Timothy R. All Rights Reserved
  #-------------------------------------------------------------------------------------
  
  
  # Check input lengths ----------------------------------------------------------------
  n.mdls <- length(FIXED)
  
  if (is.list(FUNC)) {
    if (length(FUNC) < n.mdls) {
      func.temp <- FUNC[[1]]
      FUNC <- vector("list", n.mdls)
      for (i in 1:n.mdls) { FUNC[[i]] <- func.temp }
    }
  } else {
    func.temp <- FUNC
    FUNC <- vector("list", n.mdls)
    for (i in 1:n.mdls) { FUNC[[i]] <- func.temp }
  }
  
  # Create Stacked Dataframe -----------------------------------------------------------
  n.obs <- nrow(DATA)
  
  RANDnames <- unlist(strsplit(RANDOM, split="[()1|/+ ]"))
  RANDnames <- RANDnames[RANDnames != ""]
  df <- data.frame(matrix(0, nrow=nrow(DATA) * n.mdls, ncol=length(RANDnames)))
  for (i in 1:length(RANDnames)) {
    df[ ,i] <- rep(unlist(DATA[RANDnames[i]]), n.mdls)
  }
  colnames(df) <- RANDnames
  
  df$DV <- numeric(n.obs*n.mdls)
  for (i in 1:n.mdls) {
    DVname <- all.vars(formula(FIXED[[i]]))[1]
    df$DV[(n.obs*(i-1)+1):(n.obs*i)] <- unlist(DATA[DVname])
    df[ , ncol(df)+1] <- c(rep(0,n.obs*(i-1)), rep(1,n.obs), rep(0,n.obs*(n.mdls-i)))
    colnames(df)[ncol(df)] <- paste0("S",i)
    
    IVnames <- all.vars(formula(FIXED[[i]]))
    IVnames <- IVnames[-1]
    for (j in 1:length(IVnames)) {
      df[ , ncol(df)+1] <- eval(parse(text=paste0("unlist(DATA[as.character(IVnames[j])]) * ", paste0("df$S",i))))
      colnames(df)[ncol(df)] <- paste0("IV",i, j, ".", IVnames[j])
    }
  }
  
  ## Merge Formulas --------------------------------------------------------------------
  stacked.FORM <- "DV ~ "
  for (i in 1:n.mdls) {
    stacked.FORM <- paste0(stacked.FORM, "S", i, " + ")
  }
  for (i in 1:n.mdls) {
    IVnames <- all.vars(formula(FIXED[[i]]))
    IVnames <- IVnames[-1]
    for (j in 1:length(IVnames)) {
      if (i == n.mdls & j == length(IVnames)) {
        stacked.FORM <- paste0(stacked.FORM,  paste0("IV",i, j, ".", IVnames[j]), " - 1 ")
      } else {
        stacked.FORM <- paste0(stacked.FORM,  paste0("IV",i, j, ".", IVnames[j]), " + ")
      }
    }
  }
  stacked.FORM <- paste0(stacked.FORM, " + ", RANDOM)
  
  # Run Model --------------------------------------------------------------------------
  func.ls <- unlist(FUNC)
  if (all(func.ls == "lmer")) {
    MODEL <- lmer(formula(stacked.FORM), df)
  } else if (all(func.ls == "glmer")) {
    MODEL <- glmer(formula(stacked.FORM), df,
                   family=binomial, nAGQ=1,
                   control=glmerControl(calc.derivs=FALSE,
                                        optimizer="bobyqa",
                                        optCtrl=list(maxfun=1000000)))
  } else {
    MODEL <- lmer(formula(stacked.FORM), df)
  }
  return(MODEL)
}

