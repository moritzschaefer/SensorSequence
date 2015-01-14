pkill -f "PrintfClient"
pkill -f "host_controller"
make tmote
if [ "$?" -ne "0" ]; then
   echo "COMPILE ERROR!"
   exit 1
fi
if [ "$#" -eq "3" ]; then
  node0=$1
  node1=$2
  node2=$3
elif [ "$#" -eq "2" ]; then
  node0=$1
  node1=$2
else
  node0=0
  node1=1
fi
echo "Programming Node 2"
if [ -n "$node2" ]; then
  make tmote reinstall,2 bsl,/dev/ttyUSB$node2 || {
  echo "Error programming node 2"
  exit 1
  }
fi
echo "Programming Node 1"
make tmote reinstall,1 bsl,/dev/ttyUSB$node1 || {
  echo "Error programming node 1"
  exit 1
}
echo "Programming Node 0"
make tmote reinstall,0 bsl,/dev/ttyUSB$node0 || {
  echo "Error programming node 0"
  exit 1
}
