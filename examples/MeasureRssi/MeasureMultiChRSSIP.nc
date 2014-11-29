// $Id: PERcalcP.nc,v 1.8 2008/02/19 19:56:03 scipio Exp $


#include "AM.h"
#include "Serial.h"
#include "Timer.h"
#include "UserButton.h"

//#include "Printf.h"
	#define printf(...) ;
	#define printfflush(...) ;

//#if TOS_NODE_ID != 0
//	#include "Printf.h"
//	#warning "If'in icinde"
//	#error "4"
//#else
//	#define printf(...) ;
//	#define printfflush(...) ;
//	#warning "Else'in icinde"
//	#error "5"
//#endif
	
#include "report.h"

//#define APP_ID 1982
#define RSSI_OFFSET (-45)

typedef nx_struct RssiMsg_t {
  nx_uint16_t appid;	// Application id to avoid processing of the irrelevant packets from other applications
  nx_uint8_t pcktype;	// Type of packet
  nx_uint16_t nodeid;		// ID of the node that sends this packet
  nx_uint16_t senderid;	// Sender node id, of whose rssi is measured
  nx_uint16_t receiverid; // Receiver node id, which measures the rssi of the packet from the sender
  nx_uint16_t counter;
  nx_int8_t channel;	// The channel of the measurement
  nx_int8_t txpower;	// Transmission power of the measurement
  nx_uint16_t sprayIter;	// rssi that sink measures
  nx_int16_t r_rssi;	// rssi that receiver measures
  nx_uint8_t flag; // flag bit for various uses
  
} PerMsg, ReportMsg, DummyPkt, RssiMsg;


typedef enum {	perIdle,		// not active
				perReceiving,	// some node with lower id is sending and it is counting
				perSending	// broadcasting test packets for other nodes with greater ids to count
				//perReporting	// sending counted packets over the Serial port. 
				} State_t;	// Node's state
 /* 
  * Packet Types
  */
 enum { START = 0, SPRAY = 1, REPORT = 2, QUERY = 3, PANIC = 4, SETSINK = 5, SENDER = 6 };  

module MeasureMultiChRSSIP {
  uses {
    interface Boot;
    interface SplitControl as SerialControl;
    interface SplitControl as RadioControl;

    interface AMSend as UartSend[am_id_t id];
    interface Receive as UartReceive[am_id_t id];
    interface Packet as UartPacket;
    interface AMPacket as UartAMPacket;
    
    interface AMSend as RadioSend[am_id_t id];
    interface Receive as RadioReceive[am_id_t id];
    interface Receive as RadioSnoop[am_id_t id];    //????
    interface Packet as RadioPacket;
    
    interface CC2420Packet;

    interface Leds;
    interface Random;
	
	interface Timer<TMilli> as TimerSend;	// Timer for transmissions
	interface Timer<TMilli> as TimerReport;	// Timer for reporting 
	interface Timer<TMilli> as TimerChannel;// Timer for channel shifting 
	
	// interface Timer<TMilli> as Timer1;
	// interface Timer<TMilli> as Timer2;
	
	interface Get<button_state_t>;
	interface Notify<button_state_t>;
  }
  
  uses interface GeneralIO as CSN;
  
  uses interface Resource as SpiResource;

  uses interface CC2420Ram as TXFIFO_RAM;
  uses interface CC2420Register as TXCTRL;
  uses interface CC2420Strobe as SNOP;
  uses interface CC2420Strobe as STXON;
  uses interface CC2420Strobe as STXONCCA;
  uses interface CC2420Strobe as SFLUSHTX;
  uses interface CC2420Register as MDMCTRL1;
  uses interface CC2420Register as FSCTRL;

  uses interface CC2420Strobe as SRFOFF;
  uses interface CC2420Strobe as SRXON;
  
}

implementation
{
  enum {
    UART_QUEUE_LEN = 12,
    RADIO_QUEUE_LEN = 12,
  };
  
  enum { 
  		REF_NODE_ID = 0, 
  		CONSTANT = 40, CHANNEL1 = 11, CHANNELS = 16, ENDVAL = 9999, 
  		ENDVAL_COUNT = 1, PERIOD = 20, KICKOFF=3000,
  		AM_ID = 0x06, APP_ID = 13
  	     };

  bool       uartBusy;
  bool       radioBusy;
  
  void goIdle();
  void goSending();
  void goReceiving();
  task void spray();
  task void send2pc();
  error_t send2Uart(PerMsg *);
  void sendStart();
  void sendQuery();
  void sendPanic();
  void relayPanic(nx_uint16_t, nx_uint16_t);
  task void announceSender();
  
  message_t* receive(message_t* msg, void* payload, uint8_t len);
  
  State_t nodeState;
  static uint16_t sendCount;	// sequence of the transmitted packets.
  uint16_t rcvCount;	// number of received packets from a specific sender
  //uint8_t rcvFrom;		// ID of the node which sends the bulk packets, must be LOWER then TOS_NODE_ID!!!
  uint8_t endvalCount;
  static DummyPkt currentRprt;	// Keep the latest reading in this
  bool reported;		// Keeps if it has reported after receiving ENDVAL
  bool sprayed;			// If the node has already sprayed
  bool isSink;		// Sink node should have this TRUE
  uint16_t rcvFrom;	// Id of the current sender
  bool startSent;
  bool panicked;
  bool txpchanged;
  uint16_t sprayIter;
  //uint16_t reportTime;
  
  int16_t maxRSS;
  uint16_t maxxRSSCount;
  uint8_t  maxRSSCh;
    
  static uint8_t curChannel;
  static uint8_t nextChannel;
  static uint8_t curTxPower;
  static uint8_t nextTxPower;
    
  void setTxPower(uint8_t);
  void setChannel(uint8_t);
  error_t acquireSpiResource();
  error_t releaseSpiResource();

  void proceed ();   
  task void report();

  PerMsg *genmsg;  
  message_t pkt;
  message_t upkt;

  uint8_t count = 0;
  uint8_t ledstate;
  uint16_t buttonTime;

  
	
  event void Boot.booted() {

		uartBusy = FALSE;
		radioBusy = FALSE;
		
		call RadioControl.start();
		call SerialControl.start();
		
		call Notify.enable();
			
		goIdle();
		
		rcvFrom = TOS_NODE_ID;
		rcvCount = 0;
		endvalCount = ENDVAL_COUNT;
		reported = FALSE;
		sprayed = FALSE;
		rcvFrom = 0xFFFF;
		sprayIter = SPRAY_CONSTANT;
		buttonTime = 0;
//		reportTime = PERIOD + (TOS_NODE_ID%PERIOD) * 2;
		
		maxRSS = -1000;
		maxxRSSCount = 0;
		maxRSSCh = 0;
		
		startSent = FALSE;
		panicked = FALSE;
		txpchanged = FALSE;
		if (TOS_NODE_ID == REF_NODE_ID)
			isSink = TRUE;
		else isSink = FALSE;
		
		curChannel = CC2420_DEF_CHANNEL;
		curTxPower = CC2420_DEF_RFPOWER;
		nextChannel = curChannel;
		nextTxPower = curTxPower;
		
		initReport();
		
		if (TOS_NODE_ID == REF_NODE_ID)
		{
			printf("I'm the ref node, ");
/*
			sendStart();		
			goSending();
*/
			//post spray(); // start spraying.
			//call TimerSend.startOneShot(2000);
		}
		else
			printf("I'm a receiver, ");
		
		printf("channel=%d txpower=%d\n", curChannel, curTxPower);
		printfflush();
	}
  
	void goIdle()		// Switch state to perIdle
	{
		if (nodeState != perIdle)
		{
		   reported = FALSE;
		   rcvCount = 0;
		   rcvFrom = TOS_NODE_ID;
		   call Leds.led0Off();
		   call Leds.led1Off();
		   call Leds.led2On();
		   nodeState = perIdle;
		   printf("%d: goIdle.\n", TOS_NODE_ID);
		   printfflush();
		}
	}

	void goSending()	// Switch state to perSending;
	{
		if (nodeState != perSending)
	    {
		   call Leds.led0Off();
		   call Leds.led1Off();
		   call Leds.led2Off();
		   sendCount = 0;
		   nodeState = perSending;
		   rcvFrom = TOS_NODE_ID;
		   call TimerSend.startOneShot(2000);
		   printf("%d: goSending.\n", TOS_NODE_ID);
		   printfflush();
		}
	}

	void goReceiving()	// Switch state to perSending;
	{
		if (nodeState != perReceiving)
		{
		   call Leds.led0Off();
		   call Leds.led1On();
		   call Leds.led2Off();
		   nodeState = perReceiving;
		   
		   maxRSS = -1000;
		   maxRSSCh = 0;
		   maxxRSSCount = 0;
		   printf("%d: goReceiving.\n", TOS_NODE_ID);
		   printfflush();
		}
	}  
	task void spray()
	{
		am_id_t id = AM_ID;
		DummyPkt* perpkt;
		perpkt = (DummyPkt*)(call RadioPacket.getPayload(&pkt, (int) NULL));
		perpkt->appid = APP_ID;
		perpkt->nodeid = TOS_NODE_ID;
		perpkt->pcktype = SPRAY;
		perpkt->channel = curChannel;
		perpkt->sprayIter = sprayIter;
		perpkt->txpower = curTxPower;
		
		if (radioBusy)
		{
			call TimerSend.startOneShot(PERIOD);
			return;
		}
		
		if (sendCount <= sprayIter) 			// Transmit the next packet in the sequence
			perpkt->counter = sendCount++;
		else								// If all packets sent; send the ENDVAL to finish measuring
			perpkt->counter = ENDVAL;
			
		//call Leds.led0Toggle();				// Blink led 0 if spraying
		
		if (call RadioSend.send[id](AM_BROADCAST_ADDR, &pkt, sizeof(DummyPkt)) == SUCCESS) {
		  radioBusy = TRUE;
		  call Leds.led0On();
		  //printf("Sprayed %d Ch=%d\n",sendCount, curChannel);
		}
		
		proceed();
	}
	  
	void proceed () {	//Continue with transmissions and advancing the channels
	
		if (sendCount > sprayIter)		// Transmit sufficient(?) number of ENDVALs to make sure it was received by the target(s).
		{
			nextChannel = curChannel + 1;
			printf("nextChannel = %d, sendCount=%d\n", nextChannel, sendCount);
			if (nextChannel < CHANNEL1 + CHANNELS) {
				//change channel to nextChannel
				acquireSpiResource(); 					  	
				
				sendCount = 0;
				call TimerSend.startOneShot(PERIOD*2);
				
			}
			else {
				nextChannel = CHANNEL1;
				sprayed = TRUE;
				acquireSpiResource();
				goIdle();
			}
		}
		else call TimerSend.startOneShot(PERIOD);	 
	}
	
	event void RadioSend.sendDone[am_id_t id](message_t* msg, error_t error) {
		if (error != SUCCESS) {
		  sendCount--;	// If packet couldn't be transmitted.
		  printf("Transmit fail, sendCount=%d\n", sendCount);
		}
		else { radioBusy = FALSE; 
			call Leds.led0Off();
			}
		
		if (nodeState == perSending)
			;//proceed();
	}
	  
	event message_t *RadioSnoop.receive[am_id_t id](message_t *msg, void *payload, uint8_t len) {
		return receive(msg, payload, len);
	}
	  
	event message_t *RadioReceive.receive[am_id_t isd](message_t *msg,
								void *payload,
								uint8_t len) {
		return receive(msg, payload, len);
	}
	
	void resetNode() {
		rcvCount = 0;
		endvalCount = ENDVAL_COUNT;
		reported = FALSE;
		sprayed = FALSE;
		rcvFrom = 0xFFFF;
		
		maxRSS = -1000;
		maxxRSSCount = 0;
		maxRSSCh = 0;
		initReport();
	}

	message_t* receive(message_t *msg, void *payload, uint8_t len) {
		message_t *ret = msg;
		//am_id_t id = 0x09;
		DummyPkt *incoming = (DummyPkt*)(call RadioPacket.getPayload(ret, (int) NULL));
		//uint16_t randwait = CONSTANT / 2;
		
		int16_t rssi;
		
		if (incoming->appid != APP_ID || incoming->nodeid == TOS_NODE_ID) return ret;	// wrong packet
		
		if (incoming->txpower != curTxPower && incoming->txpower != 0) {
			txpchanged = TRUE;
			nextTxPower = incoming->txpower;
			acquireSpiResource();
		}
		
		switch (incoming->pcktype)	// Who am I? What's my duty?
		{		
		
			case START:
				//if (nodeState == perIdle || TRUE) {
				if ((!isSink && TOS_NODE_ID != REF_NODE_ID) && !startSent) {
					/*
					rcvFrom = TOS_NODE_ID;
					rcvCount = 0;
					endvalCount = ENDVAL_COUNT;
					reported = FALSE;
					sprayed = FALSE;
					rcvFrom = 0xFFFF;					
					
					maxRSS = -1000;
					maxxRSSCount = 0;
					maxRSSCh = 0;
					initReport();
					*/
					
					resetNode();
					
					printf("START Packet received from %d, resetting data\n", incoming->nodeid);
					
					goIdle();
					call TimerSend.stop();
					call TimerReport.stop();
					call TimerChannel.stop();
					
					sendStart();
				}
				break;
				
			case REPORT:
				if (findReport(incoming->senderid, incoming->receiverid) == REC_ERR) {
					printf("RCV2: Received Report packet from %d of %d->%d(%d) and forwarding.\n",incoming->nodeid, incoming->senderid, incoming->receiverid, incoming->counter);
					addReport(incoming->senderid, incoming->receiverid, incoming->r_rssi, incoming->counter, incoming->channel);			
					printf("\nREPORT: Added Received Report for %d to %d->%d(%d) and forwarding.\n", incoming->senderid, incoming->receiverid, incoming->r_rssi, incoming->channel);
					
					if (! call TimerReport.isRunning())
					call TimerReport.startOneShot( PERIOD + ((TOS_NODE_ID+1)%PERIOD) * 2 );
				}
				break;
					
			case SENDER:
				if (incoming->senderid < rcvFrom && incoming->senderid != TOS_NODE_ID) {
					sendCount = 0;
					goReceiving();		// Then switch receiving state and start counting
					rcvFrom = incoming->senderid;
					rcvCount = 1;
					//post announceSender();
					printf("%d: %d<%d && %d!=%d SENDER set.\n",TOS_NODE_ID, incoming->senderid, rcvFrom, incoming->senderid, TOS_NODE_ID);

					call TimerChannel.startOneShot((sprayIter - 2)*PERIOD);
					printf("TimerChannel is set with counter: %d at channel:%d for new SENDER: %d\n", incoming->counter, curChannel, rcvFrom);
					nextChannel = incoming->channel >= CHANNEL1+CHANNELS-1 ? CHANNEL1 : incoming->channel+1;
				}
				else {
					printf("%d: %d<%d && %d!=%d SENDER NOT set.\n",TOS_NODE_ID, incoming->senderid, rcvFrom, incoming->senderid, TOS_NODE_ID);
				}
				break;
				
			case SPRAY:			// I am a receiver, I will broadcast my measurement throught the radio
				//if (incoming->nodeid == REF_NODE_ID)	// 
				startSent = FALSE; // restartable
				switch (nodeState) {
					case perSending:
					if (incoming->nodeid < TOS_NODE_ID) {
						sendCount = 0;
						goReceiving();		// Then switch receiving state and start counting
						rcvFrom = incoming->nodeid;
						rcvCount = 0;
						//post announceSender();
					}
					else 
						break;
					
					case perIdle:
						goReceiving();		// Then switch receiving state and start counting
						rcvFrom = incoming->nodeid;
						rcvCount = 0;
						reported = FALSE;
						printf("RCV3: Receive: Switching to Receive state from state %d for sender %d.\n",nodeState, rcvFrom);
						//post announceSender();
					case perReceiving:		

						if (nodeState == perReceiving)
						{
							if (rcvFrom == TOS_NODE_ID)
								break;
								
							if (rcvFrom < incoming->nodeid && curChannel == CHANNEL1)
								;//post announceSender();
							else if (rcvFrom < incoming->nodeid && curChannel > CHANNEL1) { //panic
							
								panicked = TRUE;
								call Leds.led0On();
								resetNode();
								
								printf("PANIC: rcvFrom = %d , senderid = %d\n", rcvFrom, incoming->nodeid);
								
								sendPanic();
								
								nextChannel = CHANNEL1;
								
								call TimerSend.stop();
								call TimerReport.stop();
								call TimerChannel.startOneShot(PERIOD);
							}
								
							if (incoming->nodeid < rcvFrom) {
								//Clear the record of the previous sender
								rcvFrom = incoming->nodeid;		
								rcvCount = 0;
								goReceiving();
								//post announceSender();
								//clearReported(rcvFrom, TOS_NODE_ID);
							}
							
							if (incoming->nodeid == rcvFrom) { 
								if (incoming->sprayIter != sprayIter)
									sprayIter = incoming->sprayIter;
									
								call Leds.led1Toggle();
								
								rssi = call CC2420Packet.getRssi(ret) + RSSI_OFFSET;
								//currentRprt.r_rssi	 = rssi;
								
								rcvCount++;
								
								//reported = FALSE;
								//randwait = (call Random.rand16()) % (PERIOD-(PERIOD/4));
								//call TimerReport.startOneShot(PERIOD - randwait); 
								
								if (rssi > maxRSS) {
									printf("\nR S S I ---->>>>  rssi=%d > maxRSS=%d at Ch=%d\n\n",rssi ,maxRSS, curChannel);
									maxRSS = rssi;
									maxRSSCh = curChannel;
									maxxRSSCount = 1;
								} else if (rssi == maxRSS) {
									maxxRSSCount++;
								}
								
								if (!call TimerChannel.isRunning() || incoming->counter%(int)(sprayIter/3) == 0) {
									call TimerChannel.startOneShot((sprayIter - incoming->counter+1)*PERIOD);
									printf("Timer is set with counter: %d at channel:%d\n", incoming->counter, curChannel);
									nextChannel = incoming->channel >= CHANNEL1+CHANNELS-1 ? CHANNEL1 : incoming->channel+1;
								}
								
								printf("RCV: %d(CH: %d -- %d) = %d\n", incoming->nodeid, incoming->channel, incoming->counter, rssi);
								printfflush();
								
								/*
								if (nextChannel == CHANNEL1) {
									addReport(rcvFrom, TOS_NODE_ID, maxRSS, maxRSSCh);
									// post a report task
									post report();
									rcvFrom = 0xFFFF;
									if (!sprayed)
										goSending();
								}
								*/
							}
						}//if PerReceiving
						else 
							break;
						break; //perreceiving
				    default: break;
				}	//switch nodestate		
				
				break; 
				
				case QUERY:
				if (nextUnReportedIx() == REC_ERR && (TOS_NODE_ID != REF_NODE_ID && !isSink)) {
					sendQuery();
					clearAllReported();
					//post report();
					call TimerReport.startOneShot(PERIOD + (TOS_NODE_ID%PERIOD)*2);
				}
					break;
				case PANIC:
					if (!panicked) { // if not panicked already
						panicked = TRUE;
						resetNode();
						
						printf("PANIC Received from %d", incoming->nodeid);
						
						relayPanic(incoming->senderid, incoming->receiverid);
						nextChannel = CHANNEL1;
						call TimerSend.stop();
						call TimerReport.stop();
						call TimerChannel.startOneShot(PERIOD);
					
						if (TOS_NODE_ID == REF_NODE_ID || isSink) { // Let the user know
							send2Uart(incoming);
						}
					}
					break;
				
				default:
		}	
		printfflush();
	    return ret;
	}

	event message_t *UartReceive.receive[am_id_t id](message_t *msg, void *payload, uint8_t len) {
		DummyPkt *incoming = (DummyPkt*)(call RadioPacket.getPayload(msg, (int) NULL));
	
		switch (incoming->pcktype) {
			case START:
				
				
				printf("START Packet received from %d, resetting data\n", incoming->nodeid);

				call TimerSend.stop();
				call TimerReport.stop();
				call TimerChannel.stop();
				resetNode();
				
				if (incoming->sprayIter != 0)
					sprayIter = incoming->sprayIter;
					
				if (incoming->txpower != curTxPower && incoming->txpower != 0) {
					txpchanged = TRUE;
					nextTxPower = incoming->txpower;
					acquireSpiResource();
				}
					
				sendStart();
				goSending();
				break;
			case QUERY:
				if (nextUnReportedIx() == REC_ERR) {
					sendQuery();
					//clearAllReported();
					//post report();
				}
				break;				
			case SETSINK:
				isSink = TRUE;
			default:
		}
		return msg;
	}


	event void TimerSend.fired() {
		//call Leds.led0On();
		if ( nodeState == perSending )
			post spray();
	}

	event void TimerReport.fired() {
		post report();
	}
	
	
	event void TimerChannel.fired() {
	
			// set new channel to (curChannel+1)%CHANNELS
			//nextChannel = (curChannel + 1) % CHANNELS;
			//nextChannel = curChannel >= CHANNEL1+CHANNELS-1 ? CHANNEL1 : curChannel+1;
			//int16_t maxScaledRSS;
			//maxScaledRSS = maxRSS*sprayIter + maxxRSSCount;
						
			acquireSpiResource();
			
			if (panicked) {
				panicked = FALSE;
				goIdle();
				return;
			} else
			if (nextChannel == CHANNEL1) {
				addReport(rcvFrom, TOS_NODE_ID, maxRSS, maxxRSSCount, maxRSSCh);
				printf("REPORT: Added Self Report for %d to %d->%d:%d(%d) and forwarding.\n",rcvFrom, TOS_NODE_ID, maxRSS, maxxRSSCount, maxRSSCh);
				// post a report task
				//post report();
				call TimerReport.startOneShot(PERIOD + (TOS_NODE_ID%PERIOD)*2);
				rcvFrom = 0xFFFF;
				if (!sprayed)
					goSending();
				else 
					goIdle();
			}
			else 
				call TimerChannel.startOneShot(PERIOD*(sprayIter+1));
	}
	
	task void report()
	{
		uint16_t reportTime, nextIx, nextSid, nextRid, nextMeasurement, nextMeasurementCount, nextMsrmChannel, newNextIx;
		error_t err;
		am_id_t id = AM_ID;
		PerMsg *reppkt;
				
		nextIx = nextUnReportedIx();
		
		
		
		if ( nextIx == REC_ERR ) {
			printf ("report: Nothing to report, nextIx = %d\n",nextIx);
			printfflush();
			return;
		}
		nextMeasurement = getMeasurementIx(nextIx);
		nextMeasurementCount = getMeasurementCountIx(nextIx);
		nextMsrmChannel = getChannelIx(nextIx);
		nextSid = getSenderId(nextIx);
		nextRid = getReceiverId(nextIx);
		
		//printf("In Report(), nextIx = %d : %d->%d = %d (%d)\n",nextIx, nextSid, nextRid, nextMeasurement, nextMsrmChannel);
		//printfflush();
		
		reppkt = (PerMsg*)(call RadioPacket.getPayload(&pkt, (int) NULL));
		   reppkt->nodeid = TOS_NODE_ID;
		   reppkt->senderid = nextSid;
		   reppkt->receiverid = nextRid;
		   reppkt->r_rssi = nextMeasurement;
		   reppkt->counter = nextMeasurementCount;
		   reppkt->channel = nextMsrmChannel;
		   reppkt->pcktype = REPORT;
		   reppkt->appid = APP_ID;
		   
		   reportTime = PERIOD;
		   
		   if (TOS_NODE_ID != REF_NODE_ID || 1) {
			   
			   if (radioBusy && !(call TimerReport.isRunning())) {
				call TimerReport.startOneShot(reportTime);
				//call Busy.wait(TOS_NODE_ID%PERIOD);
				//post report();
				return;
			   }
			   
			   err = call RadioSend.send[id](TOS_NODE_ID, &pkt, sizeof(PerMsg));
			   
			   if ( err == SUCCESS) {
				 radioBusy = TRUE;
				 setReported(nextSid, nextRid);
				 //printf("\t report: To air: nodeid=%d, receiverid=%d, senderid=%d, counter=%d \n",reppkt->nodeid, reppkt->receiverid, reppkt->senderid, reppkt->counter);
			   }
			   else { 
					call Leds.led0On(); 
					printf("Error in report to air for sender %d : ", reppkt->senderid); 
					switch(err){
						case FAIL: printf("FAIL"); break;
						case EBUSY: printf("EBUSY"); break;
						case ECANCEL: printf("ECANCEL"); break;
						default: printf("UNDEFINED!!!!!"); break;
					}
					printf("(%d)\n",err);
					
					if (!(call TimerReport.isRunning())) {
						call TimerReport.startOneShot(reportTime);
						return;
				   }
					
			   }
			}  // if not sink
			//else { // if sink
//#ifndef PRINTF_H
			if (TOS_NODE_ID == REF_NODE_ID || isSink) {
			   err = send2Uart(reppkt);		   	
			   
			   if (err == SUCCESS) {
					uartBusy = TRUE;
					setReported(nextSid, nextRid);
			   }
			   else {			   			
					clearReported (reppkt->senderid, reppkt->receiverid);			
					if (!(call TimerReport.isRunning())) {
						call TimerReport.startOneShot(reportTime);
						return;
				   }
			   }
			}
//#endif
			
		newNextIx = nextUnReportedIx();

		//printf("NewNextUnreportedIx = %d\n",newNextIx);

		//printfflush();
		
		if (newNextIx != REC_ERR){
			if (! call TimerReport.isRunning())	// Start report timer.
			{
				reportTime = PERIOD;
				call TimerReport.startOneShot(reportTime); // just enough to receive all. 
				//post report();
				//printf("\treport: TimerReport set to %d ms, newNextIx=%d\n",reportTime, newNextIx);
			}
		}
		else {				
			if (FALSE && isReported(rcvFrom, TOS_NODE_ID)){
				rcvFrom = TOS_NODE_ID;
				goIdle();
		}
 
			/*
			printf("Here!@!!!!\n");
			if( !sprayed ) {
			   goSending();
			   printf("\t report: Switching to perSending state in %d ms\n",PERIOD*1+TOS_NODE_ID%PERIOD);
			   call TimerSend.startOneShot(PERIOD*TOS_NODE_ID + (TOS_NODE_ID % PERIOD));
			 }
			else 
				goIdle();	   
			*/
		}
		
		printfflush();
	}// report task
	
	
	task void send2pc()	// BUNUN YERINE GELEN MESAJI DOGRUDAN KOPYALA
	{	
		am_id_t id = AM_ID;

		ReportMsg* reppkt = (ReportMsg*)(call UartPacket.getPayload(&pkt, (int) NULL));
		reppkt->appid	 = APP_ID;
		reppkt->nodeid	 = TOS_NODE_ID;
		reppkt->senderid = currentRprt.senderid;
		reppkt->receiverid = currentRprt.receiverid;
		reppkt->counter  = currentRprt.counter;
		reppkt->r_rssi   = currentRprt.r_rssi;
		reppkt->channel  = currentRprt.channel;
		reppkt->txpower  = currentRprt.txpower;
		
		//printf("Reporting: r_node=%d r_rssi=%d counter=%d channel=%d txpower=%d\n",reppkt->receiverid, 
		//						reppkt->r_rssi, reppkt->counter, reppkt->channel, reppkt->txpower);
		
		//call Leds.led1Off();
		if (call UartSend.send[id](TOS_NODE_ID, &pkt, sizeof(ReportMsg)) == SUCCESS) {
		  uartBusy = TRUE;
		  reported = TRUE;		  
		}

	}
	
	error_t send2Uart (PerMsg *incoming)
	{
		
		am_id_t uid = AM_ID;
		error_t err;

	    
		PerMsg* reppkt = (PerMsg*)(call UartPacket.getPayload(&upkt, (int) NULL));
		reppkt->nodeid = incoming->nodeid;
		reppkt->receiverid = incoming->receiverid;
		reppkt->senderid = incoming->senderid;
		reppkt->r_rssi = incoming->r_rssi;
		reppkt->channel = incoming->channel;
		reppkt->counter = incoming->counter;
		reppkt->pcktype = incoming->pcktype;
		reppkt->appid = incoming->appid;
		
	    //printf("Entered: send2Uart: nodeid=%d, receiverid=%d, senderid=%d, counter=%d \n",incoming->nodeid,\
		  //			incoming->receiverid, incoming->senderid, incoming->counter);
		call Leds.led1Off();
		
		err = call UartSend.send[uid](TOS_NODE_ID, &upkt, sizeof(PerMsg)); 
		
		if ( err == SUCCESS) {
		  uartBusy = TRUE;
		  printf("\t send2Uart: nodeid=%d, receiverid=%d, senderid=%d, counter=%d \n",reppkt->nodeid,\
		  			reppkt->receiverid, reppkt->senderid, reppkt->counter);
		}
		else { 
			call Leds.led0On(); 
			printf("Error in send2Uart for sender: %d : ", reppkt->senderid); 
			switch(err){
				case FAIL: printf("FAIL"); break;
				case EBUSY: printf("EBUSY"); break;
				case ECANCEL: printf("ECANCEL"); break;
				default: printf("UNDEFINED!!!!!"); break;
			}
			printf("(%d)\n",err);		
		}
		
		printfflush();
		 
		return err;
	}
	  
	void sendStart() {
		am_id_t uid = AM_ID;

		PerMsg* reppkt = (PerMsg*)(call RadioPacket.getPayload(&pkt, (int) NULL));
		reppkt->nodeid = TOS_NODE_ID;
		reppkt->senderid = TOS_NODE_ID;
		reppkt->pcktype = START;
		reppkt->appid = APP_ID;
		reppkt->sprayIter = sprayIter;
		reppkt->txpower = curTxPower;
				
				
		if (call RadioSend.send[uid](TOS_NODE_ID, &pkt, sizeof(PerMsg)) == SUCCESS) {
		  radioBusy = TRUE;
		  printf("\t sendStart: nodeid=%d at %d \n",reppkt->nodeid, (int)call TimerSend.getNow());		
		  startSent = TRUE;
		}
		else { 
			call Leds.led0On(); 
			printf("Error in sendStart\n"); 
		}
		printfflush();		
	}
	
	void sendQuery() {
		am_id_t uid = AM_ID;

		PerMsg* reppkt = (PerMsg*)(call RadioPacket.getPayload(&pkt, (int) NULL));
		reppkt->nodeid = TOS_NODE_ID;
		reppkt->senderid = TOS_NODE_ID;
		reppkt->pcktype = QUERY;
		reppkt->appid = APP_ID;
		reppkt->txpower = curTxPower;
				
				
		if (call RadioSend.send[uid](TOS_NODE_ID, &pkt, sizeof(PerMsg)) == SUCCESS) {
		  radioBusy = TRUE;
		  printf("\t sendQuery: nodeid=%d at %d \n",reppkt->nodeid, (int)call TimerSend.getNow());				  
		}
		else { 
			call Leds.led0On(); 
			printf("Error in sendQuery\n"); 
		}
		printfflush();		
	}
	
	void sendPanic() {
		am_id_t uid = AM_ID;

		PerMsg* reppkt = (PerMsg*)(call RadioPacket.getPayload(&pkt, (int) NULL));
		reppkt->nodeid = TOS_NODE_ID;
		reppkt->senderid = rcvFrom;
		reppkt->receiverid = TOS_NODE_ID;
		reppkt->pcktype = PANIC;
		reppkt->appid = APP_ID;
		reppkt->txpower = curTxPower;
				
				
		while (call RadioSend.send[uid](TOS_NODE_ID, &pkt, sizeof(PerMsg)) != SUCCESS) {
		  radioBusy = TRUE;
		  printf("\t sendPanic: nodeid=%d at %d \n",reppkt->nodeid, (int)call TimerSend.getNow());				  
		}
		
		if (isSink)
			send2Uart(reppkt);

		printfflush();		
	}
	
	void relayPanic(nx_uint16_t tsender, nx_uint16_t treceiver) {
		am_id_t uid = AM_ID;

		PerMsg* reppkt = (PerMsg*)(call RadioPacket.getPayload(&pkt, (int) NULL));
		reppkt->nodeid = TOS_NODE_ID;
		reppkt->senderid = tsender;
		reppkt->receiverid = treceiver;
		reppkt->pcktype = PANIC;
		reppkt->appid = APP_ID;
		reppkt->txpower = curTxPower;
				
				
		while (call RadioSend.send[uid](TOS_NODE_ID, &pkt, sizeof(PerMsg)) != SUCCESS) {
		  radioBusy = TRUE;
		  printf("\t relayPanic: nodeid=%d at %d \n",reppkt->nodeid, (int)call TimerSend.getNow());				  
		}

		printfflush();		
	}
	
	task void announceSender() {
		am_id_t uid = AM_ID;
		
		PerMsg* reppkt = (PerMsg*)(call RadioPacket.getPayload(&pkt, (int) NULL));
		reppkt->nodeid = TOS_NODE_ID;
		reppkt->senderid = rcvFrom;
		reppkt->receiverid = TOS_NODE_ID;
		reppkt->pcktype = SENDER;
		reppkt->sprayIter = sprayIter;
		reppkt->appid = APP_ID;
		reppkt->txpower = curTxPower;
		reppkt->channel = curChannel;
				
		printf("%d: In announceSender()\n", TOS_NODE_ID);	
		
		while (call RadioSend.send[uid](TOS_NODE_ID, &pkt, sizeof(PerMsg)) != SUCCESS) {
		  radioBusy = TRUE;
		  printf("\t Sender Announced: nodeid=%d, senderid=%d at %d \n",reppkt->nodeid,reppkt->senderid, (int)call TimerSend.getNow());				  
		}

		printfflush();	
	}
	
	event void UartSend.sendDone[am_id_t id](message_t* msg, error_t error) {
		if (error != SUCCESS)
		  ;
		else
		  uartBusy = FALSE;
	}

	event void RadioControl.startDone(error_t error) { 
		if (error == SUCCESS) {
		
			if (TOS_NODE_ID != REF_NODE_ID || isSink) {
				goIdle();
				printf("not sink at radiocontrol.startdone \n");
			}
			else {
				printf("sink! at radiocontrol.startdone\n");
				//sendStart();		
				//goSending();
			}
		}	
		
	}
	event void SerialControl.startDone(error_t error) {	if (error == SUCCESS) {} }  
	  
	event void SerialControl.stopDone(error_t error) {}
	event void RadioControl.stopDone(error_t error) {}


	
	event void Notify.notify( button_state_t state ) {
		uint16_t tempTime;
		
		if ( state == BUTTON_PRESSED ) {
		
			buttonTime = call TimerSend.getNow();

		   ledstate = call Leds.get();
		   call Leds.led0On();
		   call Leds.led1On();
		   call Leds.led2On();
		  //report();
		  printf("Node state: %d\n", nodeState);

   		  call Leds.led1Off();

		  printReports(); 
		} 
		else if ( state == BUTTON_RELEASED ) {
			
		  tempTime = call TimerSend.getNow();
		  printf("Button released at: %d after %dms\n", tempTime, tempTime-buttonTime);
		  
		  clearAllReported();
		  post report();

		  buttonTime = 0;
		  call Leds.set(ledstate);		
		}
		printfflush();
	}
	
	/***************** SpiResource Events ****************/
	  event void SpiResource.granted() {
		
			printf("Request Granted\n"); printfflush();
	
		if (txpchanged) {
			setTxPower(nextTxPower);
			txpchanged = FALSE;
		}
		else if (nextChannel != curChannel)
			setChannel(nextChannel);
	
		//if ( nextTxPower != curTxPower)
		//	setTxPower(nextTxPower);
	
		releaseSpiResource();
	  }
		
		error_t acquireSpiResource() {
			error_t error = call SpiResource.immediateRequest();
	
			printf("AquireSpiResource()\n"); printfflush();
	
			if ( error != SUCCESS ) {
				printf("immediate not possible, requesting()\n"); printfflush();
			  call SpiResource.request();
			}
			else {
				if (txpchanged) {
					setTxPower(nextTxPower);		
					txpchanged = FALSE;
				}
				else if (nextChannel != curChannel)
					setChannel(nextChannel);
			
				//if ( nextTxPower != curTxPower)
				//	setTxPower(nextTxPower);
					
				releaseSpiResource();
			}
			return error;
		}
		  
		error_t releaseSpiResource() {
			printf("Spi resource releasing()\n"); printfflush();
			call SpiResource.release();
			return SUCCESS;
		}
  	
	void setTxPower(uint8_t tpower) {
		uint8_t tx_power = tpower;
		uint16_t wr_power = 0;
		uint16_t rd_power = 0;
		cc2420_status_t status;
		
		call CSN.clr();
		call SRFOFF.strobe();
		call CSN.set();
		
		if ( !tx_power ) {
		  tx_power = CC2420_DEF_RFPOWER;
		}
		printf ("Now will set power to %d\n", tx_power); printfflush();
		atomic{
			call CSN.clr();		
			if ( curTxPower != tx_power ) {
			   wr_power = ( 2 << CC2420_TXCTRL_TXMIXBUF_CUR ) |
								 ( 3 << CC2420_TXCTRL_PA_CURRENT ) |
								 ( 1 << CC2420_TXCTRL_RESERVED ) |
								 ( (tx_power & 0x1F) << CC2420_TXCTRL_PA_LEVEL );
								 
				status = call TXCTRL.write( wr_power );
			}
			call TXCTRL.read(&rd_power);
			call CSN.set();
		}
		
		call CSN.clr();
		call SRXON.strobe();
		call CSN.set();
				
		printf("Written: %d(%X), Read:%d(%X)", wr_power, wr_power, rd_power, rd_power); printfflush();
		
		if ( rd_power != wr_power) 
			;//call Leds.led0On();
		else {
			;//call Leds.led0Off();
			curTxPower = tx_power;
		}
		
		if (curTxPower != tx_power) {
			printf("\t M_TX_POWER is set to %d from %d\n", tx_power, curTxPower);
			printfflush();
		}

		printfflush();
	}
	
	void setChannel (uint8_t tchannel) {
		uint8_t channel = tchannel;
		uint16_t wr_channel = 0, rd_channel = 0;
		
		cc2420_status_t status = 0;
		
		if(!channel) {
			channel = CC2420_DEF_CHANNEL;
		}
		
		
		call CSN.clr();
		call SRFOFF.strobe();
		call CSN.set();
		
		printf("set to channel=%d curChannel=%d nextChannel=%d\n",channel, curChannel,nextChannel);
		
		atomic {
			
			if (curChannel != nextChannel) {
			    call CSN.clr();
			    call FSCTRL.read(&wr_channel);
			    wr_channel = (wr_channel & 0xFE00) | ( ( (channel - 11)*5+357 ) << CC2420_FSCTRL_FREQ );
			    call CSN.set();
			    call CSN.clr();
				//wr_channel = ( 1 << CC2420_FSCTRL_LOCK_THR ) | ( ( (channel - 11)*5+357 ) << CC2420_FSCTRL_FREQ );
				status = call FSCTRL.write( wr_channel );
				call CSN.set();
			}
			
			do {			    
			    call CSN.clr();
				call FSCTRL.read(&rd_channel);
				call CSN.set();
	       } while (rd_channel & 0x1000);
		}
		
		call CSN.clr();
		call SRXON.strobe();
		call CSN.set();
		
		if (rd_channel != wr_channel) {
			printf("Problem: rd_channel=%d(0x%X) != wr_channel=%d(0x%X) && status = 0x%X SPI.owner=%d\n",rd_channel, rd_channel, wr_channel, wr_channel, status, call SpiResource.isOwner());
			call Leds.led0On();
		}
		else {
			call Leds.led0Off();		
			if ( TOS_NODE_ID == REF_NODE_ID || isSink )
				call Leds.led1Toggle();
			//else 
				//call Leds.led0Toggle();
			call Leds.led2Toggle();
			curChannel = channel;
		}
				
		printfflush();
	}
}  
