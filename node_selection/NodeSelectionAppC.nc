#define NEW_PRINTF_SEMANTICS
#include "printf.h"
#include "dataTypes.h"
#include "MeasurementData.h"

configuration NodeSelectionAppC {}
implementation {
  // Main Component
  components NodeSelectionC;

  //Printf
  components PrintfC;
  components SerialStartC;

  components MainC;
  NodeSelectionC.Boot -> MainC;
  components ActiveMessageC;
  NodeSelectionC.RadioControl -> ActiveMessageC;


  components DisseminationC;
  NodeSelectionC.DisseminationControl -> DisseminationC;

  components new DisseminatorC(ControlData, 0x0000) as Diss16C;
  NodeSelectionC.Value -> Diss16C;
  NodeSelectionC.Update -> Diss16C;
  /*---The old disseminate Interface---
  components new DisseminatorC(uint16_t, 0x0001) as Diss16C2;
  NodeSelectionC.Value2 -> Diss16C2;
  NodeSelectionC.Update2 -> Diss16C2;*/

  components LedsC;
  NodeSelectionC.Leds -> LedsC;

  //components new TimerMilliC();
  //NodeSelectionC.Timer -> TimerMilliC; not used

  // CTP Part
  components CollectionC as Collector;
  components new CollectionSenderC(0x00);

  NodeSelectionC.RoutingControl -> Collector;
  NodeSelectionC.CTPSend -> CollectionSenderC;
  NodeSelectionC.RootControl -> Collector;
  NodeSelectionC.CTPReceive -> Collector.Receive[0x00];

  // Radio Send/Receive
  components CC2420ActiveMessageC;
  NodeSelectionC.CC2420Packet -> CC2420ActiveMessageC.CC2420Packet;

  NodeSelectionC.Packet -> AMSenderC;
  NodeSelectionC.AMPacket -> AMSenderC;
  //NodeSelectionC.AMControl -> ActiveMessageC; // already done
  NodeSelectionC.AMSend -> AMSenderC;
  NodeSelectionC.AMReceive -> AMReceiverC;

  components new AMSenderC(6);
  components new AMReceiverC(6);

  // Serial Data Transfer
  components SerialActiveMessageC as SerialAM;
  NodeSelectionC.SerialAMControl -> SerialAM;
  NodeSelectionC.SerialAMReceive -> SerialAM.Receive[AM_MEASUREMENT_DATA];
  NodeSelectionC.SerialAMSend -> SerialAM.AMSend[AM_MEASUREMENT_DATA];
  NodeSelectionC.SerialAMPacket -> SerialAM;
}
