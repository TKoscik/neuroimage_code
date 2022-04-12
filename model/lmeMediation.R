mlm.mediation <- function(FUNC.xm, FIXED.xm,
                          FUNC.xmy, FIXED.xmy,
                          RANDOM, DATA,
                          x.name, m.name,
                          confidence = 95,
                          sensitivity = 0,
                          plot = FALSE) {
  #-------------------------------------------------------------------------------------
  # Copyright (C) 2017 Koscik, Timothy R. All Rights Reserved
  #-------------------------------------------------------------------------------------
  
  # Run Models
  if (FUNC.xm == "lmer" & FUNC.xmy == "lmer") {
    mdlA <- lmer(formula(paste0(FIXED.xm, " + ", RANDOM)), DATA)
    mdlB <- lmer(formula(paste0(FIXED.xmy, " + ", RANDOM)), DATA)
    mdlAB <- mlm.stacked(FUNC = list(FUNC.xm, FUNC.xmy),
                         FIXED = list(FIXED.xm, FIXED.xmy),
                         RANDOM = RANDOM,
                         DATA = DATA)
    x.colAB <- 2 + which(x.name == labels(terms(mdlA)))
    m.colAB <- 2 + length(labels(terms(mdlA))) + which(m.name == labels(terms(mdlB)))
    covAB <- vcov(mdlAB)
    covMx <- matrix(c(
      covAB[m.colAB, m.colAB], covAB[m.colAB, x.colAB],
      covAB[x.colAB, m.colAB], covAB[x.colAB, x.colAB]),
      2,2)
    x.colA <- 1 + which(x.name == labels(terms(mdlA)))
    A <- fixef(mdlA)[x.colA]
    m.colB <- 1 + which(m.name == labels(terms(mdlB)))
    B <- fixef(mdlB)[m.colB]
  } else if (FUNC.xm == "glmer" & FUNC.xmy == "glmer") {
    
  } else {
    if (FUNC.xm == "lmer") {
      mdlA <- lmer(formula(paste0(FIXED.xm, " + ", RANDOM)), DATA)
    } else {
      mdlA <- glmer(formula(paste0(FIXED.xm, " + ", RANDOM)), DATA,
                    family=binomial, nAGQ=1,
                    control=glmerControl(calc.derivs=FALSE,
                                         optimizer="bobyqa",
                                         optCtrl=list(maxfun=1000000)))
    }
    if (FUNC.xmy == "lmer") {
      mdlB <- lmer(formula(paste0(FIXED.xmy, " + ", RANDOM)), DATA)
    } else {
      mdlB <- glmer(formula(paste0(FIXED.xmy, " + ", RANDOM)), DATA,
                    family=binomial, nAGQ=1,
                    control=glmerControl(calc.derivs=FALSE,
                                         optimizer="bobyqa",
                                         optCtrl=list(maxfun=1000000)))
    }
    mdlAB <- mlm.stacked(FUNC = list(FUNC.xm, FUNC.xmy),
                         FIXED = list(FIXED.xm, FIXED.xmy),
                         RANDOM = RANDOM,
                         DATA = DATA)
    x.colAB <- 2 + which(x.name == labels(terms(mdlA)))
    m.colAB <- 2 + length(labels(terms(mdlA))) + which(m.name == labels(terms(mdlB)))
    covAB <- vcov(mdlAB)
    covAB <- matrix(c(
      covAB[m.colAB, m.colAB], covAB[m.colAB, x.colAB],
      covAB[x.colAB, m.colAB], covAB[x.colAB, x.colAB]),
      2,2)
    slopeCorrAB = cov2cor(covAB)[2,1]
    
    x.colA <- 1 + which(x.name == labels(terms(mdlA)))
    A <- fixef(mdlA)[x.colA]
    covA <- vcov(mdlA)
    
    m.colB <- 1 + which(m.name == labels(terms(mdlB)))
    B <- fixef(mdlB)[m.colB]
    covB <- vcov(mdlB)
    
    slopeCorrAB = slopeCorrAB * sqrt(covA[x.colA, x.colA] * covB[m.colB, m.colB])
    
    covMx <- matrix(c(
      covA[x.colA, x.colA], slopeCorrAB,
      slopeCorrAB, covB[m.colB, m.colB]),
      2, 2)
  }
  
  rep <- 20000
  # conf <- 95
  pest <- c(A, B)
  mcmc <- mvrnorm(rep, pest, covMx, empirical=FALSE)
  AB <- mcmc[ ,1] * mcmc[ ,2]
  low <- (1 - confidence/100)/2
  upp <- ((1 - confidence/100)/2) + (confidence/100)
  LL <- quantile(AB, low)
  UL <- quantile(AB, upp)
  
  if (!is.null(sensitivity[1])) {
    sensitivity.AB <- matrix(0, nrow=rep, ncol=length(sensitivity))
    sensitivity.LL <- numeric(length(sensitivity))
    sensitivity.UL <- numeric(length(sensitivity))
    for (i in 1:length(sensitivity)) {
      tempSlope <- cov2cor(covAB)[2,1]
      tempSlope <- tempSlope + sensitivity[1]
      tempSlope <- tempSlope * sqrt(covMx[1,1] * covMx[2,2])
      tempMx <- matrix(c(
        covMx[1,1], tempSlope,
        tempSlope, covMx[2,2]),
        2, 2)
      
      mcmc <- mvrnorm(rep, pest, tempMx, empirical=FALSE)
      sensitivity.AB[ ,i] <- mcmc[ ,1] * mcmc[ ,2]
      sensitivity.LL[i] <- quantile(sensitivity.AB[ ,i], low)
      sensitivity.UL[i] <- quantile(sensitivity.AB[ ,i], upp)
    }
  }
  
  if (plot) {
    plotf <- data.frame(xvar=AB)
    ggplot(plotf, aes(x=xvar)) + theme_bw() +
      geom_histogram(bins=50) +
      xlab("") + ylab("Frequency") +
      ggtitle("Distribution of Indirect Effect") +
      geom_vline(xintercept = LL, color="#000000", linetype="dashed") +
      geom_vline(xintercept = UL, color="#000000", linetype="dashed") +
      theme(legend.position="none")
      
    # hist(AB,
    #      breaks='FD',
    #      col='skyblue',
    #      xlab=paste(conf,'% Confidence Interval ','LL',LL4,'  UL',UL4),
    #      main='Distribution of Indirect Effect')
  }
  
  output <- list()
  output$A <- A
  # output$covA <- covA
  output$B <- B
  # output$covB <- covB
  output$AB <- AB
  output$LL <- LL
  output$UL <- UL
  if (sensitivity) {
    output$sensitivity <- list()
    output$sensitivity$AB <- sensitivity.AB
    output$sensitivity$LL <- sensitivity.LL
    output$sensitivity$UL <- sensitivity.UL 
  }
  return(output)
  
  
}
