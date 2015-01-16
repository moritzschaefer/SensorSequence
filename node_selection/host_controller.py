#!/usr/bin/env python

import os
import sys
import time
import struct
import signal

#tos stuff
import MeasurementData
import SerialControl
from tinyos.message import *
from tinyos.message.Message import *
from tinyos.message.SerialPacket import *
from tinyos.packet.Serial import Serial

class HostController:
    def __init__(self, motestring):
        self.marked = False
        self.mif = MoteIF.MoteIF()
        self.tos_source = self.mif.addSource(motestring)
        self.mif.addListener(self, MeasurementData.MeasurementData)
        self.i = 0

    def receive(self, src, msg):
        m = MeasurementData.MeasurementData(msg.dataGet())
        print "{}, Rss: {}, SenderNode: {}, ReceiverNode: {}, Channel: {}, MeasuringNum: {}".format(time.time(), m.get_rss(), m.get_senderNodeId(), m.get_receiverNodeId(), m.get_channel(), m.get_measurementNum())

        sys.stdout.flush()

    def send(self):
        smsg = SerialControl.SerialControl()
        smsg.set_cmd(0)
        # 0 means, don't change the value
        smsg.set_num_measurements(2)
        smsg.set_channel_wait_time(0)
        smsg.set_id_request_wait_time(0)
        smsg.set_data_collection_channel(0)
        self.mif.sendMsg(self.tos_source, 0xFFFF, smsg.get_amType(), 0, smsg)

    def main_loop(self):
        self.send()
        while 1:
            time.sleep(1)
            if self.marked:
                self.marked = False
                print "im here"
                self.send()

            # send a message 1's per second
            #self.send()

def main():

    if '-h' in sys.argv:
        print "Usage:", sys.argv[0], "serial@/dev/ttyUSB0:115200"
        sys.exit()
    if len(sys.argv) < 2:
        dl = HostController("serial@/dev/ttyUSB0:115200")
    else:
        dl = HostController(sys.argv[1])

    def handler(signum, frame):
        dl.marked = True


    signal.signal(signal.SIGUSR1, handler)
    dl.main_loop()  # don't expect this to return...

if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        pass
