#define NEW_PRINTF_SEMANTICS
//#include "utils.h"
#include <Timer.h>
#include "dataTypes.h"
#include "constants.h"
#include "MeasurementData.h"
#include "SerialControl.h"

#include "printf.h"

// TODO: find better name to for CollectionDataMsg
// Green: I'm on START_CHANNEL
// Blue: I am sender
// Red: I am the boss (sink)

// Disable printfs
#if DEBUG
#elif
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
    SERIAL_SINK_DATA_STATE

  };

  enum commands{
    ID_REQUEST,
    SENDER_ASSIGN,
    CHANGE_CHANNEL,
    DATA_COLLECTION_REQUEST,
    DO_NOTHING,
    FINISHED
  };

  uint16_t numMeasurements = 5;
  uint16_t channelWaitTime = 50;
  uint16_t senderChannelWaitTime = 150;
  uint16_t idRequestWaitTime = 2000;
  uint16_t startUpWaitTime = 5000;
  uint8_t dataCollectionChannel  = 11;

  // init Array
  uint16_t *nodeIds=NULL;
  CollectionDataMsg *measurements;

  // function declarations
  void addNodeIdToArray(uint16_t);
  void printNodesArray();
  void debugMessage(const char *);
  void printMeasurementArray();
  task void sendMeasurementPacket();
  task void sendCTPMeasurementData();
  task void sendCTPFullMeasurementData();
  task void statemachine();

  // counter/array counter
  int nodeCount=0;
  int measurementCount=0;
  bool justStarted = TRUE;
  int currentSender = -1;

  int receivedDataPackets=0;
  int measurementSendCount = 0;
  int serialMeasurementsTransmitted=0;
  int measurementsTransmitted=0;
  int senderIterator=0;
  int dataSenderIterator=0;
  bool isTransmittingMeasurements=FALSE;

  // Statemachine
  int state = NODE_DETECTION_STATE;

  // TODO: should we use only one sendBusy field for CTP/Serial/...? maybe they intefere..
  // Used for CTP
  message_t ctp_discover_packet, ctp_collection_packet, am_packet;
  bool sendBusy = FALSE;

  // Serial Transmission
  bool serialSend(uint16_t senderNodeId, uint16_t receiverNodeId, int16_t rssValue, uint8_t channel, uint8_t measurementNum);
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


      if (TOS_NODE_ID == 0) {
        call RootControl.setRoot();
        call Leds.led0On();
        // Wait before starting to receive "dead" disseminate
        //call Timer.startOneShot(startUpWaitTime);
      }
    }
  }


  event void Timer.fired() {
    post statemachine();
  }
  event void ResetTimer.fired() {
    // go back to channel eleven
    nextChannel = startChannel;
    acquireSpiResource();
  }

  event void ChannelTimer.fired() {

    acquireSpiResource();
    printfflush();

    // channel changed

    // if we reach first channel again
    if(currentChannel == startChannel) {
      if(TOS_NODE_ID == currentSender) {
        debugMessage("finished sending measurements\n");
      }
      if(TOS_NODE_ID == 0) {
        serialMeasurementsTransmitted=0;
        dataSenderIterator = 0;
        state = DATA_COLLECTION_STATE;
        post statemachine();
      }
    } else {
      // if it's me, that was the sender, go on with measurements
      if(currentSender == TOS_NODE_ID) {
        measurementSendCount = 0;
        post sendMeasurementPacket();
      }
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
        debugMessage("\n\n\nSend DISCOVER to all nodes\n");
        controlMsg.dissCommand = ID_REQUEST;
        controlMsg.dissValue = numMeasurements;
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
        // change controlMsg
        if (senderIterator >= nodeCount) {
          state = IDLE_STATE;
          call Timer.startOneShot(150);
          break;
        }
        controlMsg.dissCommand = SENDER_ASSIGN;
        controlMsg.dissValue = nodeIds[senderIterator];
        call Update.change((ControlData*)(&controlMsg));
        printf("Send SENDER_ASSIGN to %u\n", nodeIds[senderIterator]);
        printfflush();
        senderIterator++;
        /*if (senderIterator >= nodeCount) {
          state = IDLE_STATE;
        }*/
        // go on by disseminate signal from other node
        break;
      case SERIAL_SINK_DATA_STATE:
        if(serialMeasurementsTransmitted >= numMeasurements*NUM_CHANNELS) {
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
        if (dataSenderIterator >= nodeCount) {
          dataSenderIterator = 0;
          state = SENDER_SELECTION_STATE;
          post statemachine();
          break;
        }
        if(nodeIds[dataSenderIterator] == currentSender) {
          dataSenderIterator++;
          if(dataSenderIterator >= nodeCount) {
            dataSenderIterator = 0;
            // go on with next node measurings
            state = SENDER_SELECTION_STATE;
          }
          post statemachine();
          break;
        }

        controlMsg.dissCommand = DATA_COLLECTION_REQUEST;
        controlMsg.dissValue = nodeIds[dataSenderIterator];
        call Update.change((ControlData*)(&controlMsg));
        printf("Send DATA_COLLECTION_STATE to %u\n", nodeIds[dataSenderIterator]);
        printfflush();
        dataSenderIterator++;
        break;
      case IDLE_STATE:
        controlMsg.dissCommand = DO_NOTHING;
        controlMsg.dissValue = 0;
        call Update.change((ControlData*)(&controlMsg)); //canged "nodeIds+senderIterator" to "ctrMsg.DissValue"
        break;
    }
  }

  event void RadioControl.stopDone(error_t err) {}

  task void sendCTPFullMeasurementData() {
    FullCollectionDataMsg *msg;
    int i;

    if(sendBusy) {
      debugMessage("Call to sendCTPFullMeasurementData while sendBusy is true\n");
      return;
    }
    msg =
      (FullCollectionDataMsg*)call CTPSend.getPayload(&ctp_collection_packet, sizeof(FullCollectionDataMsg));
    msg->numData = measurementCount;

    for(i=0; i<measurementCount; i++) {
      msg->data[i] = measurements[i];
    }


    if (call CTPSend.send(&ctp_collection_packet, sizeof(FullCollectionDataMsg)) != SUCCESS) {
      debugMessage("Error sending FullCollectionData via CTP\n");
    } else {
      sendBusy = TRUE;
    }

  }
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
    const ControlData* newVal = call Value.get();
    // ignore first disseminate command if we just started and command is not id_request
    if(justStarted && newVal->dissCommand != ID_REQUEST) {
      return;
    }

    //debugMessage("received diss value: ");
    switch(newVal->dissCommand) {
      case ID_REQUEST:
        // reset state here! // TODO: all resetting here
        justStarted = FALSE;
        numMeasurements = newVal->dissValue;
        if(measurements) {
          free(measurements);
        }
        measurements = malloc(sizeof(CollectionDataMsg)*numMeasurements*NUM_CHANNELS);
        debugMessage("ID Request from Sink node\n");
        sendCTPNodeId();
        break;
      case SENDER_ASSIGN:
        measurementCount = 0;
        debugMessage("sender assign\n");
        currentSender = newVal->dissValue;
        if(newVal->dissValue == TOS_NODE_ID) {
          debugMessage("im sender now\n");
          call Leds.led2On();
          measurementSendCount = 0;
          post sendMeasurementPacket();
        } else {
          call Leds.led2Off();
        }
        break;
      case CHANGE_CHANNEL:
        printf("received channel change to %u\n", controlMsg.dissValue);
        printfflush();
        nextChannel = newVal->dissValue;
        if(currentSender == TOS_NODE_ID) {
          call ChannelTimer.startOneShot(senderChannelWaitTime); // if i am sender, wait longer!
        } else {
          call ChannelTimer.startOneShot(channelWaitTime);
        }
        break;
      case DATA_COLLECTION_REQUEST:
        debugMessage("received request for data collection\n"); // TODO delete
        if(newVal->dissValue == TOS_NODE_ID) { // if i am selected, do data collection
          if(SEND_SINGLE_MEASUREMENT_DATA) {
            debugMessage("received request for data collection for me\n");
            // start by sending first measurement and go on in sendDone
            measurementsTransmitted = 0;
            isTransmittingMeasurements = TRUE;
            post sendCTPMeasurementData();
          } else {
            post sendCTPFullMeasurementData();
          }
        }
        break;
      case DO_NOTHING:
        debugMessage("end of the story\n");
        break;
      default:
        printf("received unknown diss command: %u, value: %u", newVal->dissCommand, newVal->dissValue);
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

      sendBusy = FALSE;
    }
    if(isTransmittingMeasurements && measurementsTransmitted < NUM_CHANNELS*numMeasurements) {
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
    FullCollectionDataMsg *receivedFullCollectionData;
    switch(len) {
      case sizeof(NodeIDMsg):
        receivedNodeId = (NodeIDMsg*)payload;
        addNodeIdToArray(receivedNodeId->nodeId);
        break;
      case sizeof(CollectionDataMsg):
        receivedCollectionData = (CollectionDataMsg*)payload;
        measurements[receivedDataPackets] = *receivedCollectionData;
        receivedDataPackets++;
        if(receivedDataPackets >= NUM_CHANNELS*numMeasurements) {
          receivedDataPackets = 0;
          state = SERIAL_SINK_DATA_STATE;
          post statemachine();
        }
        break;
      case sizeof(FullCollectionDataMsg):
        receivedFullCollectionData = (FullCollectionDataMsg*)payload;
        printf("received %d measurements from node %d. sender was node %d.\n", receivedFullCollectionData->numData, receivedFullCollectionData->data[0].receiverNodeId, receivedFullCollectionData->data[0].senderNodeId);
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
        //printf("message fired\n");
        //printfflush();
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
      // switch channel
      controlMsg.dissCommand = CHANGE_CHANNEL;
      controlMsg.dissValue = currentChannel+1; // TODO: choose channel from list
      if(controlMsg.dissValue >= startChannel+NUM_CHANNELS) {
        controlMsg.dissValue = startChannel;
      }
      printf("send diss to change to %u\n", controlMsg.dissValue);
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
      if(measurementCount >= NUM_CHANNELS*numMeasurements) {
        printf("measurementCount=%d, channels*numMeasu=%d\n", measurementCount, NUM_CHANNELS*numMeasurements);
        debugMessage("too many measurements for our array");
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
  // Serial data transfer
  // TODO: pass a measurement struct....
  bool serialSend(uint16_t senderNodeId, uint16_t receiverNodeId, int16_t rssValue, uint8_t channel, uint8_t measurementNum) {
#if DEBUG
    // just printf and go back to statemachine
    printf("%u, %u, %u, %d, %u", senderNodeId, receiverNodeId, channel, rssValue, measurementNum);
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
    if(control_msg->cmd == 0) {
      resetState();

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
#if DEBUG
    if(serialSendBusy) {
      return;
    } else {
      printf(msg);
      printfflush();
    }
#endif
  }
  // Channel switching
  event void SpiResource.granted() {

    printf("Request Granted\n"); printfflush();

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
      printf("immediate not possible, requesting()\n"); printfflush();
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
      call Leds.led1On();
    } else {
      call Leds.led1Off();
    }
    return error;
  }

  error_t releaseSpiResource() {
    printf("Spi resource releasing()\n"); printfflush();
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
      call Leds.led0On();
    }
    else {
      currentChannel = channel;
    }

    printfflush();
  }

}
