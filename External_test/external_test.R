setwd('D:\\Peptide prediction\\Antihypertensive peptides\\CLassification\\AHTP')
library(caret)
library(randomForest)
library(Interpol)
library(protr)
library(seqinr)
###########################
m =20
ACCtr  <- matrix(nrow = m, ncol = 1)
SENStr  <- matrix(nrow = m, ncol = 1)
SPECtr  <- matrix(nrow = m, ncol = 1)
MCCtr  <- matrix(nrow = m, ncol = 1)
ACCts  <- matrix(nrow = m, ncol = 1)
SENSts  <- matrix(nrow = m, ncol = 1)
SPECts  <- matrix(nrow = m, ncol = 1)
MCCts  <- matrix(nrow = m, ncol = 1)

#######Read data
x <- read.fasta('allall.fasta', seqtype="AA", as.string = TRUE)
D = read.csv("Label all.csv", header = TRUE) 
m = length(x)
aac <- t(sapply(x, extractAAC))
dpc <- t(sapply(x, extractDC))
data = data.frame(aac,dpc,Class = D[,ncol(D)])
Pos = subset(data, Class == 'AHTP')
Neg = subset(data, Class == 'nonAHTP')
cross = 10
###############################customRF
customRF <- list(type = "Classification", library = "randomForest", loop = NULL)
customRF$parameters <- data.frame(parameter = c("mtry", "ntree"), class = rep("numeric", 2), label = c("mtry", "ntree"))
customRF$grid <- function(x, y, len = NULL, search = "grid") {}
customRF$fit <- function(x, y, wts, param, lev, last, weights, classProbs, ...) {
  randomForest(x, y, mtry = param$mtry, ntree=param$ntree, ...)
}
customRF$predict <- function(modelFit, newdata, preProc = NULL, submodels = NULL)
   predict(modelFit, newdata)
customRF$prob <- function(modelFit, newdata, preProc = NULL, submodels = NULL)
   predict(modelFit, newdata, type = "prob")
customRF$sort <- function(x) x[order(x[,1]),]
customRF$levels <- function(x) x$classes

for (i in 1:m){
#######  Dividing Training and Testing sets on positive and negative classes
sample1 <- c(sample(1:1066 ,800))
sample2 <- c(sample(1:1066,800))
  train1  <- Pos[sample1,] ####Positive set for training
  train2  <- Neg[sample2,] ####Negative set for training
  test1 <-   Pos[-sample1,]    ####Positive set for testing
  test2 <-   Neg[-sample2,]    ####Negative set for testing 
  internal <- rbind(train1,train2) ####combining for internal set
  external <- rbind(test1,test2)    ####combining for external set

######### Optimized parameter
control <- trainControl(method="cv", number=10)
tunegrid <- expand.grid(.mtry=c(1:10), .ntree=c(100,200,300,400,500))
custom <- train(Class~., data=internal , method=customRF, metric=c("Accuracy"), tuneGrid=tunegrid, trControl=control)

######Loop for 10-fold CV
k <- cross;
Resultcv <- 0;
folds <- cvsegments(nrow(internal), k);

for (fold in 1:k){
  currentFold <- folds[fold][[1]];
  RF = randomForest(Class ~ ., internal[-currentFold,], ntree= as.numeric(custom$ bestTune[2]),mtry = as.numeric(custom$ bestTune[1]),orm.votes=TRUE,keep.forest=TRUE, importance=TRUE) 
  pred = predict(RF, internal[currentFold,])
  Resultcv <- Resultcv + table(true=internal[currentFold,]$Class, pred=pred);   
}
################### External validation
RF = randomForest(Class ~ ., internal, ntree= as.numeric(custom$ bestTune[2]),mtry = as.numeric(custom$ bestTune[1]),orm.votes=TRUE,keep.forest=TRUE, importance=TRUE) 
predcv = table(external$Class, predict(RF, external))  ###### Prediction on external set
Resultext <- rbind(predcv[1], predcv[3],predcv[2], predcv[4]) ###### Reporting TN,FP,FN,TP
################### Performance report
data = Resultcv
	ACCtr[i,] = (data[1]+data[4])/(data[1]+data[2]+data[3]+data[4])*100
	SENStr[i,]  =  (data[1]/(data[1]+data[2]))*100
	SPECtr[i,] = (data[4])/(data[3]+data[4])*100
	MCC1      = (data[1]*data[4]) - (data[2]*data[3])
	MCC2      =  (data[4]+data[2])*(data[4]+data[3])
	MCC3      =  (data[1]+data[2])*(data[1]+data[3])
	MCC4	=  sqrt(MCC2)*sqrt(MCC3)
	MCCtr[i,]  = MCC1/MCC4
data = Resultext
	ACCts[i,] = (data[1]+data[4])/(data[1]+data[2]+data[3]+data[4])*100
	SENSts[i,]  =  (data[1]/(data[1]+data[2]))*100
	SPECts[i,] = (data[4])/(data[3]+data[4])*100
	MCC1      = (data[1]*data[4]) - (data[2]*data[3])
	MCC2      =  (data[4]+data[2])*(data[4]+data[3])
	MCC3      =  (data[1]+data[2])*(data[1]+data[3])
	MCC4	=  sqrt(MCC2)*sqrt(MCC3)
	MCCts[i,]  = MCC1/MCC4
}

result = data.frame (ACCtr,SENStr,SPECtr,MCCtr,ACCts,SENSts,SPECts,MCCts)

average <- matrix(nrow = 1, ncol = 8) 
std     <- matrix(nrow = 1, ncol = 8)
for (i in 1:8){
average[,i] = mean(result[,i])
std[,i] = sd(result[,i])
}
finalRE = t(rbind(average,std))      
