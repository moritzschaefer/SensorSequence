#include <Timer.h>
#include "BlinkToRadio.h"

#ifndef BLINKTORADIO_H
#define BLINKTORADIO_H

enum {
  TIMER_PERIOD_MILLI = 250
};

#endif

module BlinkToRadioC {
  uses interface Boot;
  uses interface Leds;
  uses interface Timer<TMilli> as Timer0;
}
implementation {
  uint16_t counter = 0;

  event void Boot.booted() {
    call Timer0.startPeriodic(TIMER_PERIOD_MILLI);
  }

  event void Timer0.fired() {
    counter++;
    call Leds.set(counter);
  }
}
