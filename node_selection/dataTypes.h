#ifndef DATA_TYPES_H
#define DATA_TYPES_H

#include "constants.h"
typedef struct ControlData {
    uint8_t dissCommand;
    uint16_t dissValue;
    uint16_t dissValue2;
} ControlData;


typedef nx_struct NodeIDMsg {
    nx_uint16_t nodeId;
    nx_int16_t rss;
} NodeIDMsg;

typedef nx_struct CollectionDataMsg {
    nx_uint16_t senderNodeId;
    nx_uint16_t receiverNodeId;
    nx_int8_t measuredRss;
    nx_uint8_t channel;
    nx_uint8_t measurementNum;
} CollectionDataMsg;

typedef nx_struct RSSMeasurementMsg {
  nx_uint16_t nodeId;
  nx_uint16_t measurementNum;
} RSSMeasurementMsg;


#endif /* DATA_TYPES_H */
