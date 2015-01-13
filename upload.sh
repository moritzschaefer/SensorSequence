make tmote
if [ "$?" -ne "0" ]; then
   echo "COMPILE ERROR!"
   exit 1
fi
echo "Programming Node 1"
make tmote reinstall,2 bsl,/dev/ttyUSB2
#p3=$!
make tmote reinstall,1 bsl,/dev/ttyUSB1 || {
  echo "Error programming node 1"
  exit 1
}
#p2=$!
echo "Programming Node 0"
make tmote reinstall,0 bsl,/dev/ttyUSB0 || {
  echo "Error programming node 0"
  exit 1
}
#p1=$!

#wait $!
#echo "$p1 and $p2 Finished."
