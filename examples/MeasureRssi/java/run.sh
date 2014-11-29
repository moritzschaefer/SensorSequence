
CLASSPATH=$CLASSPATH:./tinyos.jar

ClassFile="MeasureRssi.class"

if test -f $ClassFile
then
	echo "$ClassFile found."
else 
	echo "Compiling... $ClassFile"
	make
fi

if test -f $ClassFile
then 
	if test -f `ls /dev/tty.usbserial-*`
	then
		java MeasureRssi -nonode
	else 
		java  MeasureRssi -comm serial@`ls /dev/tty.usbserial-*`:tmote
	fi
else
	echo $ClassFile not found.
fi
