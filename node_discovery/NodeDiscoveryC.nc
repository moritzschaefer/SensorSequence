
module NodeDiscoveryC {
  uses interface Boot;
  uses interface SplitControl as RadioControl;
  uses interface StdControl as DisseminationControl;
  uses interface DisseminationValue<uint16_t> as Value;
  uses interface DisseminationUpdate<uint16_t> as Update;
  uses interface Leds;
}

implementation {
  task void ShowCounter() {
    call Leds.led0On();
    call Leds.led1On();
    call Leds.led2On();
  }

  event void Boot.booted() {
    call RadioControl.start();
  }

  event void RadioControl.startDone(error_t err) {
    if (err != SUCCESS)
      call RadioControl.start();
    else {
      call DisseminationControl.start();
      if ( TOS_NODE_ID  == 1 ) {
        uint16_t tmpValue=0;
        call Update.change(&tmpValue);
        post ShowCounter();

      }
    }
  }

  event void RadioControl.stopDone(error_t err) {}

  event void Value.changed() {
    const uint16_t* newVal = call Value.get();
    if(*newVal == 0) {
      // react with sending own ID here
      post ShowCounter();
    }
  }
}
