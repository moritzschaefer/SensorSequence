
module NodeDiscoveryC {
  uses interface Boot;
  uses interface SplitControl as RadioControl;
  uses interface StdControl as DisseminationControl;
  uses interface DisseminationValue<uint16_t> as Value;
  uses interface DisseminationUpdate<uint16_t> as Update;
  uses interface Leds;
  // CTP
  uses interface StdControl as RoutingControl;
  uses interface Send;
  uses interface RootControl;
  uses interface Receive;
}

implementation {
  // Used for CTP
  message_t packet;
  bool sendBusy = FALSE;

  typedef nx_struct NodeIDMsg {
    nx_uint16_t data;
  } NodeIDMsg;

  // debugging as long as there is no printf
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
      // start disseminate and ctp
      call DisseminationControl.start();
      call RoutingControl.start();

      if ( TOS_NODE_ID  == 1 ) {
        uint16_t tmpValue=0;
        call Update.change(&tmpValue);
        call RootControl.setRoot();
        post ShowCounter();

      }
    }
  }

  event void RadioControl.stopDone(error_t err) {}

  void sendMessage() {
    NodeIDMsg* msg =
      (NodeIDMsg*)call Send.getPayload(&packet, sizeof(NodeIDMsg));
    msg->data = TOS_NODE_ID;

    if (call Send.send(&packet, sizeof(NodeIDMsg)) != SUCCESS) {
      //printf this
    } else {
      sendBusy = TRUE;
    }
  }

  // Dissemination receive
  event void Value.changed() {
    const uint16_t* newVal = call Value.get();
    if(*newVal == 0) {
      // react with sending own ID here
      post ShowCounter();
    }
  }

  event void Send.sendDone(message_t* m, error_t err) {
    if(err != SUCCESS) {
      //printf
    } else {
      sendBusy = FALSE;
    }
  }

  // CTP receive
  event message_t* Receive.receive(message_t* msg, void* payload, uint8_t len) {
    // printf the received node id
    return msg;
  }
}
