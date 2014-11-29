module HelloWorldC {
  uses interface Boot;
  uses interface Leds;
}

implementation {
  event void Boot.booted() {
    call Leds.led0On();
  }
}

