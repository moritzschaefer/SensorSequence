#!/bin/bash
cp measurement.txt ../node_algorithm/seq16ch_1.txt
cd ../node_algorithm
R CMD BATCH ProbabilisticSeq-v2.5.R
sed -ne '197,200p' probabilisticSeq-v2.5.Rout
