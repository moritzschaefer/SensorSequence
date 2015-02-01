#!/usr/bin/env python

import os
import sys
import time
import struct
import argparse
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
        import ipdb; ipdb.set_trace()
        m = MeasurementData.MeasurementData(msg.dataGet())
        if msg.get_amType()==137:
            if m.get_rss() != 0:
                output_line = '\t'.join((str(int(x)) for x in (m.get_senderNodeId(), m.get_receiverNodeId(), m.get_channel(), m.get_rss(), 31, time.time(), m.get_measurementNum()))) + '\n'
                if args.out_file:
                    print output_line
                else:
                    fobj_in = open("args.out_file")
                    fobj_out = open("args.out_file","w")
                    print output_line
                    fobj_in.close()
                    fobj_out.close()
            sys.stdout.flush()
        elif msg.get_amType()==142:
            sys.exit(0)


    def send(self):

        smsg = SerialControl.SerialControl()
        smsg.set_cmd(0)
        # 0 means, don't change the value
        smsg.set_num_measurements(20)
        smsg.set_channel_wait_time(self.channel_wait_time)
        smsg.set_sender_channel_wait_time(self.sender_channel_wait_time)
        smsg.set_id_request_wait_time(0)
        smsg.set_data_collection_channel(0)
        self.mif.sendMsg(self.tos_source, 0xFFFF, smsg.get_amType(), 0, smsg)

    def main_loop(self):
        while 1:
            line = raw_input()
            try:
                self.sender_channel_wait_time, self.channel_wait_time = (int(x) for x in line.split())
            except ValueError:
                self.sender_channel_wait_time, self.channel_wait_time = (110,60)

            self.send()

def main():

    #argparse
    parser = argparse.ArgumentParser()
    parser.add_argument("--measurements", default=20, type=int)
    parser.add_argument("--channelWait", default=0, type=int)
    parser.add_argument("--SenderchannelWait", default=0, type=int)
    parser.add_argument("--idWait", default=0, type=int)
    parser.add_argument("--collectionChannel", default=0, type=int)
    parser.add_argument("--out_file", type=str)
    parser.add_argument("--nodepath", default="serial@/dev/ttyUSB0:115200", type=str)
    args = parser.parse_args()

    print args.nodepath

    if '-h' in sys.argv:
        print "Usage:", sys.argv[0], arg.nodepath
        sys.exit()
    if len(sys.argv) < 2:
        dl = HostController("serial@/dev/ttyUSB0:115200")
    else:
        dl = HostController(sys.argv[1])

    dl.main_loop()

if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        pass
