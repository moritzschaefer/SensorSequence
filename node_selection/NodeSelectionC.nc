#define NEW_PRINTF_SEMANTICS
#include "printf.h"
#include <Timer.h>
module NodeSelectionC {
  uses interface Boot;
  uses interface SplitControl as RadioControl;
  uses interface StdControl as DisseminationControl;
  uses interface DisseminationValue<uint16_t> as Value1;
  uses interface DisseminationValue<uint16_t> as Value2;
  uses interface DisseminationUpdate<uint16_t> as Update1;
  uses interface DisseminationUpdate<uint16_t> as Update2;
  uses interface Leds;
  uses interface Timer<TMilli>;
  // CTP
  uses interface StdControl as RoutingControl;
  uses interface CTPSend;
  uses interface RootControl;
  uses interface Receive as CTPReceive;
}


#define MAX_NODE_COUNT 10
typedef struct {
  uint16_t NodeId;
  uint16_t measuredRss;
} measurement;

implementation {
  // init Array
  //const int ARRAYLENGTH = MAX_NODE_COUNT;
  uint16_t nodeIds[MAX_NODE_COUNT];
  void addNodeIdToArray(uint16_t);
  void printArray();
  int nodeCount=0;
  int id=0;
  int currentSender=-1;

  //Statemachine
  int state = 0;

  // Used for CTP
  message_t packet;
  bool sendBusy = FALSE;

  const uint16_t NODE_DISCOVERY=0;
  const uint16_t SELECT_SENDER=1; // TODO use this later

  typedef nx_struct NodeIDMsg {
    nx_uint16_t data;
  } NodeIDMsg;

  // debugging as long as there is no printf
  task void ShowCounter() {
    call Leds.led1On();

    printf("ShowCounter\n");
    printfflush();
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

      if ( TOS_NODE_ID  == 0 ) {
        call RootControl.setRoot();
        post ShowCounter();
        call Timer.startPeriodic(2000);

      }
    }
  }

  event void Timer.fired() {
    printfflush();
    switch(state){
    //Node detection State
      case(0):
        printf("---State NR. %d---\n", state);
        printf("Discovery to all nodes\n");
        call Update1.change(&NODE_DISCOVERY);
        state=1;
        break;
    //Node selection State
        case 1:
        printf("---State NR. %d---\n", state);
        //SELECT_SENDER=nodeIds[i];
        call Update2.change((uint16_t*)(nodeIds+id));
        printf("Sende an Node %u\n", nodeIds[id]);
        id++;
        if (id >= nodeCount) {
          id = 0;
        }
        printArray();
        printfflush();
    }
  }


  event void RadioControl.stopDone(error_t err) {}

  void sendMessage() {
    NodeIDMsg* msg =
      (NodeIDMsg*)call CTPSend.getPayload(&packet, sizeof(NodeIDMsg));
    msg->data = TOS_NODE_ID;

    if (call CTPSend.send(&packet, sizeof(NodeIDMsg)) != SUCCESS) {
      printf("Error sending NodeID via CTP\n");
    } else {
      sendBusy = TRUE;
    }
  }

  // Dissemination receive I
  event void Value1.changed() {
    const uint16_t* newVal = call Value1.get();
    if(*newVal == NODE_DISCOVERY) {
      sendMessage();
      //post ShowCounter();
    }
    /*if(*newVal == SELECT_SENDER) {
      printf("recived Dissemination");
      printfflush();
    }*/
  }

  // Dissemination receive II
  event void Value2.changed() {
    const uint16_t *newVal = call Value2.get();
    currentSender = *newVal;
    if(*newVal == TOS_NODE_ID) {
      post ShowCounter();
      // Wait 10ms and send radio
			call Busy.wait(TOS_NODE_ID%PERIOD);
      // TODO send RSS here
    }
  }

  event void CTPSend.sendDone(message_t* m, error_t err) {
    if(err != SUCCESS) {
      printf("Error sending NodeID via CTP\n");
    } else {
      printf("Sent CTP value\n");
      sendBusy = FALSE;
    }
  }

  // CTP receive
  event message_t* CTPReceive.receive(message_t* msg, void* payload, uint8_t len) {
    NodeIDMsg* received =
      (NodeIDMsg*)payload;
    if(len != sizeof(NodeIDMsg)) {
      printf("Received CTP length doesn't match expected one.\n");
    } else {
      printf("Received node ID %u\n", received->data);
      addNodeIdToArray(received->data);
      printf("added in array...\n");
    }
    return msg;
  }

  // Writing each incomming id into the Array
  void addNodeIdToArray(uint16_t nodeId) {
    int i;
    for(i = 0; i<nodeCount; i++)
    {
      if(nodeIds[i] == nodeId) {
        //printf("array[%d] = %u\n", i, nodeIds[i]);
        //printfflush();
        return;
      }
    }
    nodeIds[nodeCount] = nodeId;
    printf("array[%d] = %u\n", i, nodeIds[nodeCount]);
    nodeCount++;
    return;
  }

  void printArray(){
    int k;
    for(k=0; k<nodeCount; k++)
    {
      printf("array[%d] = %u\n", k, nodeIds[k]);
    }
  }
}
