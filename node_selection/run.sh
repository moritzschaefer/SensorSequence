#!/bin/bash
PFAD=$(cd $(dirname $0) 2>/dev/null && pwd)
echo $PFAD
#echo "Inputfile: $1"
cp $1 ../node_algorithm/seq16ch_1.txt
cd ../node_algorithm
#shift
#sed -i -e 43c"Project = \"$PFAD\", " seq16ch_1.txt 
R CMD BATCH probabilisticSeq-v2.5.R
echo "Computed result is:"
cat finalresult.txt
