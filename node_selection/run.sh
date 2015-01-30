#!/bin/bash

cp measurement.txt ../node_algorithm/seq16ch_1.txt
cd ../node_algorithm
R CMD BATCH probabilisticSeq-v2.5.R
echo "Computed result is:"
cat finalresult.txt

