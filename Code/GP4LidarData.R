##############################################################################
# Analyzing LIDAR data using Gaussian Process Regression
# Author: Mattias Villani, Stockholm and Linkoping University. 
# http://mattiasvillani.com
##############################################################################


####################################
# User settings
####################################

# Data
load("Data/lidar.RData") # loading the data
x = distance
y = logratio

# Prior hyperparameters
sigmaNoise = 0.05 # Noise standard deviation
sigmaf = 0.4 #0.5      # prior stdev for f
ell = 0.3# 0.2           # length scale in kernel
kernelName = "Matern32" # Kernel function. Options: "Matern32", "SquaredExp".
priorMean = rep(0,length(y)) # Prior mean must be zero in this code. Sorry!

####################################
# Setting path, loading packages, color settings
####################################
setwd('~/Dropbox/Teaching/WinterConfHemavan2019/')

#install.packages("kernlab")
#install.packages("mvtnorm")
#install.packages("pracma")
#install.packages("spatstat")
#install.packages("RColorBrewer")
library(kernlab) # Used to compute the covariance matrix K from a kernel function k(x',x)
library(mvtnorm)
library(pracma)
library(spatstat)
library(RColorBrewer)
plotColors = brewer.pal(12, "Paired")
pointColor = plotColors[5] # Color for single dots
lwdDef = 3                 # Default line thickness
lwdThin = 6
lwdThinner = 3
pointSizeDef = 4
cexLabDef = 1.5            # Default scaling of font size labels
cexAxisDef = 1             # Default scaling of tick labels

#####################################
# Defining the kernel
####################################
if (strcmpi(kernelName,"SquaredExp")){
  k <- function(sigmaf = 1, ell = 1)  
  {   
    rval <- function(x, y = NULL) 
    {       
      r = sqrt(crossprod(x-y))       
      return(sigmaf^2*exp(-r^2/(2*ell^2)))     
    }   
    class(rval) <- "kernel"   
    return(rval) 
  }
}

if (strcmpi(kernelName,"Matern32")){
  k <- function(sigmaf = 1, ell = 1)  
  {   
    rval <- function(x, y = NULL) 
    {	r = sqrt(crossprod(x-y))
    return(sigmaf^2*(1+sqrt(3)*r/ell)*exp(-sqrt(3)*r/ell))   
    }   
    class(rval) <- "kernel"   
    return(rval) 
  }
}

if (!exists("k")){
  stop("Invalid name of kernel function.")
}

####################################
### GP inference
####################################

# Set up the kernel function
kernelFunc <- k(sigmaf = sigmaf, ell = ell)

# Plotting the prior correlation function
zGrid <- seq(0.01, 1, by = 0.01)
count = 0
covs = rep(0,length(zGrid))
for (z in zGrid){
  count = count + 1
  covs[count] <- kernelFunc(0,z)/(sigmaf^2)
}
par(cex.lab=cexLabDef, cex.axis = cexAxisDef)
plot(zGrid, covs, axes = FALSE, type = "l", xlab = "|x'-x|", ylab = "Correlation", 
     col = plotColors[2], lwd = lwdDef, main = paste("Length scale = ",ell))
axis(side = 1, at = seq(0, 1, by = 0.2))
axis(side = 2, at = seq(0, 1, by = 0.2), pos = -0.05)

# Compute the covariance matrix Cov(f)

xs = seq(min(x),max(x), length.out = 100)
n <- length(x)
Kss <- kernelMatrix(kernel = kernelFunc, x = xs, y = xs)
Kxx <- kernelMatrix(kernel = kernelFunc, x = x, y = x)
Kxs <- kernelMatrix(kernel = kernelFunc, x = x, y = xs)
meanPred <- t(Kxs)%*%solve(Kxx + sigmaNoise^2*diag(n), y) # Predicting the training data.
Covf = Kss-t(Kxs)%*%solve(Kxx + sigmaNoise^2*diag(n), Kxs)

# Plot the data
par(cex.lab=cexLabDef, cex.axis = cexAxisDef)
plot(x, y, col = "black", cex=0.3, xlab = 'Distance', lwd = lwdDef,
     axes=FALSE, ylim = c(-1, 0.2), ylab = 'LogRatio', main = '')
axis(side = 1, at = seq(0, 1, by = 0.2))
axis(side = 2, at = seq(-1, 0.2, by = 0.2), pos = -0.05)

# Plot the mean for f
lines(xs, meanPred, lwd = lwdDef, col = plotColors[6])

# Probability intervals for f
lines(xs, meanPred - 1.96*sqrt(diag(Covf)), lwd = lwdDef, col = plotColors[2])
lines(xs, meanPred + 1.96*sqrt(diag(Covf)), lwd = lwdDef, col = plotColors[2])

# Prediction intervals for y 
lines(xs, meanPred - 1.96*sqrt((diag(Covf) + sigmaNoise^2)), lwd = lwdDef,col = plotColors[1])
lines(xs, meanPred + 1.96*sqrt((diag(Covf) + sigmaNoise^2)), lwd = lwdDef, col = plotColors[1])

legend("bottomleft", inset = 0.03, legend = c("data","post mean","95% intervals for f", "95% predictive intervals for y"), 
       col = c("black", plotColors[6], plotColors[2], plotColors[1]), 
       pch = c('o',NA,NA,NA), lty = c(NA,1,1,1), lwd = 2, cex = 0.8)

# Define the log marginal likelihood function
logMargLike <- function(logTheta, y, x, k, priorMean, sigmaNoise, verbose){
  kernelFunc <- k(sigmaf = exp(logTheta[1]), ell = exp(logTheta[2]))
  K <- kernelMatrix(kernel = kernelFunc, x = x, y = x)
  n <- length(y)
  lml = dmvnorm(x = y, mean = priorMean, 
                        sigma = K + sigmaNoise^2*diag(n), log = TRUE)
  if (verbose) print( c(exp(logTheta[1]),exp(logTheta[2]),lml))
  return(lml)
}

nTrain <- length(y)
initVal = c(log(sigmaf),log(ell))
# Optimize the marginal likelihood
OptimResults<-optim(initVal, logMargLike, gr=NULL, y, x, k, priorMean, 
                    sigmaNoise, verbose = TRUE, method=c("BFGS"), control=list(fnscale=-1), 
                    hessian=TRUE)
theta = exp(OptimResults$par)
print(theta)

# Plotting the log marginal likelihood in (sigmaf,ell)-space
# Uncomment if you have the time!
# sigmafs = seq(0.01,1,length = 50)
# ells = seq(0.01,1,length = 50)
# logMargLikes = matrix(NA, length(sigmafs), length(ells))
# countSigmaf = 0
# for (sigmaf in sigmafs){
#   print(paste("sigmaf = ", sigmaf))
#   countSigmaf = countSigmaf + 1
#   countEll = 0
#   for (ell in ells){
#     countEll = countEll + 1
#     theta = c(sigmaf,ell)
#     logMargLikes[countSigmaf, countEll] = logMargLike(log(theta), y, x, k, priorMean, sigmaNoise, verbose = FALSE)
#   }
# }
