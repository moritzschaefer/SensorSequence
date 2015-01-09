#define NEW_PRINTF_SEMANTICS
#include "printf.h"
//#include "utils.h"
#include <Timer.h>
#include "dataTypes.h"
//#include "constants.h"
#include "MeasurementData.h"

#define DEBUG 1

// number of measurements per channel and node
#define NUM_MEASUREMENTS 3


// TODO: make this dynamic!
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
  // Radio
  uses interface Packet;
  uses interface AMPacket;
  uses interface AMSend;
  uses interface Receive as AMReceive;
  uses interface CC2420Packet;

  // Serial Transmission
  uses interface Receive as SerialAMReceive;
  uses interface Packet as SerialAMPacket;
  uses interface AMSend as SerialAMSend;
  uses interface SplitControl as SerialAMControl;
}


implementation {
  enum states{ // TODO: no need to asign integers. we don't care about the actual values
    NODE_DETECTION_STATE = 0,
    SENDER_SELECTION_STATE = 1,
    PRINTING_STATE = 2,
    IDLE_STATE = 3,
    WAITING_STATE = 5,
    DATA_COLLECTION_STATE = 4

  };

  enum commands{
    ID_REQUEST = 0, //no uint16_t anymore, it's a problem? # TODO "it's" -> "is it".
    SENDER_ASSIGN = 1
  };

  // init Array
  // TODO: later we have to make this flexible!
  uint16_t nodeIds[MAX_NODE_COUNT];
  measurement measurements[MAX_NODE_COUNT];

  // function declarations
  void addNodeIdToArray(uint16_t);
  void printNodesArray();
  void debugMessage(const char *);
  void printMeasurementArray();
  bool sendMeasurementPacket();
  void statemachine();  

  // counter/array counter
  int nodeCount=0;
  int measurementCount=0;
  int measurementsTransmitted=0;
  int senderIterator=0;
  int currentSender=-1;

  // Statemachine
  int state = NODE_DETECTION_STATE;

  // TODO: should we use only one sendBusy field for CTP/Serial/...? maybe they intefere..
  // Used for CTP
  message_t ctp_packet, am_packet;
  bool sendBusy = FALSE;

  // Serial Transmission
  bool serialSend(uint16_t nodeId, uint16_t rssValue);
  bool serialSendBusy = FALSE;
  message_t serial_packet;



  // Dissemination ControlMsg instantiation # TODO: man spricht in C nicht wirklich von instanzen AFAIK. Es ist eher eine Deklaration
  struct ControlData controlMsg;


  task void ShowCounter() {
    call Leds.led1On();
  }

  event void Boot.booted() {
    call RadioControl.start();
    call SerialAMControl.start();
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
    statemachine();
  }

  // TODO: this function has to become a "task".

  void statemachine(){
    switch(state){
      //Node detection State
      case(NODE_DETECTION_STATE):
        debugMessage("Send DISCOVER to all nodes\n");
        controlMsg.dissCommand = ID_REQUEST;
        controlMsg.dissValue = 0;
        call Update.change((ControlData*)(&controlMsg));
        printf("dissCommand = %d\ndissValue = %d\n", controlMsg.dissCommand, controlMsg.dissValue);
        printfflush();
        state = WAITING_STATE;
        break;
        //Node selection State
      case WAITING_STATE:  //TODO this is hacky. delete later!
        debugMessage("Found nodes:\n");
        printNodesArray();
        state = SENDER_SELECTION_STATE;
        break;
      case SENDER_SELECTION_STATE:
        // change controlMsg
        controlMsg.dissCommand = SENDER_ASSIGN;
        controlMsg.dissValue = nodeIds[senderIterator];
        call Update.change((ControlData*)(&controlMsg)); //canged "nodeIds+senderIterator" to "ctrMsg.DissValue"
        printf("Send SENDER_ASSIGN to %u\n", nodeIds[senderIterator]);
        printfflush();
        senderIterator++;
        if (senderIterator >= nodeCount) {
          state = DATA_COLLECTION_STATE;
        }
        break;
      case DATA_COLLECTION_STATE: //TODO
	
	state = PRINTING_STATE;
	break;
        // go to DATA_COLLECTION_STATE between each assigned sender
      case PRINTING_STATE:
        // measurements done. go on
        serialSend(measurements[measurementsTransmitted].nodeId, measurements[measurementsTransmitted].measuredRss);
        measurementsTransmitted += 1;
        if(measurementsTransmitted >= measurementCount) {
          state = IDLE_STATE;
          measurementsTransmitted = 0;
        }
        break;
    }
  }


  event void RadioControl.stopDone(error_t err) {}

  // CTP receive
  event message_t* CTPReceive.receive(message_t* msg, void* payload, uint8_t len) {
    NodeIDMsg* received =
      (NodeIDMsg*)payload;
    if(len != sizeof(NodeIDMsg)) {
      debugMessage("Received CTP length doesn't match expected one.\n");
    } else {
      switch(state) {
        case NODE_DETECTION_STATE:
          addNodeIdToArray(received->nodeId);
          break;
        case DATA_COLLECTION_STATE: // TODO: SENDER_SELECTION_STATE is the wrong name as well... we need more states anyways.
          // directly forward to serial
          serialSend(received->nodeId, received->rss); // TODO: use BaseStation to automatically forward packets to serial
      }
    }
    return msg;
  }

  void sendCTPMeasurementData() { // TODO do you need parameters maybe?
    // TODO: use code as in sendCTPNodeId, just add msg->rss value and you are good to go
    NodeIDMsg* msg =
      (NodeIDMsg*)call CTPSend.getPayload(&ctp_packet, sizeof(NodeIDMsg));
    msg->rss = TOS_NODE_ID;

    if (call CTPSend.send(&ctp_packet, sizeof(NodeIDMsg)) != SUCCESS) {
      debugMessage("Error sending NodeID via CTP\n");
    } else {
      sendBusy = TRUE;
    }
  }

  void sendCTPNodeId() {
    NodeIDMsg* msg =
      (NodeIDMsg*)call CTPSend.getPayload(&ctp_packet, sizeof(NodeIDMsg));
    msg->nodeId = TOS_NODE_ID;

    if (call CTPSend.send(&ctp_packet, sizeof(NodeIDMsg)) != SUCCESS) {
      debugMessage("Error sending NodeID via CTP\n");
    } else {
      sendBusy = TRUE;
    }
  }

  event void Value.changed() {
    const ControlData* newVal = call Value.get();
    switch(newVal->dissCommand) {
      case ID_REQUEST:
        sendCTPNodeId();
        break;
      case SENDER_ASSIGN:
        currentSender = newVal->dissCommand; // wrong?
        if(newVal->dissValue == TOS_NODE_ID) {
          post ShowCounter();
          while(!sendMeasurementPacket());
          break;
        }
    }
  }

  event void CTPSend.sendDone(message_t* m, error_t err) {
    if(err != SUCCESS) {
      debugMessage("Error sending NodeID via CTP\n");
    } else {
      debugMessage("Sent CTP value\n");
      sendBusy = FALSE;
    }
  }

  // AM send
  bool sendMeasurementPacket() {
    if (!sendBusy) {
      RSSMeasurementMsg* rss_msg = (RSSMeasurementMsg*)(call Packet.getPayload(&am_packet, sizeof(RSSMeasurementMsg)));
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
      debugMessage("Error sending AM packet");
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
        debugMessage("too many measurements for our array");
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
  // Serial data transfer
  bool serialSend(uint16_t nodeId, uint16_t rssValue) {
    // TODO: refactor: either delete debugMessages or improve their meanings (better)
    if (serialSendBusy) {
      debugMessage("failed1\n");
      return FALSE;
    }
    else {
      measurement_data_t *rcm = (measurement_data_t*)call SerialAMPacket.getPayload(&serial_packet, sizeof(measurement_data_t));
      if (rcm == NULL) {debugMessage("failed2\n"); return FALSE;}

      rcm->nodeId = nodeId;
      rcm->rss = rssValue;

      if (call SerialAMPacket.maxPayloadLength() < sizeof(measurement_data_t)) {
        debugMessage("failed3\n");
        return FALSE;
      }

      if (call SerialAMSend.send(AM_BROADCAST_ADDR, &serial_packet, sizeof(measurement_data_t)) == SUCCESS) {
        serialSendBusy = TRUE;
      } else {
        printf("failed4\n"); printfflush();
        return FALSE;
      }
    }
    return TRUE;

  }
  event void SerialAMSend.sendDone(message_t* bufPtr, error_t error) {
    if (&serial_packet == bufPtr) {
      serialSendBusy = FALSE;
      debugMessage("successfully sent\n");
    }
  }

  event void SerialAMControl.startDone(error_t err) {
    debugMessage("successfully started serial control\n");
  }
  event void SerialAMControl.stopDone(error_t err) {
    // do nothing
  }
  event message_t* SerialAMReceive.receive(message_t* bufPtr,
      void* payload, uint8_t len) {
    debugMessage("received serial data. why..? should not happen.");
  }
  void debugMessage(const char *msg) {
#if DEBUG
    if(serialSendBusy) {
      return;
    } else {
      printf(msg);
      printfflush();
    }
#endif
  }

}
