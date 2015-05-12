make tmote
if [ "$?" -ne "0" ]; then
   echo "COMPILE ERROR!"
   exit 1
fi
echo "Programming Node 1"
make tmote reinstall,1 bsl,/dev/tty.usbserial-XBS3IO7G 
#p2=$!
echo "Programming Node 0"
make tmote reinstall,0 bsl,/dev/tty.usbserial-M4A7N5TR 
#p1=$!

#wait $!
echo "$p1 and $p2 Finished."
