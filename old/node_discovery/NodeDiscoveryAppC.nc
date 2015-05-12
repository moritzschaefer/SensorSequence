#define NEW_PRINTF_SEMANTICS
#include "printf.h"
configuration NodeDiscoveryAppC {}
implementation {
  // Main Component
  components NodeDiscoveryC;


  components PrintfC;
  components SerialStartC;

  components MainC;
  NodeDiscoveryC.Boot -> MainC;

  components ActiveMessageC;
  NodeDiscoveryC.RadioControl -> ActiveMessageC;

  components DisseminationC;
  NodeDiscoveryC.DisseminationControl -> DisseminationC;

  components new DisseminatorC(uint16_t, 0x0000) as Diss16C;
  NodeDiscoveryC.Value -> Diss16C;
  NodeDiscoveryC.Update -> Diss16C;

  components LedsC;
  NodeDiscoveryC.Leds -> LedsC;

  components new TimerMilliC();
  NodeDiscoveryC.Timer -> TimerMilliC;

  // ctp part
  components CollectionC as Collector;
  components new CollectionSenderC(0x00);

  NodeDiscoveryC.RoutingControl -> Collector;
  NodeDiscoveryC.Send -> CollectionSenderC;
  NodeDiscoveryC.RootControl -> Collector;
  NodeDiscoveryC.Receive -> Collector.Receive[0x00];
}
