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
  // init Array
  uint16_t array_id[5];
  uint16_t array_test[5] = {0};
  void setArray(uint16_t);

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
    NodeIDMsg* received =
      (NodeIDMsg*)payload;
    if(len != sizeof(NodeIDMsg)) {
      printf("Received CTP length doesn't match expected one.\n");
    } else {
      printf("Received node ID %u\n", received->data);
      setArray(received->data);
    }
    return msg;
  }

  void setArray(uint16_t value) {
    // Writing each incomming id into the Array
    int i;
    printf("Der neue Wert ist eine %u\n", value);
    printf("FIELD----VALUE-----\n");
    //for( i = 0; i<5; i++ ){
    //  printf("array[%d] = %u\n", i, array_test[i]);}
    for( i = 0; i<5; i++ )
    {
      if (array_id[i] == value) {
      printf("array[%d] = %u\n", i, array_id[i]);
      return;
      }
      if (array_id[i] == 0) {
        array_id[i] = value;
        return;
      }
      printf("array[%d] = %u\n", i, array_id[i]);
    }
    printf("-------------------\n");
  }
}