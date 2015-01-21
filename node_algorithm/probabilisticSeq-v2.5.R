## probabilisticSeq.R - O.Ergin - 17.06.2013
# v2 - 14.08.2013
# Description ...
# 	This one clusters sequences in subsequences of n. After n'th node in the sequence, the best one is taken and iterated from there to the end.
# 	It should be after every n'th node after the beginning or last cropping, but for our case (max node=10) this is not necessary <== resolved

# In addition, it doesn't only select the first winning node, but also other nodes with up to 2dbm difference for selecting Winning receivers.
#
# Version History: 
#
# v2.1 - 30.10.2013
#	Tree will be clustered with the paths whose P's are equal or greater than maximum P
#	Clustering is now every maxSubSeqSize mod of the path length
#
# v2.2 - 19.11.2013
#	packets is subsetted to Truth list, for the case there are more nodes in the measurement than desired.
#
# v2.3 - 05.12.2013
# Last remaining node is now assigned a heuristical probability by the last placed node, compared with the two nodes previously placed node
#
# v.2.5 - 23.05.2014
# Check the verdict with the reverse sequence
#
# For best maxRankToCompare sequences, compute the reverse maxRankToCompare Sequences
# Check for consistency
#
# DONE ToDo: Convert the sequence building algorithm into a function, with parameters (packets, refnode) 
#

#library(tcltk)

## Load configuration file
## global/common variables are written 
## in a configuration file now.

source("configuration.R")

source("probSeqFunctions.R")

run.verbose <- FALSE

totalSuccess <- 0
 
#experimentSet <- 15
#probsOutputDirectory <- outputDirectory
#outputDirectory <- "verify/"

testName <- paste(exp.set.name,definition,direction,sep="-")
outputDirectory <- paste(testName,"/",sep="");

if (!file.exists(outputDirectory))
  dir.create(outputDirectory,showWarnings=TRUE,recursive=TRUE)

outputFileName <- paste(outputDirectory,testName,"-verify",experimentSet[1],"-",experimentSet[length(experimentSet)],".txt",sep="")
settingsFileName <- paste(outputDirectory,testName,"-Settings.txt",sep="")
write.table(exp.set.name,settingsFileName,append=TRUE, row.names=FALSE, col.names=FALSE)
write.table(paste(experimentSet[1],tail(experimentSet,1),sep="-"),settingsFileName,append=TRUE, row.names=FALSE,col.names=FALSE)
write.table(outputFileName,settingsFileName,append=TRUE, row.names=FALSE, col.names=FALSE)
write.table(paste(Truth,collapse=" "),settingsFileName,append=TRUE, row.names=FALSE, col.names=FALSE)

outputDirectory <- paste(outputDirectory,"probs/", sep="")

for(expNo in experimentSet)
{   
	startTime <- proc.time()
	
	TRACE_FILE <- paste(directory,inFilePrefix,expNo,inFileSuffix, sep="")
	
	if ("packets" %in% ls() && debugging) {
		; # do not reload packets
	}
	else # not debugging
	{
		cat("Loading:",TRACE_FILE, "\n")	
		packets <- read.table(TRACE_FILE, sep="\t", na.strings="", col.names=c("receiver", "sender", "channel", "rssi", "power", "time", "packetnum"), colClasses=c(rep("factor",3), "numeric", "factor", "character", "numeric"), header=FALSE)
	}
	packets <- subset(packets, sender %in% Truth & receiver %in% Truth)
  packets <- droplevels(packets)
  
	## DEBUG SET
	if (debugging) {
		print("Debug set.")
		packets <- subset(packets,receiver %in% debugSet & sender %in% debugSet)
	}
	
# 	analyse <- matrix(data = NA, nrow = 4, ncol = 11, byrow = TRUE, dimnames = list(NULL,c("expNo", "Rank", "isCorrect", "prob", 
#                                                                                          "verifyRank", "verifyIsCorrect", "verifyProb", 
#                                                                                          "match", "JointProb", "ComputedSeq", "verifySeq")))

    analyse <- data.frame(expNo=integer(), Rank=integer(), isCorrect=logical(), prob=double(),
                          verifyRank=integer(), verifyIsCorrect=logical(), verifyProb=double(), 
                          match=logical(), jointProb=double(), computedSeq=character(), verifySeq=character(),
                          stringsAsFactors=FALSE)

  print("Finding Sequence")
	probabilitySeqDF <- findProbSequences(packets,refnode, produceOutput=produceOutput, verbose=run.verbose);
    probOrder <- with(probabilitySeqDF,order(-prob))
    probabilitySeqDF <- probabilitySeqDF[probOrder,]
  
	## RESULT
	print(probabilitySeqDF[1,])
	winnerSeq <- probabilitySeqDF[1,1:numnodes] 
	verdict <- all(winnerSeq == Truth)
	cat("Verdict is:", verdict,"\n"); 
  
maxRankToCompare <- 2
for (mainRank in 1:maxRankToCompare)
{
  cat("Verify", mainRank,"\n")
	verifySeqDF <- findProbSequences(packets,refnode=probabilitySeqDF[mainRank,numnodes], produceOutput=produceOutput, verbose=run.verbose);
    probOrder <- with(verifySeqDF,order(-prob))
    verifySeqDF <- verifySeqDF[probOrder,]
  cat("Verify", mainRank,"is", all(rev(verifySeqDF[1,1:numnodes])==Truth), "\n" )
  
  for (verifyRank in 1:maxRankToCompare) 
  {
    i <- (mainRank-1)*maxRankToCompare+verifyRank;
    
  	analyse[i,"expNo"] <- expNo; 
    
    analyse[i,"Rank"] <- mainRank; 
    analyse[i,"isCorrect"] <- all(probabilitySeqDF[mainRank,1:numnodes] == Truth); 
    analyse[i,"prob"] <- probabilitySeqDF[mainRank,"prob"];
  
  	analyse[i,"verifyRank"] <- verifyRank; 
    analyse[i,"verifyIsCorrect"] <- all(rev(verifySeqDF[verifyRank,1:numnodes])==Truth); 
    analyse[i,"verifyProb"] <- verifySeqDF[verifyRank,"prob"];
  
    analyse[i,"match"] <- all(probabilitySeqDF[mainRank,1:numnodes] == rev(verifySeqDF[verifyRank,1:numnodes]));
    analyse[i,"jointProb"] <- probabilitySeqDF[mainRank,"prob"] * verifySeqDF[verifyRank,"prob"];
  
    analyse[i,"computedSeq"] <- paste(probabilitySeqDF[mainRank,1:numnodes], collapse=",");
    analyse[i,"verifySeq"] <- paste(verifySeqDF[verifyRank,1:numnodes],collapse=",");
  }
}
	## Print Elapsed Time
	endTime <- proc.time()
	print(endTime-startTime)
	
	if(verdict == TRUE)
	{
		totalSuccess <- totalSuccess +1
	}
	cat("TotalSUCCESS=",totalSuccess,"\n");
	
	print(analyse)
  write.table(analyse, file=outputFileName, sep=" ", append=TRUE, col.names=(expNo==experimentSet[1]), row.names=FALSE)
	if (TRUE)
  {
  	rm(packets)
	}
} # for expNo

# Run: Rank Verdict prob RankCheck VerdictCheck ProbCheck
# n     1    T/F     p1    1         T/F          pc1
# n     1    T/F     p1    2         T/F          pc2
# n     2    T/F     p1    1         T/F          pc1
# n     2    T/F     p1    2         T/F          pc2
# 
# expNo: Rank Verdict prob RankCheck VerdictCheck ProbCheck Same JointProb ComputedSeq CheckSeq
#   n     1    F       p1    1         T          pc1         F   
#   n     1    F       p1    2         F          pc2         ?
#   n     2    T       p1    1         T          pc1         T
#   n     2    T       p1    2         F          pc2         F
