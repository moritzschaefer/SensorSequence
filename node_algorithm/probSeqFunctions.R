#source("userFunctions.R")

library(plyr)

MatrixRowSize <- 5040   # 7!=5040

rm("getSendersWinningReceivers")

## Load Functions
#source("userFunctions.R")

#override this function from userFunctions.R: compare with 1 packet only
if(FALSE)
getSendersWinningReceivers <- function (allPackets, theSender, excludeList=NULL, includeList=NULL, maxPacketNum=(10^6)) {
  
  if (is.null(excludeList) && is.null(includeList)) 
  {
    thisFunctionsName <- match.call()[[1]]
    stop (paste("In ", thisFunctionsName,", excludeList and includeList cannot be both NULL!"))
  } 
  else if (!is.null(excludeList) && !is.null(includeList)) 
  {
    thisFunctionsName <- match.call()[[1]]
    stop (paste("In ", thisFunctionsName,", excludeList and includeList cannot be both non-NULL!"))
  } 
  else if (!is.null(excludeList)) 
    senderPackets <- subset(allPackets, sender == theSender & !(receiver %in% excludeList), select=c(-time,-power)) 
  else if (!is.null(includeList))
    senderPackets <- subset(allPackets, sender == theSender & (receiver %in% includeList), select=c(-time,-power))
  
  if (!exists("senderPackets") || nrow(senderPackets)==0) {
    cat(paste("No packets found from sender",theSender,"to receivers:",paste(excludeList,sep=','),paste(includeList,sep=',')))
    # Above was stop(...), below was not there
    return(NA)
  }
  
  if (maxPacketNum == (10^6))
  {  packetNums <- unique(senderPackets$packetnum)
  }else 
    packetNums <- na.omit(unique(senderPackets$packetnum)[1:maxPacketNum])
  
  channelSet <- unique(packets$channel)
  
  sendersWinningReceivers <- c()
  for (c in channelSet) 
  {
    for (n in packetNums) 
    {
      sendersNthPackets <- subset(senderPackets,packetnum==n&channel==c)   # find all reports for {s, c, n}
      theWinningReceiver <- -9999 #impossible receiver
      
      #sendersNthPackets <- sendersNthPackets[order(-sendersNthPackets[,"rssi"]),]  # reorder by rssi, big to small
      #theWinningReceiver <- as.numeric(as.character(sendersNthPackets[1,"receiver"])) # find the receiver with best rssi
      #theWinningRssi <- as.numeric(as.character(sendersNthPackets[1,"rssi"])) # find the rssi of the best receiver
      #sendersWinningReceivers <- c(sendersWinningReceivers,theWinningReceiver) # put it into the list.
      
      #rssMaxDifference <- 2 # now in configuration.R
      rssDifference <- 0
      
      firstRssiDummy <- -1000
      firstRssi <- firstRssiDummy # impossible rssi, so 1st iteration of loop actuates
      
      while (rssDifference <= rssMaxDifference)
      {
        sendersNthPackets <- subset(sendersNthPackets, receiver!=theWinningReceiver)
        if (nrow(sendersNthPackets) == 0) # if there was only one receiver, strange measurement!.
          break
        sendersNthPackets <- sendersNthPackets[order(-sendersNthPackets[,"rssi"]),]  # reorder by rssi, big to small
        
        theWinningReceiver <- as.numeric(as.character(sendersNthPackets[1,"receiver"])) # find the receiver with best rssi
        theWinningRssi <- as.numeric(as.character(sendersNthPackets[1,"rssi"])) # find the rssi of the best receiver
        
        rssDifference <- firstRssi - theWinningRssi
        #cat("rssDifference=",rssDifference, "firstRssi=",firstRssi, "theWinningRssi=",theWinningRssi,"theWinningReceiver=",theWinningReceiver , "at c =",c,"n =",n,"for sender:",s,"\n")
        
        if(rssDifference <= rssMaxDifference)
        {
          sendersWinningReceivers <- c(sendersWinningReceivers,theWinningReceiver) # put it into the list.
          
          if (firstRssi != firstRssiDummy && FALSE)
          {
            cat("rssDifference=",rssDifference, "firstRssi=",firstRssi, "theWinningRssi=",theWinningRssi,"theWinningReceiver=",theWinningReceiver , "at c =",c,"n =",n,"for sender:",s,"\n")
            cat ("Just inserted", theWinningReceiver,":",theWinningRssi,"\n")
          }
        }
        else
          next
        
        if (firstRssi == firstRssiDummy)  # set just once
          firstRssi <- theWinningRssi
      }
      
      if (c==13 && FALSE)
      {stop ("Stopped after c=13"); warning ("warning iste.")}
    } # for n
  } # for c
  sendersWinningReceivers <- sendersWinningReceivers[!is.na(sendersWinningReceivers)]   # remove NAs
  return (sendersWinningReceivers)
}

# Instead of comparing all rssi's, below function compares mean(Q90) rssi's for each channel
getSendersWinningReceivers <- function (allPackets, theSender, excludeList=NULL, includeList=NULL) {
  
  if (is.null(excludeList) && is.null(includeList)) 
  {
    thisFunctionsName <- match.call()[[1]]
    stop (paste("In ", thisFunctionsName,", excludeList and includeList cannot be both NULL!"))
  } 
  else if (!is.null(excludeList) && !is.null(includeList)) 
  {
    thisFunctionsName <- match.call()[[1]]
    stop (paste("In ", thisFunctionsName,", excludeList and includeList cannot be both non-NULL!"))
  } 
  else if (!is.null(excludeList)) 
    senderPackets <- subset(allPackets, sender == theSender & !(receiver %in% excludeList), select=c(-time,-power)) 
  else if (!is.null(includeList))
    senderPackets <- subset(allPackets, sender == theSender & (receiver %in% includeList), select=c(-time,-power))
  
  if (!exists("senderPackets") || nrow(senderPackets)==0) {
    cat(paste("No packets found from sender",theSender,"to receivers:",paste(excludeList,sep=','),paste(includeList,sep=',')))
    # Above was stop(...), below was not there
    return(NA)
  }
  
  channelSet <- unique(packets$channel)
  
  senderPackets <- ddply(senderPackets, .(receiver,sender,channel), summarize, rssiQuantileMean=mean(subset(rssi, rssi>=quantile(rssi, topQuantile))) )
  
  sendersWinningReceivers <- c()
  channelsOfWinningReceivers <- c()
  for (c in channelSet) 
  {
      sendersNthPackets <- subset(senderPackets,channel==c)   # find all reports for {s, c, n}
      theWinningReceiver <- -9999 #impossible receiver
      
      #rssMaxDifference <- 2 # now in configuration.R
      rssDifference <- 0
      
      firstRssiDummy <- -1000
      firstRssi <- firstRssiDummy # impossible rssi, so 1st iteration of loop actuates
      
      while (rssDifference <= rssMaxDifference)
      {
        sendersNthPackets <- subset(sendersNthPackets, receiver!=theWinningReceiver)
        if (nrow(sendersNthPackets) == 0) # if there was only one receiver, strange measurement!.
          break
        sendersNthPackets <- sendersNthPackets[order(-sendersNthPackets[,"rssiQuantileMean"]),]  # reorder by rssi, big to small
        
        theWinningReceiver <- as.numeric(as.character(sendersNthPackets[1,"receiver"])) # find the receiver with best rssi
        theWinningRssi <- as.numeric(as.character(sendersNthPackets[1,"rssiQuantileMean"])) # find the rssi of the best receiver
        
        rssDifference <- firstRssi - theWinningRssi
        #cat("rssDifference=",rssDifference, "firstRssi=",firstRssi, "theWinningRssi=",theWinningRssi,"theWinningReceiver=",theWinningReceiver , "at c =",c,"n =",n,"for sender:",s,"\n")
        
        if(rssDifference <= rssMaxDifference)
        {
          sendersWinningReceivers <- c(sendersWinningReceivers,theWinningReceiver) # put it into the list.
          channelsOfWinningReceivers <- c(channelsOfWinningReceivers,c)
          
          if (firstRssi != firstRssiDummy && FALSE)
          {
            cat("rssDifference=",rssDifference, "firstRssi=",firstRssi, "theWinningRssi=",theWinningRssi,"theWinningReceiver=",theWinningReceiver , "at c =",c,"for sender:",s,"\n")
            cat ("Just inserted", theWinningReceiver,":",theWinningRssi,"\n")
          }
        }
        else
          next
        
        if (firstRssi == firstRssiDummy)  # set just once
          firstRssi <- theWinningRssi
      }
      
      if (c==13 && FALSE)
      {stop ("Stopped after c=13"); warning ("warning iste.")}
    
    
  } # for c
  sendersWinningReceivers <- sendersWinningReceivers[!is.na(sendersWinningReceivers)]   # remove NAs
  return (sendersWinningReceivers)
}


findProbSequences <- function (packets, refnode, produceOutput=FALSE, verbose = FALSE)
{
  # Verbose functions
  vPrint <- function (arg) { if (verbose) print(arg) }
  vCat <- function (...) { if (verbose) cat(...) }
  
  # Create two parallel matrices
  probabilitySeqMatrix <- matrix(data = NA, nrow = MatrixRowSize, ncol = numnodes+1, byrow = TRUE, dimnames = list(NULL,c(paste("N",1:numnodes,sep=""),"P")))
  probabilitiesMatrix <- matrix(data = 1, nrow = MatrixRowSize, ncol = numnodes, byrow = TRUE, dimnames = list(NULL,paste("P",1:numnodes,sep="")))
  
  probabilitySeqDF <- as.data.frame(probabilitySeqMatrix)
  probabilitiesDF <- as.data.frame(probabilitiesMatrix)	
  
  probabilitySeqDF[1,1] <- refnode
  probabilitiesDF[1,1] <- 1
  validRows <- 1
  lastRow <- 1
  
  probabilitySeqDF[1,"P"] <- 1
  
  # For returning error
  allZeros <- probabilitySeqDF[1:2,]
  allZeros$prob <- 4
  allZeros[1,] <- rep(0,ncol(allZeros))
  allZeros[2,] <- rep(0,ncol(allZeros))
  
  ## Progress Bar
  #
#   cat("\n"); 
#   pb <- txtProgressBar(min = 0, max = numnodes, style = 3)
  ##\
  
  for (nextnode in 1:(numnodes-1)) #For each position
  {
    # Cut off the sequences here: after 5th node, take the best subseq and continue from there.
    
    #maxSubSeqSize <- 5 # now in configuration.R
    if (nextnode %% maxSubSeqSize == 0) # Start Clustering
    {
      #cluster()
      vPrint("clustering")
      
      #print (probabilitiesDF[1:validRows,])
      vPrint (probabilitySeqDF[1:validRows,])
      #cat("Paused.. Hit Enter to continue"); scan(n=1)
      probabilitySeqDF$P[1:validRows] <- computeProbabilities(probabilitiesDF,validRows)
      
      maxProb <- max(probabilitySeqDF$P, na.rm=TRUE)
      
      #selectedRows <- probabilitySeqDF$P>=(maxProb/2)
      selectedRows <- probabilitySeqDF$P[1:validRows]>=(maxProb/2)
      newValidRows <- sum(selectedRows)
      
      vCat("Cut down from", validRows, "to",newValidRows, "rows.")
      
      selectedRows <- c(selectedRows,rep(TRUE,nrow(probabilitySeqDF)-length(selectedRows)))
      
      #This code removes undesired rows, resulting in a reduced size of DFs
      probabilitiesDF <- probabilitiesDF[selectedRows,]
      probabilitySeqDF <- probabilitySeqDF[selectedRows,]
      
      validRows <- newValidRows
      
    } # Finish Clustering
    
    ## UPDATE Progress Bar
    #
    vCat("\n"); 
    pb <- txtProgressBar(min = 0, max = numnodes, style = 3)
    ##
    
    lastRow <- validRows
    for (Row in lastRow:1) 
    {
      s <- probabilitySeqDF[Row,nextnode]
      #cat("\nRow: ", Row, ", s: ",s, "\n",sep=""); print(probabilitySeqDF[Row,])
      
      #ErrorCheck
      if (is.na(s)) return (allZeros)      
      
      if (probabilitiesDF[Row,1] == 0)
        next
      
      if (nextnode == (numnodes-2) && FALSE) {  ##  ... Ni Nj] Nk Nl ==> P(NjNk) = P(NiNk)*P(NjNk) , totally heuristical.
        lastNodes <- subset(packets, sender == s & !(receiver %in% probabilitySeqDF[Row,1:nextnode]), select=c(receiver))
        
        lastPlacedNode <- probabilitySeqDF[Row,nextnode]
        excludeList <- probabilitySeqDF[Row,c(1:nextnode)]
        
        
        ## Last Sender
        lastSendersReceivers <- c()
        lastSendersReceivers <- getSendersWinningReceivers(packets, theSender = lastPlacedNode, excludeList=excludeList)
        lastSendersReceivers <- lastSendersReceivers[!is.na(lastSendersReceivers)]  
        freqTable1 <- table(lastSendersReceivers)
        
        ## Previous Sender
        prevSender <- probabilitySeqDF[Row,nextnode-1]
        prevSendersReceivers <- c()
        prevSendersReceivers <- getSendersWinningReceivers(packets, theSender = prevSender, excludeList=excludeList)
        prevSendersReceivers <- prevSendersReceivers[!is.na(prevSendersReceivers)]  
        
        freqTable2 <- table(prevSendersReceivers)
        
        vPrint ("BEFORE")
        vCat ("LastNode:",lastPlacedNode,"\n")
        vPrint(freqTable1)
        vCat("PreviousNode:", prevSender,"\n")
        vPrint(freqTable2)
        vPrint(probabilitySeqDF[1:validRows,]); vCat("\b (",validRows," rows)\n",sep="")
        vPrint(probabilitiesDF[1:validRows,]); vCat("\b (",validRows," rows)\n",sep="")
        rcvrNo <- 1
        for (r in unique(lastSendersReceivers))
        {
          pr1 <- freqTable1[as.character(r)]/sum(freqTable1)
          pr2 <- freqTable2[as.character(r)]/sum(freqTable2)
          
          if (rcvrNo == 1) 
          {
            probabilitySeqDF[Row,nextnode+1] <- as.character(r)
            probabilitiesDF[Row,nextnode+1] <- pr1*pr2
            rcvrNo <- rcvrNo + 1
          } 
          else 
          {
            validRows <- validRows + 1
            probabilitySeqDF[validRows,] <- c(probabilitySeqDF[Row,]) 
            probabilitiesDF[validRows,] <- c(probabilitiesDF[Row,])
            
            probabilityDFLastIndex <- validRows
            probabilitySeqDF[probabilityDFLastIndex,nextnode+1] <- as.character(r)
            
            #find and compute probabilities here
            nodeProbability <- pr1*pr2
            probabilitiesDF[probabilityDFLastIndex,nextnode+1] <- nodeProbability 
          }
          vPrint ("AFTER")
          vPrint(probabilitySeqDF[1:validRows,]); vCat("\b (",validRows," rows)\n",sep="")
          vPrint(probabilitiesDF[1:validRows,]); vCat("\b (",validRows," rows)\n",sep="")
          
        }
        
        
      } 
      else 
        if (nextnode == (numnodes-1)) 
        {
          ;# Put the remaining node right away and continue
          #s <- probabilitySeqDF[Row,nextnode]
          lastNode <- subset(packets, sender == s & !(receiver %in% probabilitySeqDF[Row,1:nextnode]), select=c(receiver))
          
          #cat("lastNode: \n"); print(unique(lastNode));
          if(length(unique(lastNode)) > 1) 
          {
            #cat("Error: lastNode size > 1 =", length(unique(lastNode)))
            vPrint(unique(lastNode))
            next	
          }
          
          if(length(unique(lastNode)) == 1)
          {
            if (TRUE) # Put the last remaining node to the end with Np=1
            {  
              probabilitySeqDF[Row,nextnode+1] <- as.integer(as.character(lastNode[1,1])) #don't know why lastNode[1] doesn't work
              probabilitiesDF[Row,nextnode+1] <- 1
            }
            else {
              lastPlacedNode <- probabilitySeqDF[Row,nextnode]
              
              #remainingNode <- lastNode
              #twoNodeBehind <- probabilitySeqDF[Row,nextnode-2]
              #includeList <- c(remainingNode,twoNodeBehind)
              twoNodeBehind <- nextnode-2  
              excludeList <- probabilitySeqDF[Row,c(1:nextnode)[-twoNodeBehind]]
              
              sendersControlReceivers <- c()
              
              sendersControlReceivers <- getSendersWinningReceivers(packets, theSender = lastPlacedNode, excludeList=excludeList)
              
              sendersControlReceivers <- sendersControlReceivers[!is.na(sendersControlReceivers)]	
              
              remainingNode <- as.integer(as.character(lastNode[1,1]))  #don't know why lastNode[1] doesn't work
              
              freqTable <- table(sendersControlReceivers)
              if (as.character(remainingNode) %in% names(freqTable))
                pRemainingNode <- freqTable[names(freqTable)==as.character(remainingNode)]/sum(freqTable)
              else
                pRemainingNode <- 0
              probabilitySeqDF[Row,nextnode+1] <- remainingNode
              probabilitiesDF[Row,nextnode+1] <- pRemainingNode
              vCat("P(",lastPlacedNode,"|",probabilitySeqDF[Row,twoNodeBehind],",",remainingNode,") =>", "P(",lastPlacedNode,"|",remainingNode,")=",pRemainingNode,"\n")
            }
          }
          next
          
        }
      
      currentSequence <- probabilitySeqDF[Row,1:nextnode]
      #find and compute probabilities here
      
      sendersWinningReceivers <- c()
      
      sendersWinningReceivers <- getSendersWinningReceivers(packets, theSender = s, excludeList=currentSequence)
        if(is.na(sendersWinningReceivers) || is.null(sendersWinningReceivers)) return(allZeros) # Error check
      
      sendersWinningReceivers <- sendersWinningReceivers[!is.na(sendersWinningReceivers)]		  	
      
      maxReceiver <- mostFreqReceiver(sendersWinningReceivers)
      maxReceiverProb <- findProbability(sendersWinningReceivers,maxReceiver,length(sendersWinningReceivers[!is.na(sendersWinningReceivers)]))
      
      
      # FOR EACH sendersWinningReceivers ADD A ROW AND UPDATE PROBABILITY
      
      #cat("Row=",Row,"nextnode=",nextnode,"UniqueReceivers of ", s, " : ", unique(sendersWinningReceivers), "\n")
      
      uniqueSenders<-unique(sendersWinningReceivers)
      #cat("\nAdd node:", uniqueSenders[1])
      #probabilitySeqDF[i,nextnode+1] <- uniqueSenders[1]
      probabilitySeqDF[Row,nextnode+1] <- mostFreqReceiver(sendersWinningReceivers,1)
      probabilitiesDF[Row,nextnode+1] <- findProbability(sendersWinningReceivers,1,length(sendersWinningReceivers[!is.na(sendersWinningReceivers)]))
      
      #probabilitySeqDF[Row,"P"] <- probabilitySeqDF[Row,"P"] * probabilitiesDF[Row,nextnode+1]
      
      vCat("\nprobabilitySeqDF=\n");   vPrint(probabilitySeqDF[1:validRows,]); vCat("\b (",validRows," rows)\n",sep="")
      #print(probabilitiesDF[1:validRows,]); cat("\b (",validRows," rows)\n",sep="")
      
      
      if (length(unique(sendersWinningReceivers)) > 1)
        for (r in 2:length(unique(sendersWinningReceivers)))
        {
          #probabilitySeqDF <- rbind(probabilitySeqDF, c(probabilitySeqDF[Row,])) #,receiversOfInterest[r])	)
          #probabilitiesDF <- rbind(probabilitiesDF, c(probabilitiesDF[Row,]))
          validRows <- validRows + 1
          probabilitySeqDF[validRows,] <- c(probabilitySeqDF[Row,]) #,receiversOfInterest[r])	)
          probabilitiesDF[validRows,] <- c(probabilitiesDF[Row,])
          
          #cat("Added Row:",validRows,"\n")
          
          #Depreciated: probabilityDFLastIndex <- nrow(probabilitySeqDF)
          
          probabilityDFLastIndex <- validRows
          probabilitySeqDF[probabilityDFLastIndex,nextnode+1] <- mostFreqReceiver(sendersWinningReceivers,r)
          
          #find and compute probabilities here
          nodeProbability <- findProbability(sendersWinningReceivers,r,length(sendersWinningReceivers[!is.na(sendersWinningReceivers)]))
          probabilitiesDF[probabilityDFLastIndex,nextnode+1] <- nodeProbability
          
          #Update the probability
          #probabilitySeqDF[probabilityDFLastIndex,"prob"] <- nodeProbability * probabilitySeqDF[probabilityDFLastIndex,"prob"]
        }
      
      ## Progress Bar
      #
      progress <- (lastRow-Row)#*numnodes
      setTxtProgressBar(pb, progress); vCat("\n"); 
      ##cat("Progress:",progress,"\n")
      ##
    }
    
  }
  close(pb)
  probabilitySeqDF$P[1:validRows] <- computeProbabilities(probabilitiesDF,validRows)
  probabilitySeqDF$prob <- 0    #probability that's computed at the end
  if (TRUE){
    for(rr in 1:validRows)
    {
      prob <- 1
      if (TRUE)
        for (cc in 1:ncol(probabilitiesDF))
        {
          #cat(" probabilitiesDF[",rr,",",cc,"]=",probabilitiesDF[rr,cc], sep="")
          prob <- prob * probabilitiesDF[rr,cc]
        }
      prob <- prod(probabilitiesDF[rr,])
      #print("\n")
      probabilitySeqDF[rr,"prob"] <- prob
      #cat("probabilitySeqDF[",rr,",prob] <- ",prob,"=>",probabilitySeqDF[rr,"prob"],"\n",sep="")
    }
    #print(probabilitySeqDF[1:validRows,]); #print(probabilitiesDF)
  }
  
  if (produceOutput)
  {
    if (!file.exists(outputDirectory))
      dir.create(outputDirectory,showWarnings=TRUE,recursive=TRUE)
    
    outFileName1 <- paste(outputDirectory,fileNamePrefix1,expNo,fileNameSuffix,sep="")
    write.table(probabilitySeqDF[1:validRows,], file=outFileName1, sep=" ", append=FALSE, col.names=TRUE, row.names=FALSE)
    
    outFileName2 <- paste(outputDirectory,fileNamePrefix2,expNo,fileNameSuffix,sep="")
    write.table(probabilitiesDF[1:validRows,], file=outFileName2, sep=" ", append=FALSE, col.names=TRUE, row.names=FALSE)
    
    cat(validRows,"rows written to:",outFileName1,"and",outFileName2,"\n")
  }
  
  probabilitySeqDF <- probabilitySeqDF[1:validRows,]
  probabilitiesDF <- probabilitiesDF[1:validRows,]
  
  return(probabilitySeqDF)
}