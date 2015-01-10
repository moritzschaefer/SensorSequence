#ifndef DATA_TYPES_H
#define DATA_TYPES_H

typedef struct ControlData {
    uint16_t dissCommand;
    uint16_t dissValue;
} ControlData;


typedef nx_struct NodeIDMsg {
    nx_uint16_t nodeId;
    nx_uint16_t rss;
} NodeIDMsg;

typedef nx_struct CollectionDataMsg {
    nx_uint16_t senderNodeId;
    nx_uint16_t receiverNodeId;
    nx_uint16_t rss;
} CollectionDataMsg;

typedef nx_struct RSSMeasurementMsg {
  nx_uint16_t nodeId;
} RSSMeasurementMsg;


typedef nx_struct SerialControlMsg {
  nx_uint16_t cmd;
} SerialControlMsg;
#endif /* DATA_TYPES_H */
