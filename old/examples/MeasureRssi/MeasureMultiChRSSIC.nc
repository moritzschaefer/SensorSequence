// $Id: PERcalcC.nc,v 1.0 2008/04/08 01:00:25 scipio Exp $
//UPDATE COMMENTS

configuration MeasureMultiChRSSIC {
}
implementation {
  components MainC, MeasureMultiChRSSIP, LedsC, RandomC, new TimerMilliC() as TimerSendC, 
  			 new TimerMilliC() as TimerReportC, new TimerMilliC() as TimerChannelC;
  components ActiveMessageC as Radio, 
			 SerialActiveMessageC as Serial;
  components CC2420ActiveMessageC;
  //components new AMSenderC(AM_BLINKTORADIO);

  
  MainC.Boot <- MeasureMultiChRSSIP;

  MeasureMultiChRSSIP.RadioControl -> Radio;
  MeasureMultiChRSSIP.SerialControl -> Serial;
  
  MeasureMultiChRSSIP.UartSend -> Serial;
  MeasureMultiChRSSIP.UartReceive -> Serial;
  MeasureMultiChRSSIP.UartPacket -> Serial;
  MeasureMultiChRSSIP.UartAMPacket -> Serial;
  
  MeasureMultiChRSSIP.RadioSend -> Radio;
  MeasureMultiChRSSIP.RadioReceive -> Radio.Receive;
  MeasureMultiChRSSIP.RadioSnoop -> Radio.Snoop;
  MeasureMultiChRSSIP.RadioPacket -> Radio;
  //MeasureMultiChRSSIP.RadioAMPacket -> Radio;
  //MeasureMultiChRSSIP.AMPacketSend -> AMSenderC;
  
  MeasureMultiChRSSIP -> CC2420ActiveMessageC.CC2420Packet;
  
  MeasureMultiChRSSIP.TimerSend->TimerSendC;
  MeasureMultiChRSSIP.TimerReport->TimerReportC;
  MeasureMultiChRSSIP.TimerChannel->TimerChannelC;
    
  MeasureMultiChRSSIP.Leds -> LedsC;
  MeasureMultiChRSSIP.Random -> RandomC.Random;
  
  components HplCC2420PinsC as Pins;
  MeasureMultiChRSSIP.CSN -> Pins.CSN;
  
  components new CC2420SpiC() as Spi;
  MeasureMultiChRSSIP.SpiResource -> Spi;
  MeasureMultiChRSSIP.SNOP        -> Spi.SNOP;
  MeasureMultiChRSSIP.STXON       -> Spi.STXON;
  MeasureMultiChRSSIP.STXONCCA    -> Spi.STXONCCA;
  MeasureMultiChRSSIP.SFLUSHTX    -> Spi.SFLUSHTX;
  MeasureMultiChRSSIP.TXCTRL      -> Spi.TXCTRL;
  MeasureMultiChRSSIP.MDMCTRL1    -> Spi.MDMCTRL1;
  MeasureMultiChRSSIP.FSCTRL 	  -> Spi.FSCTRL;

  MeasureMultiChRSSIP.SRXON -> Spi.SRXON;	
  MeasureMultiChRSSIP.SRFOFF -> Spi.SRFOFF;
  
  
  components UserButtonC;
  MeasureMultiChRSSIP.Get -> UserButtonC;
  MeasureMultiChRSSIP.Notify -> UserButtonC;

  
}
