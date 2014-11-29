/*
 * Copyright (c) 2008 Onur Ergin
 * All rights reserved
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 * - Redistributions of source code must retain the above copyright
 *   notice, this list of conditions and the following disclaimer.
 * - Redistributions in binary form must reproduce the above copyright
 *   notice, this list of conditions and the following disclaimer in the
 *   documentation and/or other materials provided with the
 *   distribution.
 * - Neither the name of the Stanford University nor the names of
 *   its contributors may be used to endorse or promote products derived
 *   from this software without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
 * ``AS IS'' AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
 * LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS
 * FOR A PARTICULAR PURPOSE ARE DISCLAIMED.  IN NO EVENT SHALL DIMAS ABREU
 * DUTRA OR HIS CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT,
 * INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
 * (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
 * SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
 * HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT,
 * STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
 * ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED
 * OF THE POSSIBILITY OF SUCH DAMAGE.
 */

/**
 * @author Onur Ergin
 */

#ifndef RSSIMESSAGES_H__
#define RSSIMESSAGES_H__

enum {
  AM_RSSIMSG = 0x06
};

 typedef nx_struct RssiMsg {
  nx_uint16_t appid;	// Application id to avoid processing of the irrelevant packets from other applications
  nx_uint8_t pcktype;	// Type of packet
  nx_uint16_t nodeid;		// ID of the node that sends this packet
  nx_uint16_t senderid;	// Sender node id, of whose rssi is measured
  nx_uint16_t receiverid; // Receiver node id, which measures the rssi of the packet from the sender
  nx_uint16_t counter;
  nx_int8_t channel;	// The channel of the measurement
  nx_int8_t txpower;	// Transmission power of the measurement
  nx_uint16_t sprayIter;	// number of spraying iterations
  nx_int16_t r_rssi;	// rssi that receiver measures
  nx_uint8_t flag; // flag bit for various uses
} RssiMsg;

#endif //RSSIMESSAGES_H__
