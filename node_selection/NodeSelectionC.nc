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
  enum states { // TODO: no need to asign integers. we don't care about the actual values
    NODE_DETECTION_STATE = 0,
    SENDER_SELECTION_STATE = 1,
    PRINTING_STATE = 2,
    IDLE_STATE = 3,
    WAITING_STATE = 5,
    MEASUREMENT_TABLE_REQUEST,
    DATA_COLLECTION_STATE

  };

  enum commands{
    ID_REQUEST = 0,
    SENDER_ASSIGN = 1,
    MEASUREMENT_REQUEST
  };

  // init Array
  uint16_t *nodeIds=NULL;
  measurement measurements[MAX_NODE_COUNT]; // TODO: use NUM_MEASUREMENTS*NUM_CHANNELS

  // function declarations
  void addNodeIdToArray(uint16_t);
  void printNodesArray();
  void debugMessage(const char *);
  void printMeasurementArray();
  bool sendMeasurementPacket();
  void sendCTPMeasurementData(measurement);
  task void statemachine();

  // counter/array counter
  int nodeCount=0;
  int measurementCount=0;
  int measurementsTransmitted=0;
  int senderIterator=0;

  // Statemachine
  int state = NODE_DETECTION_STATE;

  // TODO: should we use only one sendBusy field for CTP/Serial/...? maybe they intefere..
  // Used for CTP
  message_t ctp_discover_packet, ctp_collection_packet, am_packet;
  bool sendBusy = FALSE;

  // Serial Transmission
  bool serialSend(uint16_t senderNodeId, uint16_t receiverNodeId, uint16_t rssValue);
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
        post statemachine();
        //call Timer.startPeriodic(2000); //delete
      }
    }
  }

  event void Timer.fired() {
    post statemachine();
  }

  // TODO: this function has to become a "task".

  task void statemachine(){ //task
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
        call Timer.startOneShot(200);
        break;
        //Node selection State
      case WAITING_STATE:  //TODO merge with sender_selection_state
        debugMessage("Found nodes:\n");
        printNodesArray();
        state = SENDER_SELECTION_STATE;

        call Timer.startOneShot(500);
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
          senderIterator = 0;
          state = MEASUREMENT_TABLE_REQUEST;
        }
        call Timer.startOneShot(200);
        break;
        // go to DATA_COLLECTION_STATE between each assigned sender
      case MEASUREMENT_TABLE_REQUEST: //get from sender detection state
        controlMsg.dissCommand = MEASUREMENT_REQUEST; //MEASUREMENT_TABLE_REQUEST
        controlMsg.dissValue = nodeIds[senderIterator];
        call Update.change((ControlData*)(&controlMsg));
        printf("Send MEASUREMENT_REQUEST to %u\n", nodeIds[senderIterator]);
        printfflush();
        senderIterator++;
        if (senderIterator >= nodeCount) {
          state = IDLE_STATE;
        }
	// continued through sendDone post
        break;
      // we don't use you anymore (right now)
      case PRINTING_STATE:
        // measurements done. go on
        serialSend(measurements[measurementsTransmitted].nodeId, TOS_NODE_ID, measurements[measurementsTransmitted].measuredRss);
        measurementsTransmitted += 1;
        if(measurementsTransmitted >= measurementCount) {
          state = IDLE_STATE;
          measurementsTransmitted = 0;
        }
        break;
    }
  }

  event void RadioControl.stopDone(error_t err) {}

  void sendCTPMeasurementData(measurement m) {
    CollectionDataMsg *msg;

    if(sendBusy) {
      debugMessage("Call to sendCTPMeasurementData while sendBusy is true\n");
      return;
    }
    msg =
      (CollectionDataMsg*)call CTPSend.getPayload(&ctp_collection_packet, sizeof(CollectionDataMsg));
    msg->senderNodeId = m.nodeId;
    msg->receiverNodeId = TOS_NODE_ID; // This node received the measurement
    msg->rss = m.measuredRss;

    if (call CTPSend.send(&ctp_collection_packet, sizeof(CollectionDataMsg)) != SUCCESS) {
      debugMessage("Error sending NodeID via CTP\n");
    } else {
      sendBusy = TRUE;
    }
  }

  void sendCTPNodeId() {
    NodeIDMsg* msg;

    if(sendBusy) {
      debugMessage("Call to sendCTPNodeId while sendBusy is true\n");
      return;
    }
    msg =
      (NodeIDMsg*)call CTPSend.getPayload(&ctp_discover_packet, sizeof(NodeIDMsg));
    msg->nodeId = TOS_NODE_ID;

    if (call CTPSend.send(&ctp_discover_packet, sizeof(NodeIDMsg)) != SUCCESS) {
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
        if(newVal->dissValue == TOS_NODE_ID) {
          post ShowCounter();
          while(!sendMeasurementPacket());
        }
        break;
      case MEASUREMENT_REQUEST:
        if(newVal->dissValue != 0 && TOS_NODE_ID == newVal->dissValue)
          sendCTPMeasurementData(measurements[0]);
      break;
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

  // CTP receive
  event message_t* CTPReceive.receive(message_t* msg, void* payload, uint8_t len) {
    // do action dependent on packet type (= size)
    NodeIDMsg *receivedNodeId;
    CollectionDataMsg *receivedCollectionData;
    switch(len) {
      case sizeof(NodeIDMsg):
        receivedNodeId = (NodeIDMsg*)payload;
        addNodeIdToArray(receivedNodeId->nodeId);
        break;
      case sizeof(CollectionDataMsg):
        receivedCollectionData = (CollectionDataMsg*)payload;
        serialSend(receivedCollectionData->senderNodeId, receivedCollectionData->receiverNodeId, receivedCollectionData->rss); // TODO: use BaseStation to automatically forward packets to serial
        break;

      default:
        debugMessage("Received CTP length doesn't match expected one.\n");
    }
    return msg;
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

    // first check if the node is already in the array
    int i;
    for(i = 0; i<nodeCount; i++)
    {
      if(nodeIds[i] == nodeId) {
        //printf("array[%d] = %u\n", i, nodeIds[i]);
        //printfflush();
        return;
      }
    }

    // resize the array
    if(nodeCount == 0) {
      nodeIds = malloc(sizeof(uint16_t));
    } else {
      uint16_t *nodeIds_new = malloc(sizeof(uint16_t) * (nodeCount+1));
      //realloc
      memcpy(nodeIds_new, nodeIds, sizeof(uint16_t) * (nodeCount));
      free(nodeIds);
      nodeIds = nodeIds_new;
    }

    nodeIds[nodeCount] = nodeId;
    // add the element
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
  bool serialSend(uint16_t senderNodeId, uint16_t receiverNodeId, uint16_t rssValue) {
    // TODO: refactor: either delete debugMessages or improve their meanings (better)
    if (serialSendBusy) {
      debugMessage("failed1\n");
      return FALSE;
    }
    else {
      measurement_data_t *rcm = (measurement_data_t*)call SerialAMPacket.getPayload(&serial_packet, sizeof(measurement_data_t));
      if (rcm == NULL) {debugMessage("failed2\n"); return FALSE;}

      rcm->senderNodeId = senderNodeId;
      rcm->receiverNodeId = receiverNodeId;
      rcm->rss = rssValue;

      if (call SerialAMPacket.maxPayloadLength() < sizeof(measurement_data_t)) {
        debugMessage("failed3\n");
        return FALSE;
      }

      if (call SerialAMSend.send(AM_BROADCAST_ADDR, &serial_packet, sizeof(measurement_data_t)) == SUCCESS) {
        serialSendBusy = TRUE;
      } else {
        printf("Serial send is busy. can't send\n"); printfflush();
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
    post statemachine();
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
    return bufPtr;
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
