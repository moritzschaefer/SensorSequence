#include <Timer.h>
#include "BlinkToRadio.h"

configuration BlinkToRadioAppC {
}
implementation {
   components MainC;
   components LedsC;
   components BlinkToRadioC as App;
   components new TimerMilliC() as Timer0;

   App.Boot -> MainC;
   App.Leds -> LedsC;
   App.Timer0 -> Timer0;
}
