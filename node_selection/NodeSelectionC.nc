#define NEW_PRINTF_SEMANTICS
#include "printf.h"
#include <Timer.h>
#include "dataTypes.h"

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
  uses interface DisseminationValue<ControlData> as Value;
  uses interface DisseminationUpdate<ControlData> as Update;
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
  enum {
    NODE_DETECTION_STATE = 0,
    SENDER_SELECTION_STATE = 1,
    PRINTING_STATE = 2,
    BUSY_STATE = 3,
    WAITING_STATE = 5
  };

  enum {
    ID_REQUEST = 0,
    MEASUREMENT_REQUEST = 1
  };

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
  int state = NODE_DETECTION_STATE;

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
    //testing struct
    ControlData c;
    c.dissCommand = 0;
    c.dissValue = 0;
    printfflush();
    switch(state){
      //Node detection State
      case(NODE_DETECTION_STATE):
        //printf("---State NR. %d---\n", state);
        printf("Send DISCOVER to all nodes\n");
        printfflush();
        call Update.change(&NODE_DISCOVERY); // hier fehlt mir information, wie mache ich klar, dass ich ein ControlData übergeben will, casten?
	printf("diss Command = %d\ndissValue = %d\n", c.dissCommand, c.dissValue);
	printfflush();
        state = WAITING_STATE;
        break;
        //Node selection State
      case WAITING_STATE:  //TODO this is hacky. delete later!
        printf("Found nodes:\n");
        printNodesArray();
        state = SENDER_SELECTION_STATE;
        break;
      case SENDER_SELECTION_STATE:
        //printf("---State NR. %d---\n", state);
        // select sender
        call Update.change((ControlData*)(nodeIds+senderIterator)); // wie übergebe ich die Information des DissCommand?
        printf("Send SELECT_SENDER to %u\n", nodeIds[senderIterator]);
        printfflush();
        senderIterator++;
        if (senderIterator >= nodeCount) {
          state = PRINTING_STATE;
        }
        break;
      case PRINTING_STATE:
        // measurements done. go on
        printMeasurementArray();
        state = BUSY_STATE;

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

  // Disseminations
  event void Value.changed() {			 
    if(Value.DissKey == ID_REQUEST){		 //switch-case more pretty than if-if?
      const uint16_t* newVal = call Data.DissValue.get();
      if(*newVal == NODE_DISCOVERY) { 	         //is this after struct using essential? && *newVal is a Pointer to our data struct. 
      	sendCTPMessage();
      	//post ShowCounter();
      }
      /*if(*newVal == SELECT_SENDER) {
      rintf("recived Dissemination");
      printfflush();
      }*/
    }
    if(Value.DissKey == MEASUREMENT_REQUEST){
      currentSender = *newVal;
      if(*newVal == TOS_NODE_ID) {
        post ShowCounter();
        // Wait 10ms and send radio
        //call Busy.wait(10);
        // TODO send am here
      while(!sendAMMessage());
      }
    }
  }

  /*// Dissemination receive II
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
  }*/

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
      measurements[measurementCount].measuredRss = (int)getRssi(msg);
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
    //printf("array[%d] = %u\n", i, nodeIds[nodeCount]);
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
