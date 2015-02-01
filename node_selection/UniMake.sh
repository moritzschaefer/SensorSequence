#!/bin/bash
killall ssh
make tmote
./connect.sh
#./host_controller.py sf@localhost:9011 | tee measurement.txt
