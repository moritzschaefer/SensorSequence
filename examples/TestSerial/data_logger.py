import os
import sys
import time
import struct

#tos stuff
import TestSerialMsg
from tinyos.message import *
from tinyos.message.Message import *
from tinyos.message.SerialPacket import *
from tinyos.packet.Serial import Serial

class DataLogger:
    def __init__(self, motestring):
        self.mif = MoteIF.MoteIF()
        self.tos_source = self.mif.addSource(motestring)
        self.mif.addListener(self, MyMsg.MyMsg)

    def receive(self, src, msg):
        if msg.get_amType() == MyMsg.AM_TYPE:
            print msg
            m = MyMsg.MyMsg(msg.dataGet())
            print time.time(), m.get_rx_timestamp(), m.get_next_rx_timestamp(), m.get_misses()

        sys.stdout.flush()

    def send(self):
                smsg = MyMsg.MyMsg()
                smsg.set_rx_timestamp(time.time())
                self.mif.sendMsg(self.tos_source, 0xFFFF,
                smsg.get_amType(), 0, smsg)

    def main_loop(self):
        while 1:
            time.sleep(1)
            # send a message 1's per second
            self.send_msg()

def main():

    if '-h' in sys.argv or len(sys.argv) < 2:
        print "Usage:", sys.argv[0], "sf@localhost:9002"
        sys.exit()

    dl = DataLogger(sys.argv[1])
    dl.main_loop()  # don't expect this to return...

if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        pass
