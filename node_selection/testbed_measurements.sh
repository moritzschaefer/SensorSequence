#!/bin/bash

NUM_MEASUREMENTS="1 5 10 20"

for RUN in $(seq 3); do # do everything 3 times
  for NUM in $NUM_MEASUREMENTS; do
    python host_controller.py > measurement_${RUN}_${NUM}
  done
done

