#!/bin/bash

NUM_MEASUREMENTS="1 5 10 20 40"

for RUN in $(seq 3); do # do everything 3 times
  for NUM in $NUM_MEASUREMENTS; do
    date > time_${RUN}_${NUM}
    python host_controller.py --measurements $NUM --channelWait 250 --senderChannelWait 500 --nodePath "sf@localhost:9148" > measurement_${RUN}_${NUM}
    date >> time_${RUN}_${NUM}
  done
done

