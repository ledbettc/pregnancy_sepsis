Table1 <- function(rowvars, colvariable, data, row_var_names = NULL, 
                   incl_missing = F, incl_pvalues = T, 
                   emphasis = c('s', 'b', 'n')) {
  # determing if data is a design object or data frame
  weighted <- F
  if (!is.data.frame(data)){
    classData <- class(data)
    if('survey.design' %in% classData) {
      if (!requireNamespace('survey', quietly = T)) {
        stop('Survey Package is required for weighted tables')
      }
      design <- data
      data <- design$variables[0,]
      weighted <- T
      if (incl_missing == T) {
        warning('Missing is turned off for weighted tables')
        incl_missing <- F
      }
    } else {
        stop('Data is not a data frame or design object')
      }
  }
  
  # do not include p_values if data is not stratified
  # setup dummy variable for unstratified data
  if (is.null(colvariable)) {
    incl_pvalues <- F
    data$dummy <- factor(rep('', nrow(data)))
    colvariable <- 'dummy'
    if (weighted == T){
      design$variables$dummy <- factor(rep('', nrow(design$variables)))
    }
  }

  # Warn users p_values are not calculated on missing obs
  if (incl_missing == T & incl_pvalues == T) {
    warning('P values are only calculated on non-missing observations')
  }
  
  #check that all arguments are valid 
  if (!is.atomic(rowvars)) stop("Please pass row variables as a vector")
  
  if (weighted == T) {
    if (length(unique(design$variables[, colvariable])) > 20) {
      stop(paste0("Column Variable has more than 20 unique values,", 
                  "please pass a column variable with less", 
                  "than 20 unique values"))
    }
    
    if (!is.factor(design$variables[, colvariable])) {
      design$variables[, colvariable] <- 
            factor(design$variables[, colvariable])
      data[, colvariable] <- factor(design$variables[, colvariable])[0]
    }
  } 
  
  if (length(unique(data[, colvariable])) > 20) {
    stop(paste0("Column Variable has more than 20 unique values,", 
         "please pass a column variable with less than 20 unique values"))
  }
  
  if (!is.factor(data[, colvariable])) {
    data[, colvariable] <- factor(data[, colvariable])
  }
  
  if (!is.null(row_var_names) & length(rowvars) != length(row_var_names)){
    stop("Length of Row Variable Names is not equal to Row Variables")
  }
    
  if (length(unique(rowvars)) != length(rowvars)){
    stop('You may not pass duplicate row variables')
  }
  
  # set numeric colvariable and rownames to character names so they 
  # can be used in formula arguments also names will be used in table
  if (is.numeric(rowvars)){
    rowvars <- names(data)[rowvars]
  }
  
  if (is.numeric(colvariable))  colvariable <- names(data)[colvariable]

  #set column names
  if (weighted == T) {
    Col_n <- survey::svytable(as.formula(paste0("~", colvariable)),
                      design, round = T)
  } else {
    Col_n <- table(data[, colvariable])
  }
  
  p_str <- NULL
  if(incl_pvalues == T) p_str <- 'p_value'
  spacer <- ifelse(colvariable == 'dummy', '(N=', ' (n=')
  cnames <- c(paste0(levels(data[, colvariable]), spacer,  
                     format(Col_n, big.mark = ',', trim = T), 
                     ")"), p_str)
  
  #col dimensions
  col_dim <- length(levels(data[, colvariable]))
  
  # determine row types and names
  vartypes <- lapply(rowvars, function(i) {is.factor(data[, i])})
  catvars <- rowvars[vartypes == T]
               
  
  #add missing level for factors 
  if(incl_missing == T) {
    for(i in catvars){
      if(any(is.na(data[,i]))){
        levels(data[,i]) <- c(levels(data[,i]),'Missing')
        data[,i][is.na(data[,i])] <- 'Missing'
      }
    }; remove(i)
  }
  
  # set row name emphasis
  emphasis <- match.arg(emphasis)
  fxn <- function(i, title) {
    switch(emphasis, 
           s = c(title, paste0("\\  ",levels(data[,i]))), 
           b = c(paste0('**', title, '**'), levels(data[,i])), 
           n = c(title, levels(data[,i])))
  }
  
  # get number of levels for categorical variables and set rownames
  numlevels <- lapply(catvars, function(i) {length(levels(data[, i]))})
  
  binaryvars <- catvars[numlevels == 2]
  binarylabs <- sapply(binaryvars, function(i){
    title <- i
    lab <- fxn(i, title)[1:2]
    return(lab)
  })
  
  nonbinary <- catvars[!(numlevels == 2)]
  nonbinlab <- sapply(nonbinary, function(x){
    title <- x
    lab <- fxn(x, title)
    return(lab)
    })
  
  # continous variables 
  contvars <- rowvars[vartypes == F]

  continuous_labels <- contvars
  
  if(emphasis == 'b') {
    continuous_labels <- paste0('**', continuous_labels, '**')
  }
  
  # if missing are included add a line for the missing count
  if(incl_missing == T & length(contvars) != 0) {
    continuous_labels  <- unlist(
      lapply(1:length(contvars), function(x){
        if (sum(is.na(data[,contvars[x]])) >0){
          emp <- ''
          # add slashes for indent if set
          if (emphasis == 's') emp <- '\\ '
          return(list(continuous_labels[x], 
                      paste0(emp, 'Missing N(%)')))
        }
        return(continuous_labels[x])
      }))
  }
  
  
   
  # put together all rownames
  rnames <- unlist(c(" ", binarylabs, nonbinlab," ",continuous_labels))
  
  #remove extra rows if no categorical/continous variables exist
  if (length(catvars) == 0) {
    rnames <- unlist(c(" ",continuous_labels))
  }
  if (length(contvars) == 0){
    rnames <- unlist(c(" ", binarylabs, nonbinlab))
  }
 
  # replace variable names with row variable names if they were provided
  if(!is.null(row_var_names)){
    tmp <- rowvars
    if (emphasis == 'b') {
      tmp <- paste0('**', rowvars, '**')
      row_var_names <- paste0('**', row_var_names, '**')
    }
    n <- match(tmp, rnames)
    rnames[n] <- row_var_names
  }
    
  # function to return rows for categorical variables
  returnRowCat <- function(var, r){
    levs <- length(levels(data[,var])) - r
    if (weighted == T){
      n <- survey::svytable(as.formula(paste0("~", var, ' + ', 
                                      colvariable)), design, 
                    round = T)
    } else {
      n <- table(data[, var],data[, colvariable])
    }
    p <- NULL
    repp <- 0
    # if requested get p-value using a univariable logisitic regression and a 
    # liklihood ratio test
    if (incl_pvalues == T){
      if (weighted == T){
        p <- survey::svychisq(as.formula(paste0("~", var, ' + ', 
                                        colvariable)), design, 
                              statistic = 'F')$p.value
      } else {
        p <- anova(glm(as.formula(paste0(colvariable, "~", var)), 
                     data = data, 
                     family = binomial()), test = 'LRT')$`Pr(>Chi)`[2]
      }
      p <- ifelse(p < 0.000001, '<0.000001', sprintf('%.6f',p))
      repp <- levs
    }
    
    percent <- t(sapply(1:levs, function(i){round(n[i,] / apply(n,2,sum) 
                                                  * 100, digits = 0)}))
    n_per <- cbind(matrix(paste0(format(n[1:levs,], big.mark = ',', trim = T), 
                                 "(", percent, ")"), nrow = levs, 
                          byrow = F), rep(" ", repp))
    returnRow <- rbind(c(rep(" ", col_dim), p), n_per)
    return(returnRow)
  }

  # function to return continuous rows 
  returnRowContinuous <- function(var){
    # make table with mean and sd
    if (weighted == T){ 
      summ <- survey::svyby(formula = as.formula(paste0("~", var)),
                    by = as.formula(paste0("~", colvariable)), 
                    FUN = survey::svymean, design = design, na.rm = T)
      # convert to same structure as unweighted summary
      summ <- matrix(c(summ[,2], summ[,3]), nrow = 2, byrow = T)
    } else {
      summ <- sapply(levels(data[, colvariable]), function(i) {
        mean <- mean(data[, var][data[, colvariable] == i], 
                   na.rm = T)
        sd <- sd(data[, var][data[, colvariable] == i], 
               na.rm = T)
        return(c(mean, sd))
      })
    }
    
    p <- NULL
    # return p-value if requested using anova
    if (incl_pvalues == T){
      if (weighted == T) {
        p <- summary(survey::svyglm(as.formula(paste0(colvariable, "~", var)),
                            design = design, 
                            family = 'quasibinomial'))$coefficients[2, 4]
      } else {
        p <- summary(aov(as.formula(paste0(var, "~", colvariable)), 
          data = data))[[1]][5][1, ]
      }
      p <- ifelse(p < 0.000001, '<0.000001', sprintf('%.6f',p))
    }
    
    #round mean and sd appropriately
    if (abs(summ[1, 1]) >= 10){
      m_sd <- paste0(round(summ[1, ], digits = 0), "(", 
                     round(summ[2, ], digits = 0), ")")
    } else{
      if (abs(summ[1, 2]) >= 1){
        m_sd <- paste0(sprintf('%.1f', summ[1, ]), "(",
                       sprintf('%.1f', summ[2, ]), ")")
      } else{
        if (abs(summ[1, 2]) >= 0.1){
          m_sd <- paste0(sprintf('%.2f', summ[1, ]), "(",
                         sprintf('%.2f', summ[2, ]), ")")
        } else{
          if (abs(summ[1,2]) >= 0.01){
            m_sd <- paste0(sprintf('%.3f', summ[1, ]), "(",
                           sprintf('%.3f', summ[2, ]), ")")
          }
          m_sd <- paste0(sprintf('%.2e', summ[1, ]), "(",
                           sprintf('%.2e', summ[2, ]), ")")
          }}}
    returnRow <- matrix(c(m_sd, p), nrow = 1, byrow = T)
    
    # add row for missing if requested
    if (incl_missing == T & sum(is.na(data[, var])) > 0){
      N <- sapply(levels(data[, colvariable]), function(i){
             sum(is.na(data[, var][data[, colvariable] == i]))
                 })
      pct <- as.vector(round(
        (N/table(data[, colvariable])) * 100,0))
      spacer <- NULL
      if (incl_pvalues == T){
        spacer <- ' '
      }
      N_pct <- c(paste0(N[], '(', pct[], ")"), spacer)
      returnRow <- matrix(c(returnRow, N_pct), nrow = 2, byrow = T)
    }
    return(returnRow)
  }
  
  #put together table
  rowheadercat <- NULL
  rowheadercont <- NULL
  cattable <- NULL
  conttable <- NULL
  if (length(catvars) != 0){
    cattable <- do.call(rbind, 
                        lapply(c(lapply(binaryvars, returnRowCat, r = 1), 
                                 lapply(nonbinary, returnRowCat, r = 0)), 
                               data.frame, stringsAsFactors=FALSE))
    names(cattable) <-  c(1:length(cattable))
    rowheadercat <- rep("N(%)", col_dim)
    if(incl_pvalues == T){
      rowheadercat <- c(rowheadercat, '')
    }
  }
  if (length(contvars) != 0){
    conttable <- do.call(rbind, 
                         lapply(lapply(contvars, returnRowContinuous), 
                                data.frame, stringsAsFactors=FALSE))
    names(conttable) <- c(1:length(conttable))
    rowheadercont <- rep("Mean(SD)", col_dim)
    if(incl_pvalues == T){
      rowheadercont <- c(rowheadercont, '')
    }
  }
  
  
  finaltab <- as.matrix(rbind.data.frame(rowheadercat, 
                                         cattable, 
                                         rowheadercont, 
                                         conttable,
                                         stringsAsFactors = F))


  dimnames(finaltab) <- list(rnames, cnames)
  return(finaltab)
}


