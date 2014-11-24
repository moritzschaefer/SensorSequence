#define NEW_PRINTF_SEMANTICS
#include "printf.h"
#include <Timer.h>
module NodeDiscoveryC {
  uses interface Boot;
  uses interface SplitControl as RadioControl;
  uses interface StdControl as DisseminationControl;
  uses interface DisseminationValue<uint16_t> as Value;
  uses interface DisseminationUpdate<uint16_t> as Update;
  uses interface Leds;
  uses interface Timer<TMilli>;
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
  uint16_t NODE_DISCOVERY=0;

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
        call RootControl.setRoot();
        post ShowCounter();
        call Timer.startPeriodic(2000);

      }
    }
  }

  event void Timer.fired() {
    printfflush();
    call Update.change(&NODE_DISCOVERY);
  }


  event void RadioControl.stopDone(error_t err) {}

  void sendMessage() {
    NodeIDMsg* msg =
      (NodeIDMsg*)call Send.getPayload(&packet, sizeof(NodeIDMsg));
    msg->data = TOS_NODE_ID;

    if (call Send.send(&packet, sizeof(NodeIDMsg)) != SUCCESS) {
      printf("Error sending NodeID via CTP\n");
    } else {
      sendBusy = TRUE;
    }
  }

  // Dissemination receive
  event void Value.changed() {
    const uint16_t* newVal = call Value.get();
    if(*newVal == 0) {
      sendMessage();
      post ShowCounter();
    }
  }

  event void Send.sendDone(message_t* m, error_t err) {
    if(err != SUCCESS) {
      printf("Error sending NodeID via CTP\n");
    } else {
      printf("Sent CTP value\n");
      sendBusy = FALSE;
    }
  }

  // CTP receive
  event message_t* Receive.receive(message_t* msg, void* payload, uint8_t len) {
    //notice that byte order in payload is swapped
    printf("Received node ID %u. len: %u\n", *((short int*)payload), len);
    return msg;
  }
}
