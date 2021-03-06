#define NEW_PRINTF_SEMANTICS
//#include "utils.h"
#include <Timer.h>
#include "dataTypes.h"
#include "MeasurementData.h"
#include "SerialControl.h"

#include "printf.h"
// TODO: find better name to for CollectionDataMsg
// Green: I'm on START_CHANNEL
// Blue: I am sender

// Disable printfs
#ifndef DEBUG
#define DEBUG 0
#endif

#if DEBUG
#else
#define printf (void)sizeof
#endif

module NodeSelectionC {
  uses interface Boot;
  uses interface SplitControl as RadioControl;
  uses interface StdControl as DisseminationControl;
  uses interface DisseminationValue<ControlData> as Value;
  uses interface DisseminationUpdate<ControlData> as Update;
  uses interface Leds;
  uses interface Timer<TMilli>;
  uses interface Timer<TMilli> as ChannelTimer;
  uses interface Timer<TMilli> as ResetTimer;
  uses interface Timer<TMilli> as ReassignTimer; // we need to reassign sometimes because some channels sometimes don't receive their assignment #dissemination-bug
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

  // channel switching stuff
  uses interface GeneralIO as CSN;

  uses interface Resource as SpiResource;

  uses interface CC2420Ram as TXFIFO_RAM;
  uses interface CC2420Register as TXCTRL;
  uses interface CC2420Strobe as SNOP;
  uses interface CC2420Strobe as STXON;
  uses interface CC2420Strobe as STXONCCA;
  uses interface CC2420Strobe as SFLUSHTX;
  uses interface CC2420Register as MDMCTRL1;
  uses interface CC2420Register as FSCTRL;

  uses interface CC2420Strobe as SRFOFF;
  uses interface CC2420Strobe as SRXON;
}


implementation {
  enum states {
    NODE_DETECTION_STATE,
    SENDER_SELECTION_STATE,
    IDLE_STATE,
    WAITING_STATE,
    DATA_COLLECTION_STATE,
    SERIAL_SINK_DATA_STATE,
    CHANGE_CHANNEL_STATE
  };

  enum commands{
    ID_REQUEST,
    SENDER_ASSIGN,
    CHANGE_CHANNEL,
    DATA_COLLECTION_REQUEST,
    DO_NOTHING,
    FINISHED,
    FINISHED_MEASUREMENTS,
    PLACEHOLDER_COMMAND
  };


  // Non sense setting it here as it will be set on initialization always
  uint8_t numChannels = 16;
  uint8_t channels[] = {11,12,13,14,15,16,17,18,19,20,21,22,23,24,25,26}; // TODO: right now first channel must be 11

  // TODO do timings dependent on node count
  uint16_t assignRetries = 0;
  uint16_t maxAssignRetries = 2;



  uint8_t dataCollectionChannel  = 11; // TODO not used
  uint16_t numMeasurements = 5;
  uint16_t channelWaitTime = 50;
  uint16_t senderChannelWaitTime = 150;
  uint16_t idRequestWaitTime = 2000;

  // TODO configure these here
  uint16_t dataCollectionWaitTime = 2000;
  uint16_t resetTime = 60000;
  //uint16_t resetTime = 0; // TODO now disabled, change to 20000
  uint16_t reassignTime = 3000; // time to resend sender assign

  // init Array
  uint16_t *nodeIds=NULL;
#define  MAX_MEASUREMENTS 1000
  CollectionDataMsg measurements[MAX_MEASUREMENTS];

  // function declarations
  void addNodeIdToArray(uint16_t);
  void resetNodeIds();
  void printNodesArray();
  void debugMessage(const char *);
  void printMeasurementArray();
  task void sendMeasurementPacket();
  task void sendCTPMeasurementData();
  task void statemachine();

  // counter/array counter
  int nodeCount=0;
  int measurementCount=0;
  bool justStarted = TRUE;

  int receivedDataPackets=0;
  int measurementSendCount = 0;
  int serialMeasurementsTransmitted=0;
  int measurementsTransmitted=0;
  int channelIterator=0;
  int senderIterator=0;
  int dataSenderIterator=0;
  bool isSink=FALSE;
  bool isTransmittingMeasurements=FALSE;

  // Statemachine
  int state = NODE_DETECTION_STATE;

  // Used for CTP
  message_t ctp_discover_packet, ctp_collection_packet, am_packet;
  bool sendBusy = FALSE;

  // Serial Transmission
  bool serialSend(uint16_t senderNodeId, uint16_t receiverNodeId, int16_t rssValue, uint8_t channel, uint8_t measurementNum);
  bool serialSendFinish();
  bool serialSendBusy = FALSE;
  message_t serial_packet;

  // Channel switching
  const uint8_t startChannel = 11;
  uint8_t currentChannel = CC2420_DEF_CHANNEL;
  uint8_t curTxPower = CC2420_DEF_RFPOWER;
  uint8_t nextTxPower = CC2420_DEF_RFPOWER;
  uint8_t nextChannel = -1;
  bool txpchanged = FALSE;

  // private/don't use.
  void setTxPower(uint8_t);
  void setChannel(uint8_t);

  // IMPORTANT: set nextChannel and txpchanged/nextTxPower and call acquireSpiResurce
  error_t acquireSpiResource();
  error_t releaseSpiResource();

  // Dissemination ControlMsg
  struct ControlData controlMsg;



  event void Boot.booted() {
    call RadioControl.start();
    call SerialAMControl.start();
  }

  event void RadioControl.startDone(error_t err) {
    if (err != SUCCESS)
      call RadioControl.start();
    else {
      // set start channel
      nextChannel = startChannel;
      acquireSpiResource();

      // start disseminate and ctp
      call DisseminationControl.start();
      call RoutingControl.start();


    }
  }


  event void Timer.fired() {
    post statemachine();
  }
  event void ResetTimer.fired() {
    // go back to channel eleven

    debugMessage("Reset Timer called");

    nextChannel = startChannel;
    acquireSpiResource();
  }

  event void ReassignTimer.fired() {
    //Reset disseminate
    controlMsg.dissCommand = PLACEHOLDER_COMMAND;
    controlMsg.dissValue = 0;
    controlMsg.dissValue2 = 0;

    call Update.change((ControlData*)(&controlMsg));

    if(assignRetries < maxAssignRetries) {
      senderIterator -= 1;
      assignRetries++;
    } else {
      int i;
      printf("too many reassigns. deleting node %d from list\n", nodeIds[senderIterator-1]); printfflush();
      for(i=senderIterator-1; i<nodeCount-1;i++) {
        nodeIds[i] = nodeIds[i+1];
      }
      nodeCount--;
      senderIterator -= 1;
    }
    post statemachine();
  }

  event void ChannelTimer.fired() {

    acquireSpiResource();
    debugMessage("channel changed\n");
    if(isSink) {
      post statemachine();
    }

  }

  void resetState() {
    state = NODE_DETECTION_STATE;
    senderIterator = 0;
    measurementsTransmitted = 0;
  }

  task void statemachine(){
    switch(state){
      //Node detection State
      case(NODE_DETECTION_STATE):
        // RESET everything
        call Leds.set(1);
        resetNodeIds();
        debugMessage("\n\n\nSend DISCOVER to all nodes\n");
        controlMsg.dissCommand = ID_REQUEST;
        controlMsg.dissValue = numMeasurements;
        controlMsg.dissValue2 = channelWaitTime ;
        call Update.change((ControlData*)(&controlMsg));
        printfflush();
        state = WAITING_STATE;
        call Timer.startOneShot(idRequestWaitTime);
        break;
        //Node selection State
      case WAITING_STATE:  //TODO merge with sender_selection_state
        debugMessage("Found nodes:\n");
        printNodesArray();
        state = SENDER_SELECTION_STATE;

        call Timer.startOneShot(500);
        break;
      case SENDER_SELECTION_STATE:
        call Leds.set(2);
        // change controlMsg
        if (senderIterator >= nodeCount) {
          senderIterator = 0;
          receivedDataPackets = measurementCount; // TODO: delete receivedDataPackets and just use measurementCount
          state = SERIAL_SINK_DATA_STATE;
          post statemachine();
          break;
        }
        controlMsg.dissCommand = SENDER_ASSIGN;
        controlMsg.dissValue = nodeIds[senderIterator];
        controlMsg.dissValue2 = currentChannel;

        call ReassignTimer.startOneShot(reassignTime);
        call Update.change((ControlData*)(&controlMsg));
        printf("Send SENDER_ASSIGN to %u\n", nodeIds[senderIterator]);
        printfflush();
        senderIterator++;
        break;

      case SERIAL_SINK_DATA_STATE:
        call Leds.set(3);
        if(serialMeasurementsTransmitted >= receivedDataPackets) {
          receivedDataPackets = 0;
          debugMessage("\nserial-transmitted all measurements\n");
          serialMeasurementsTransmitted = 0;
          state=DATA_COLLECTION_STATE;
          post statemachine();
          break;
        }
        if(!serialSend(measurements[serialMeasurementsTransmitted].senderNodeId, measurements[serialMeasurementsTransmitted].receiverNodeId, measurements[serialMeasurementsTransmitted].measuredRss, measurements[serialMeasurementsTransmitted].channel, measurements[serialMeasurementsTransmitted].measurementNum)) {
          call Timer.startOneShot(50);
        } else {
          serialMeasurementsTransmitted++;
        }
        break;

      case DATA_COLLECTION_STATE:
        call Leds.set(4);
        if (dataSenderIterator >= nodeCount) {
          dataSenderIterator = 0;
          state = CHANGE_CHANNEL_STATE;
          post statemachine();
          break;
        }
        if(nodeIds[dataSenderIterator] == TOS_NODE_ID && isSink) { // no data collection for sink node! (i transmitted my stuff already)
          dataSenderIterator++;
          post statemachine();
          break;
        }

        controlMsg.dissCommand = DATA_COLLECTION_REQUEST;
        controlMsg.dissValue = nodeIds[dataSenderIterator];
        call Update.change((ControlData*)(&controlMsg));
        printf("Send DATA_COLLECTION_REQUEST to %u\n", nodeIds[dataSenderIterator]);
        printfflush();
        state = SERIAL_SINK_DATA_STATE;
        dataSenderIterator++;

        // go on if no data arriving
        call Timer.startOneShot(dataCollectionWaitTime);
        break;
      case CHANGE_CHANNEL_STATE:
        call Leds.set(5);
        controlMsg.dissCommand = CHANGE_CHANNEL;
        // set next channel. TODO: first channel is always 11. change this with ID_REQUEST
        channelIterator++;
        if(channelIterator >= numChannels) {
          channelIterator = 0;
          state = IDLE_STATE;
        } else {
          state = SENDER_SELECTION_STATE;
        }
        controlMsg.dissValue = channels[channelIterator];
        call Update.change((ControlData*)(&controlMsg));

        break;
      case IDLE_STATE:
        call Leds.set(0);
        controlMsg.dissCommand = DO_NOTHING;
        controlMsg.dissValue = 0;
        call Update.change((ControlData*)(&controlMsg)); //canged "nodeIds+senderIterator" to "ctrMsg.DissValue"
        break;
    }
  }

  event void RadioControl.stopDone(error_t err) {}

  task void sendCTPMeasurementData() {
    CollectionDataMsg *msg;
    if(sendBusy) {
      debugMessage("Call to sendCTPMeasurementData while sendBusy is true\n");
      return;
    }
    msg =
      (CollectionDataMsg*)call CTPSend.getPayload(&ctp_collection_packet, sizeof(CollectionDataMsg));

    if(measurementsTransmitted < measurementCount) {
      (*msg) = measurements[measurementsTransmitted];
    } else {
      msg->senderNodeId = 0;
      msg->receiverNodeId = TOS_NODE_ID;
      msg->measuredRss = 0;
      msg->channel = 0;
      msg->measurementNum = 0;
    }


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
      debugMessage("Sent Node ID\n");
      sendBusy = TRUE;
    }
  }

  event void Value.changed() {
    const ControlData newVal = *(call Value.get());
    if(resetTime != 0) {
      call ResetTimer.startOneShot(resetTime);
    }

    // ignore first disseminate command if we just started and command is not id_request
    if(justStarted && newVal.dissCommand != ID_REQUEST) {
      return;
    }

    //debugMessage("received diss value: ");
    switch(newVal.dissCommand) {
      case ID_REQUEST:
        justStarted = FALSE;
        numMeasurements = newVal.dissValue;
        channelWaitTime = newVal.dissValue2;
        debugMessage("ID Request from Sink node\n");
        sendCTPNodeId();
        break;
      case SENDER_ASSIGN:
        // change channel and sender begin
        debugMessage("sender assign\n");
        if(newVal.dissValue == TOS_NODE_ID) {
          debugMessage("im sender now\n");
          if(!isSink)
            call Leds.led2On();
          measurementSendCount = 0;
          // TODO WAIT before sending?
          post sendMeasurementPacket();
        } else {
          if(!isSink)
            call Leds.led2Off();
        }
        break;

      case FINISHED_MEASUREMENTS:
        // select next sender. if all selected go over
        if(isSink) {
          call ReassignTimer.stop();
          assignRetries = 0;
          post statemachine();
        }
        break;
      case CHANGE_CHANNEL:
        measurementCount = 0;
        if(isSink) {
          printf("received channel change to %u\n", newVal.dissValue);
          printfflush();
        }
        nextChannel = newVal.dissValue;
        if(isSink) {
          call ChannelTimer.startOneShot(senderChannelWaitTime); // if i am sink, wait longer!
        } else {
          call ChannelTimer.startOneShot(channelWaitTime);
        }
        break;
      case DATA_COLLECTION_REQUEST:
        if(newVal.dissValue == TOS_NODE_ID) { // if i am selected, do data collection
          if(!isSink)
            call Leds.led0On();
          debugMessage("received request for data collection for me\n");
          // start by sending first measurement and go on in sendDone
          measurementsTransmitted = 0;
          isTransmittingMeasurements = TRUE;
          post sendCTPMeasurementData();
        } else {
          if(!isSink)
            call Leds.led0Off();
        }
        break;
      case DO_NOTHING:
        debugMessage("end of the story\n");
        if(isSink) {
          while(!serialSendFinish());
        }
        call ResetTimer.stop();
        break;
      case PLACEHOLDER_COMMAND:
        break;
      default:
        printf("received unknown diss command: %u, value: %u", newVal.dissCommand, newVal.dissValue);
        printfflush();
    }
  }

  event void CTPSend.sendDone(message_t* m, error_t err) {
    // If we sent a measurementdata packet, go on by sending the next one
    if(err != SUCCESS) {
      debugMessage("Error sending via CTP\n");
    } else {
      //debugMessage("transmitted measurement value to sink\n");
      if(isTransmittingMeasurements) {
        measurementsTransmitted++;

      }

    }
    sendBusy = FALSE;
    if(!isTransmittingMeasurements) {
      debugMessage("transmitted Node ID\n");
    }
    else if(measurementsTransmitted < measurementCount) {
      post sendCTPMeasurementData();
    } else {
      debugMessage("transmitted all measurement values to sink\n");
      isTransmittingMeasurements = FALSE;
      // go on here
    }
  }

  // CTP receive
  event message_t* CTPReceive.receive(message_t* msg, void* payload, uint8_t len) {
    // do action dependent on packet type (= size)
    NodeIDMsg *receivedNodeId;
    CollectionDataMsg *receivedCollectionData;
    call Leds.set(6);
    switch(len) {
      case sizeof(NodeIDMsg):
        receivedNodeId = (NodeIDMsg*)payload;
        addNodeIdToArray(receivedNodeId->nodeId);
        break;
      case sizeof(CollectionDataMsg):
        receivedCollectionData = (CollectionDataMsg*)payload;
        measurements[receivedDataPackets] = *receivedCollectionData;
        receivedDataPackets++;
        if(receivedDataPackets >= (nodeCount-1)*numMeasurements) {
          call Timer.stop();
          post statemachine(); // go to serial transmission
        } else {
          // fallback timer. if we don't receive a next data packet in X seconds, just go on
          call Timer.startOneShot(dataCollectionWaitTime);
        }
        break;
      default:
        debugMessage("Received CTP length doesn't match expected one.\n");
    }
    return msg;
  }

  // AM send
  task void sendMeasurementPacket() {
    if (!sendBusy) {
      RSSMeasurementMsg* rss_msg = (RSSMeasurementMsg*)(call Packet.getPayload(&am_packet, sizeof(RSSMeasurementMsg)));
      if (rss_msg == NULL) {
        debugMessage("could not send measurement paket. repeating\n");
        post sendMeasurementPacket();
        return;
      }
      rss_msg->nodeId = TOS_NODE_ID;
      rss_msg->measurementNum = measurementSendCount;
      if (call AMSend.send(AM_BROADCAST_ADDR, &am_packet, sizeof(RSSMeasurementMsg)) == SUCCESS) {
        sendBusy = TRUE;
        return;
      }
    } else {
      debugMessage("wanted to send measurement with sendbusy true\n");
    }
    post sendMeasurementPacket();
  }

  event void AMSend.sendDone(message_t* msg, error_t err) {
    sendBusy = FALSE;
    if (err != SUCCESS) {
      debugMessage("Error sending AM packet");
    } else {
      //debugMessage("sent measurement\n");
      measurementSendCount += 1;
    }
    if(measurementSendCount < numMeasurements) {
      post sendMeasurementPacket();
    } else {
      // inform everyone that i finished sending
      controlMsg.dissCommand = FINISHED_MEASUREMENTS;
      controlMsg.dissValue = 0;
      printf("inform everyone that sending is finished\n");
      printfflush();
      call Update.change((ControlData*)(&controlMsg));
    }
  }

  int16_t getRssi(message_t *msg){
    return (int16_t) (call CC2420Packet.getRssi(msg))-45; // According to CC2420 datasheet, (RSSI / Energy Detection) it says there is -45 Rssi offset.
  }

  // AM receive
  event message_t* AMReceive.receive(message_t* msg, void* payload, uint8_t len){
    if (len == sizeof(RSSMeasurementMsg)) {
      RSSMeasurementMsg* rss_msg = (RSSMeasurementMsg*)payload;
      //setLeds(btrpkt->counter);
      //printf("measurement packet recived. sender node: %d, RSS:  %d\n", rss_msg->nodeId, (int)getRssi(msg));
      // Save RSSI to packet now
      if(measurementCount >= MAX_MEASUREMENTS) {
        printf("measurementCount=%d, channels*numMeasu=%d, max_measurements=%d\n", measurementCount, numChannels*numMeasurements, MAX_MEASUREMENTS);
        debugMessage("too many measurements for our array. decrementing measurementCount");
        measurementCount--;
      }

      measurements[measurementCount].senderNodeId = rss_msg->nodeId;
      measurements[measurementCount].channel = currentChannel;
      measurements[measurementCount].measurementNum = rss_msg->measurementNum;
      measurements[measurementCount].measuredRss = (int16_t)getRssi(msg);
      measurements[measurementCount].receiverNodeId = TOS_NODE_ID;
      measurementCount++;
    }
    return msg;
  }


  void resetNodeIds() {
    nodeCount = 0;
    free(nodeIds);

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
      printf("rss measurement nr. %d from node %d: %d\n", k, measurements[k].senderNodeId, measurements[k].measuredRss);
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
  bool serialSendFinish() {
    if (serialSendBusy) {
      debugMessage("failed serial: serialSendBusy is true.\n");
      return FALSE;
    }
    else {
      measurement_data_t *rcm = (measurement_data_t*)call SerialAMPacket.getPayload(&serial_packet, sizeof(measurement_data_t));
      if (rcm == NULL) {debugMessage("failed serial: getting rcm\n"); return FALSE;}

      // This is like the "command for finish " #hacky #TODO
      rcm->channel = 0;
      rcm->senderNodeId = 0;
      rcm->receiverNodeId = 0;
      rcm->rss = 0;
      rcm->channel = 0;
      rcm->measurementNum = 0;


      if (call SerialAMPacket.maxPayloadLength() < sizeof(measurement_data_t)) {
        debugMessage("failed serial: wrong packet size\n");
        return FALSE;
      }

      if (call SerialAMSend.send(AM_BROADCAST_ADDR, &serial_packet, sizeof(measurement_data_t)) == SUCCESS) {
        serialSendBusy = TRUE;
      } else {
        debugMessage("failed serial: send returns false\n");
        return FALSE;
      }
    }
    return TRUE;

  }
  // Serial data transfer
  // TODO: pass a measurement struct....
  bool serialSend(uint16_t senderNodeId, uint16_t receiverNodeId, int16_t rssValue, uint8_t channel, uint8_t measurementNum) {
#if DEBUG
    // just printf and go back to statemachine
    printf("%u, %u, %u, %d, %u\n", senderNodeId, receiverNodeId, channel, rssValue, measurementNum);
    printfflush();
    if(state == SERIAL_SINK_DATA_STATE)
      post statemachine();
    return TRUE;
#endif

    if (serialSendBusy) {
      debugMessage("failed serial: serialSendBusy is true.\n");
      return FALSE;
    }
    else {
      measurement_data_t *rcm = (measurement_data_t*)call SerialAMPacket.getPayload(&serial_packet, sizeof(measurement_data_t));
      if (rcm == NULL) {debugMessage("failed serial: getting rcm\n"); return FALSE;}

      rcm->senderNodeId = senderNodeId;
      rcm->receiverNodeId = receiverNodeId;
      rcm->rss = rssValue;
      rcm->channel = channel;
      rcm->measurementNum = measurementNum;

      if (call SerialAMPacket.maxPayloadLength() < sizeof(measurement_data_t)) {
        debugMessage("failed serial: wrong packet size\n");
        return FALSE;
      }

      if (call SerialAMSend.send(AM_BROADCAST_ADDR, &serial_packet, sizeof(measurement_data_t)) == SUCCESS) {
        serialSendBusy = TRUE;
      } else {
        debugMessage("failed serial: send returns false\n");
        return FALSE;
      }
    }
    return TRUE;

  }
  event void SerialAMSend.sendDone(message_t* bufPtr, error_t error) {
    if (&serial_packet == bufPtr) {
      serialSendBusy = FALSE;
      debugMessage("successfully sent\n");
    } else {
      serialSendBusy = FALSE;
      debugMessage("unsuccessfully sent serial\n");
    }
    if(state == SERIAL_SINK_DATA_STATE)
      post statemachine();
  }

  event void SerialAMControl.startDone(error_t err) {
  }
  event void SerialAMControl.stopDone(error_t err) {
    // do nothing
  }
  event message_t* SerialAMReceive.receive(message_t* bufPtr,
      void* payload, uint8_t len) {
    serial_control_t* control_msg = (serial_control_t*)(call Packet.getPayload(bufPtr, (int) NULL));
    if(!isSink)
      call RootControl.setRoot();
    isSink = TRUE;
    if(control_msg->cmd == 0) {
      resetState();

      // set channels
      numChannels = control_msg->num_channels;
      memcpy(channels, control_msg->channels, sizeof(uint8_t)*numChannels);

      // set all data from packet
      if(control_msg->num_measurements > 0) {
        numMeasurements = control_msg->num_measurements;
      }
      //debug = control_msg->debug;

      if(control_msg->channel_wait_time > 0) {
        channelWaitTime = control_msg->channel_wait_time;
      }
      if(control_msg->sender_channel_wait_time > 0) {
        senderChannelWaitTime = control_msg->sender_channel_wait_time;
      }
      if(control_msg->id_request_wait_time > 0) {
        idRequestWaitTime = control_msg->id_request_wait_time;
      }
      if(control_msg->data_collection_channel > 0) {
        dataCollectionChannel = control_msg->data_collection_channel;
      }

      post statemachine();
    }
    return bufPtr;
  }
  void debugMessage(const char *msg) {
    if(serialSendBusy || !isSink || DEBUG == 0 ) {
      return;
    } else {
      printf(msg);
      printfflush();
    }
  }
  // Channel switching
  event void SpiResource.granted() {

    debugMessage("Request Granted\n");

    if (txpchanged) {
      setTxPower(nextTxPower);
      txpchanged = FALSE;
    }
    else if (nextChannel >= 0) {
      setChannel(nextChannel);
      nextChannel = -1;
    }


    //if ( nextTxPower != curTxPower)
    //	setTxPower(nextTxPower);

    releaseSpiResource();
  }

  error_t acquireSpiResource() {
    error_t error = call SpiResource.immediateRequest();

    //printf("AquireSpiResource()\n"); printfflush();

    if ( error != SUCCESS ) {
      debugMessage("immediate not possible, requesting()\n");
      call SpiResource.request();
    }
    else {
      if (txpchanged) {
        setTxPower(nextTxPower);
        txpchanged = FALSE;
      }
      else if (nextChannel >= 0) {
        setChannel(nextChannel);
        nextChannel = -1;
      }

      //if ( nextTxPower != curTxPower)
      //	setTxPower(nextTxPower);

      releaseSpiResource();
    }
    if(currentChannel == startChannel) {
      if(!isSink)
        call Leds.led1On();
    } else {
      if(!isSink)
        call Leds.led1Off();
    }
    return error;
  }

  error_t releaseSpiResource() {
    debugMessage("Spi resource releasing()\n");
    call SpiResource.release();
    return SUCCESS;
  }
  void setTxPower(uint8_t tpower) {
    uint8_t tx_power = tpower;
    uint16_t wr_power = 0;
    uint16_t rd_power = 0;
    cc2420_status_t status;

    call CSN.clr();
    call SRFOFF.strobe();
    call CSN.set();

    if ( !tx_power ) {
      tx_power = CC2420_DEF_RFPOWER;
    }
    printf ("Now will set power to %d\n", tx_power); printfflush();
    atomic{
      call CSN.clr();
      if ( curTxPower != tx_power ) {
        wr_power = ( 2 << CC2420_TXCTRL_TXMIXBUF_CUR ) |
          ( 3 << CC2420_TXCTRL_PA_CURRENT ) |
          ( 1 << CC2420_TXCTRL_RESERVED ) |
          ( (tx_power & 0x1F) << CC2420_TXCTRL_PA_LEVEL );

        status = call TXCTRL.write( wr_power );
      }
      call TXCTRL.read(&rd_power);
      call CSN.set();
    }

    call CSN.clr();
    call SRXON.strobe();
    call CSN.set();

    printf("Written: %d(%X), Read:%d(%X)", wr_power, wr_power, rd_power, rd_power); printfflush();

    if ( rd_power != wr_power)
      ;//call Leds.led0On();
    else {
      ;//call Leds.led0Off();
      curTxPower = tx_power;
    }

    if (curTxPower != tx_power) {
      printf("\t M_TX_POWER is set to %d from %d\n", tx_power, curTxPower);
      printfflush();
    }

    printfflush();
  }

  void setChannel (uint8_t tchannel) {
    uint8_t channel = tchannel;
    //currentChannel = tchannel;
    uint16_t wr_channel = 0;
    uint16_t rd_channel = 0;

    cc2420_status_t status = 0;

    if(!channel) {
      channel = CC2420_DEF_CHANNEL;
    }


    call CSN.clr();
    call SRFOFF.strobe();
    call CSN.set();

    printf("set to channel=%d currentChannel=%d ",channel, currentChannel);
    printfflush();

    atomic {

      if (nextChannel >= 0) {
        call CSN.clr();
        call FSCTRL.read(&wr_channel);
        wr_channel = (wr_channel & 0xFE00) | ( ( (channel - 11)*5+357 ) << CC2420_FSCTRL_FREQ );
        call CSN.set();
        call CSN.clr();
        //wr_channel = ( 1 << CC2420_FSCTRL_LOCK_THR ) | ( ( (channel - 11)*5+357 ) << CC2420_FSCTRL_FREQ );
        status = call FSCTRL.write( wr_channel );
        call CSN.set();
      }

      do {
        call CSN.clr();
        call FSCTRL.read(&rd_channel);
        call CSN.set();
      } while (rd_channel & 0x1000);
    }

    call CSN.clr();
    call SRXON.strobe();
    call CSN.set();

    if (rd_channel != wr_channel) {
      printf("Problem: rd_channel=%d(0x%X) != wr_channel=%d(0x%X) && status = 0x%X SPI.owner=%d\n",rd_channel, rd_channel, wr_channel, wr_channel, status, call SpiResource.isOwner());
      if(!isSink)
        call Leds.led0On();
    }
    else {
      currentChannel = channel;
    }

    printfflush();
  }

}
