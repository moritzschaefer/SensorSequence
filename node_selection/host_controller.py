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
import threading


class HostController:
    def __init__(self, motestring, outfile, wait_event):
        if outfile:
            self.outfile = open(outfile, 'w')
        self.wait_event = wait_event

        self.mif = MoteIF.MoteIF()
        self.tos_source = self.mif.addSource(motestring)
        self.mif.addListener(self, MeasurementData.MeasurementData)
        self.i = 0

    def receive(self, src, msg):
        m = MeasurementData.MeasurementData(msg.dataGet())
        if msg.get_amType()==137:
            if m.get_channel() == 0 and m.get_rss() == 0:
                try:
                    self.outfile.close()
                except AttributeError:
                    pass
                # sys.stderr.write('Received terminate signal\n'); sys.stderr.flush()
                self.wait_event.set()
            elif m.get_rss() != 0:
                output_line = '\t'.join((str(int(x)) for x in (m.get_senderNodeId(), m.get_receiverNodeId(), m.get_channel(), m.get_rss(), 31, time.time(), m.get_measurementNum()))) + '\n'
                try:
                    self.outfile.write(output_line)
                except AttributeError:
                    sys.stdout.write(output_line)
                    sys.stdout.flush()
        # how it should be
        # elif msg.get_amType()==142:
        #     try:
        #         self.outfile.close()
        #     except AttributeError:
        #         pass
        #     sys.exit(0)


    def send(self, args):

        smsg = SerialControl.SerialControl()
        smsg.set_cmd(0)
        smsg.set_channels(args.channels)
        smsg.set_num_channels(len(args.channels))
        # 0 means, don't change the value
        smsg.set_num_measurements(args.measurements)
        smsg.set_channel_wait_time(args.channelWait)
        smsg.set_sender_channel_wait_time(args.senderChannelWait)
        smsg.set_id_request_wait_time(args.idWait)
        smsg.set_data_collection_channel(0) # not used
        self.mif.sendMsg(self.tos_source, 0xFFFF, smsg.get_amType(), 0, smsg)

def main():

    #argparse
    #import ipdb; ipdb.set_trace()
    parser = argparse.ArgumentParser(formatter_class=argparse.ArgumentDefaultsHelpFormatter)
    # 0 is using values from nesc code
    parser.add_argument('--measurements', default=20, type=int, help='How many measurements per node and channel')

    class ChannelListAction(argparse.Action):
        def __init__(self, option_strings, dest, nargs=None, **kwargs):
            if nargs is not None:
                raise ValueError("nargs not allowed")
            super(ChannelListAction, self).__init__(option_strings, dest, **kwargs)
        def __call__(self, parser, namespace, values, option_string=None):
            setattr(namespace, self.dest, [int(x) for x in values.split(',')][:16])

    parser.add_argument('--channels', default=list(range(11,27)), type=str, help='The channel to measure on. comma separated (e.g. 11,12,13,14). Limited to 16 values. has to start with 11', action=ChannelListAction)
    parser.add_argument('--channelWait', default=100, type=int, help='How much time to wait after a channel switch')
    parser.add_argument('--senderChannelWait', default=200, type=int, help='How much time to wait after a channel switch (sink node)')
    parser.add_argument('--idWait', default=2000, type=int, help='How much time to wait for node ids?')
    #parser.add_argument('--collectionChannel', default=0, type=int, help='') # not supported yet
    parser.add_argument('--outfile', type=str, help='Write to stdout or to a filename')
    parser.add_argument('--nodePath', default='serial@/dev/ttyUSB0:115200', type=str, help='the path of the sink node')
    args = parser.parse_args()

    # TODO: print usage if -h in arguments

    wait_event = threading.Event()
    dl = HostController(args.nodePath, args.outfile, wait_event)
    dl.send(args)
    wait_event.wait()


if __name__ == '__main__':
    try:
        main()
    except KeyboardInterrupt:
        pass
