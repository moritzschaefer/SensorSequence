#define NEW_PRINTF_SEMANTICS
#include "printf.h"
#include <Timer.h>
typedef nx_struct RSSMeasurementMsg {
  nx_uint16_t nodeId;
} RSSMeasurementMsg;

#define MAX_NODE_COUNT 10
typedef struct {
  uint16_t nodeId;
  uint16_t measuredRss;
} measurement;

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
  uses interface Send as CTPSend;
  uses interface RootControl;
  uses interface Receive as CTPReceive;
  //Radio
  uses interface Packet;
  uses interface AMPacket;
  uses interface AMSend;
  uses interface Receive as AMReceive;
  uses interface CC2420Packet;
}


implementation {
  // init Array
  //const int ARRAYLENGTH = MAX_NODE_COUNT;
  uint16_t nodeIds[MAX_NODE_COUNT];
  measurement measurements[MAX_NODE_COUNT];

  // function declarations
  void addNodeIdToArray(uint16_t);
  void printNodesArray();
  void printMeasurementArray();
  bool sendAMMessage();


  // counter/array counter
  int nodeCount=0;
  int measurementCount=0;
  int senderIterator=0;
  int currentSender=-1;

  //Statemachine
  int state = 0;

  // Used for CTP
  message_t ctp_packet, am_packet;
  bool sendBusy = FALSE;

  const uint16_t NODE_DISCOVERY=0;
  const uint16_t SELECT_SENDER=1; // TODO use this later

  typedef nx_struct NodeIDMsg {
    nx_uint16_t data;
  } NodeIDMsg;

  // debugging as long as there is no printf
  task void ShowCounter() {
    call Leds.led1On();

    //printf("ShowCounter\n");
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
        //printf("---State NR. %d---\n", state);
        printf("Send DISCOVER to all nodes\n");
        call Update1.change(&NODE_DISCOVERY);
        state=5;
        break;
        //Node selection State
      case 5:  //TODO this is hacky. delete later!
        printf("Found nodes:\n");
        printNodesArray();
        state = 1;
        break;
      case 1:
        //printf("---State NR. %d---\n", state);
        // select sender
        call Update2.change((uint16_t*)(nodeIds+senderIterator));
        printf("Send SELECT_SENDER to %u\n", nodeIds[senderIterator]);
        senderIterator++;
        if (senderIterator >= nodeCount) {
          state = 2;
        }
        break;
      case 2:
        // measurements done. go on
        printMeasurementArray();
        state = 3;

    }
  }


  event void RadioControl.stopDone(error_t err) {}

  void sendCTPMessage() {
    NodeIDMsg* msg =
      (NodeIDMsg*)call CTPSend.getPayload(&ctp_packet, sizeof(NodeIDMsg));
    msg->data = TOS_NODE_ID;

    if (call CTPSend.send(&ctp_packet, sizeof(NodeIDMsg)) != SUCCESS) {
      printf("Error sending NodeID via CTP\n");
    } else {
      sendBusy = TRUE;
    }
  }

  // Dissemination receive I
  event void Value1.changed() {
    const uint16_t* newVal = call Value1.get();
    if(*newVal == NODE_DISCOVERY) {
      sendCTPMessage();
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
      //call Busy.wait(10);
      // TODO send am here
      while(!sendAMMessage());

    }
  }

  event void CTPSend.sendDone(message_t* m, error_t err) {
    if(err != SUCCESS) {
      printf("Error sending NodeID via CTP\n");
    } else {
      //printf("Sent CTP value\n");
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
      //printf("Received node ID %u\n", received->data);
      addNodeIdToArray(received->data);
      //printf("added in array...\n");
    }
    return msg;
  }

  // AM send
  bool sendAMMessage() { // TODO rename this function to something like sendMeasurementPacket
    if (!sendBusy) {
      RSSMeasurementMsg* rss_msg =	(RSSMeasurementMsg*)(call Packet.getPayload(&am_packet, sizeof(RSSMeasurementMsg)));
      if (rss_msg == NULL) {
        return FALSE;
      }
      rss_msg->nodeId = TOS_NODE_ID;
      if (call AMSend.send(AM_BROADCAST_ADDR, &am_packet, sizeof(RSSMeasurementMsg)) == SUCCESS) {
        //printf("message fired\n");
        //printfflush();
        sendBusy = TRUE;
        return TRUE;
      }
    }
    return FALSE;
  }

  event void AMSend.sendDone(message_t* msg, error_t err) {
    sendBusy = FALSE;
    //printf("success sending AM packet");
    if (err != SUCCESS) {
      printf("Error sending AM packet");
    }
  }
  //unnecessary helper
  uint16_t getRssi(message_t *msg){
    //printf("get RSSI\n");
    return (uint16_t) (call CC2420Packet.getRssi(msg))-45; // According to CC2420 datasheet[2], (RSSI / Energy Detection) it says there is -45 Rssi offset.
  }

  // AM receive
  event message_t* AMReceive.receive(message_t* msg, void* payload, uint8_t len){
    if (len == sizeof(RSSMeasurementMsg)) {
      RSSMeasurementMsg* rss_msg = (RSSMeasurementMsg*)payload;
      //setLeds(btrpkt->counter);
      //printf("measurement packet recived. sender node: %d, RSS:  %d\n", rss_msg->nodeId, (int)getRssi(msg));
      // Save RSSI to packet now
      if(measurementCount >= 10) {
        printf("too many measurements for our array");
        printfflush();
      }

      measurements[measurementCount].nodeId = rss_msg->nodeId;
      measurements[measurementCount].nodeId = (int)getRssi(msg);
      measurementCount++;
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

  void printMeasurementArray(){
    int k;
    for(k=0; k<measurementCount; k++)
    {
      printf("rss measurement nr. %d from node %d: %d\n", k, measurements[k].nodeId, measurements[k].measuredRss);
    }
    printfflush();
  }
  void printNodesArray(){
    int k;
    for(k=0; k<nodeCount; k++)
    {
      printf("nodes[%d] = %u\n", k, nodeIds[k]);
    }
    printfflush();
  }
}
