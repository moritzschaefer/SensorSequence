#define NEW_PRINTF_SEMANTICS
#include "printf.h"
configuration NodeSelectionAppC {}
implementation {
  // Main Component
  components NodeSelectionC;


  components PrintfC;
  components SerialStartC;

  components MainC;
  NodeSelectionC.Boot -> MainC;

  components ActiveMessageC;
  NodeSelectionC.RadioControl -> ActiveMessageC;

  components DisseminationC;
  NodeSelectionC.DisseminationControl -> DisseminationC;

  components new DisseminatorC(uint16_t, 0x0000) as Diss16C;
  NodeSelectionC.Value -> Diss16C;
  NodeSelectionC.Update -> Diss16C;

  components LedsC;
  NodeSelectionC.Leds -> LedsC;

  components new TimerMilliC();
  NodeSelectionC.Timer -> TimerMilliC;

  // ctp part
  components CollectionC as Collector;
  components new CollectionSenderC(0x00);

  NodeSelectionC.RoutingControl -> Collector;
  NodeSelectionC.Send -> CollectionSenderC;
  NodeSelectionC.RootControl -> Collector;
  NodeSelectionC.Receive -> Collector.Receive[0x00];
}
