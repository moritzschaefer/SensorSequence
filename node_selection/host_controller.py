#!/usr/bin/env python

import os
import sys
import time
import struct

#tos stuff
import MeasurementData
from tinyos.message import *
from tinyos.message.Message import *
from tinyos.message.SerialPacket import *
from tinyos.packet.Serial import Serial

class HostController:
    def __init__(self, motestring):
        self.mif = MoteIF.MoteIF()
        self.tos_source = self.mif.addSource(motestring)
        self.mif.addListener(self, MeasurementData.MeasurementData)
        self.i = 0

    def receive(self, src, msg):
        m = MeasurementData.MeasurementData(msg.dataGet())
        print "{}, Rss: {}, SenderNode: {}, ReceiverNode: {}".format(time.time(), m.get_rss(), m.get_senderNodeId(), m.get_receiverNodeId())

        sys.stdout.flush()

    def send(self):
        # smsg = MeasurementData.MeasurementData()
        # smsg.set_counter(self.i)
        # self.mif.sendMsg(self.tos_source, 0xFFFF,
        # smsg.get_amType(), 0, smsg)
        # self.i += 1
        pass
        # we dont need to send anything

    def main_loop(self):
        while 1:
            time.sleep(1)
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
    dl.main_loop()  # don't expect this to return...

if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        pass
