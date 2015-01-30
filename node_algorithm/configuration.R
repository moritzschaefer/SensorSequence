# Configuration file

#rm(list=ls()) # clears all defined variables

print("Loading configuration.R")

wokstations <- c("MacBookPro", "MacMini", "Anna", "maximusLux")

workstation   <- wokstations[4]
exp.set.name  <- "SetC"

topQuantile <- 0.50
definition <- paste("Q",100*topQuantile,sep="")

reverseDirection <- FALSE

if (exp.set.name == "SetA"){
  experimentSet <- 1:2000
  Truth  	<- c(16,138,96,141,92,145,88,147,10,153);
  
  directory <- switch (workstation,
                       MacBookPro = "/Users/ergin/phd/R/measurements/4thFloor/FourthFloor_chLoop2000withPktID/",
                       MacMini = "/Volumes/MacOSX-1/phd/FourthFloor_chLoop2000withPktID/",
                       Anna = "/lhome/ergin/measurements/4thFloor/FourthFloor_chLoop2000withPktID/",
                       maximusLux = "/home/maximilian/Documents/SensorSequence/node_algorithm"
                      )
} else 
if (exp.set.name == "SetB") {
  experimentSet <- 1:693
  Truth    <- c(140,94,143,90,150,13,152);
  
  directory <- switch (workstation,
                       MacBookPro = "/Users/ergin/phd/R/measurements/4thFl-NorthWindow/",
                       MacMini = "" # fill in
                      )
} else 
if (exp.set.name == "SetC") {
  experimentSet <- 1:1
  Truth    <- rev(c(10,0,20));
  
  directory <- switch (workstation,
                       MacBookPro = "/TestTest/",
                       MacMini = "", # fill in
                       Anna = "/lhome/ergin/measurements/4thFloor/chOuterLoop4thFl-2ndRow10Nodes/",
		       maximusLux = "/home/maximilian/Documents/SensorSequence/node_algorithm/"
                      )
}
numnodes   <- length(Truth)
refnode 	<- Truth[1]

outputDirectoryBase <- "output"

if (reverseDirection)
{
	Truth <- rev(Truth)
	refnode <- Truth[1]
	outputDirectory <- paste(outputDirectoryBase,"RevDir",sep="")
  direction <- "Reverse"
} else {
  outputDirectory <- paste(outputDirectoryBase,"NormalDir",sep="")
  direction <- "Normal"
}

# Give directory syntax
outputDirectory <- paste("./",outputDirectory,"/",sep="")

# Crop/select the nodes for debugging
debugging <- FALSE
	if (debugging)
	{
		debugSet<-c(145,88,147,10,153)
		Truth <- rev(debugSet)
		numnodes <- length(debugSet)
		refnode <- Truth[1]
	}

maxSubSeqSize	<- 5 # cluster size for computation efficiency

rssMaxDifference<- 0	# if(rssDifference <= rssMaxDifference)

inFilePrefix <- "seq16ch_"
inFileSuffix <- ".txt"

fileNamePrefix1	<- "probabilitySeqDF"
fileNamePrefix2	<- "probabilitiesDF"
fileNameSuffix	<- ".txt"
produceOutput	<- FALSE


#directory <- "../../FourthFloor_chLoop2000withPktID/measurements/"
#directory <- "/Volumes/MacOSX-1/phd/FourthFloor_chLoop2000withPktID/"
#directory <- "/lhome/ergin/FourthFloor_chLoop2000withPktID/measurements/"
#directory <- "/lhome/ergin/2d/chOuterLoop4thFl-4x7/"
#directory <- "./"
#directory <- "/Users/ergin/phd/R/measurements/FourthFloor_chLoop2000withPktID/" # Macbook Pro
#directory <- "/Users/ergin/phd/R/measurements/2D-NothSide/nointerference/"
#directory <- "/Users/ergin/phd/R/measurements/2D-NothSide/withinterference/1interferer/"
#directory <- "/lhome/ergin/measurements/2D-NorthSide/controlledInterference2/"
#directory <- "/Users/ergin/phd/R/measurements/4thFloor/FourthFloor_chLoop2000withPktID/"

# fileBegin   <- 1
# fileEnd 	<- 300

#fileBegin <- fileEnd <- 1832
#experimentSet <- c(fileBegin:fileEnd)

#failedExperiments
#experimentSet <- c(1,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,25,30,32,34,35,40,45,46,50,53,54,63,64,65,69,71,76,82,83,87,88,93,96,97,102,103,105,106,107,108,110,116,120,121,126,129,131,133,136,137,141,146,151,158,159,165,169,173,174,176,183,188,189,193,194,195,203,204,206,207,209,211,212,213,214,215,216,218,219,220,223,240,258,273,280,282,283,285,288,289,291,292,294,295,296,297,298,305,310,311,329,330,1825,1826,1831,1832,1836,1839,1841,1842,1848,1851,1862,1864,1878,1879,1891,1893,1895,1910,1949,1997)
# experimentSet <- c(1,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,27,30,32,34,35,40,42,45,46,48,50,53,54,60,63,64,65,69,70,71,76,83,91,93,102,105,106,107,108,131,141,165,173,174,176,189,193,194,203,204,207,209,211,212,213,214,215,216,218,219,223,240,258,273,280,282,283,285,288,289,291,292,294,295,296,297,298,305,310,311,329)
#experimentSet <- experimentSet[1:44]
#experimentSet <- experimentSet[45:88]
#experimentSet <- 7

#Truth		<- c(16,138,96,141,92,145,88,147,10,153); # 4h Fl 1st Row
#Truth <- rev(c(154, 11, 148, 15, 146, 91, 142, 95, 137, 97)); #4th Fl 2nd Row
#Truth 		<- c(140,94,143,90,150,13,152); # 4th Fl North Window Side
#numnodes 	<- length(Truth)
#refnode 	<- Truth[1]
#refnode  	<- 16
#numnodes 	<- 10

# for Batch execution: > nohup R CMD BATCH probabilisticSeq.R &
# for output watching: > tail -f probabilisticSeq.Rout
