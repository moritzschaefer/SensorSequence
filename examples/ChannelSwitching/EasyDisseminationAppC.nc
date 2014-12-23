
#define NEW_PRINTF_SEMANTICS
#include "printf.h"

configuration EasyDisseminationAppC {}
implementation {
  components EasyDisseminationC;

  components MainC;
  EasyDisseminationC.Boot -> MainC;

  components ActiveMessageC;
  EasyDisseminationC.RadioControl -> ActiveMessageC;

  components DisseminationC;
  EasyDisseminationC.DisseminationControl -> DisseminationC;

  components new DisseminatorC(uint16_t, 0x1234) as Diss16C;
  EasyDisseminationC.Value -> Diss16C;
  EasyDisseminationC.Update -> Diss16C;
/*components new DisseminatorC(uint32_t, 0x1234) as Object32C;
  TestDisseminationC.Value32 -> Object32C;
  TestDisseminationC.Update32 -> Object32C;*/

  components LedsC;
  EasyDisseminationC.Leds -> LedsC;

  components new TimerMilliC();
  EasyDisseminationC.Timer -> TimerMilliC;

  components new TimerMilliC() as ChannelSwitchTimer;
  EasyDisseminationC.ChannelSwitchTimer -> ChannelSwitchTimer;


  // debug

  components PrintfC, SerialStartC;

// channel switching stuff

  components HplCC2420PinsC as Pins;
  EasyDisseminationC.CSN -> Pins.CSN;

  components new CC2420SpiC() as Spi;
  EasyDisseminationC.SpiResource -> Spi;
  EasyDisseminationC.SNOP        -> Spi.SNOP;
  EasyDisseminationC.STXON       -> Spi.STXON;
  EasyDisseminationC.STXONCCA    -> Spi.STXONCCA;
  EasyDisseminationC.SFLUSHTX    -> Spi.SFLUSHTX;
  EasyDisseminationC.TXCTRL      -> Spi.TXCTRL;
  EasyDisseminationC.MDMCTRL1    -> Spi.MDMCTRL1;
  EasyDisseminationC.FSCTRL 	  -> Spi.FSCTRL;

  EasyDisseminationC.SRXON -> Spi.SRXON;
  EasyDisseminationC.SRFOFF -> Spi.SRFOFF;
}
