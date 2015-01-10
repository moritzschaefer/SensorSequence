#ifndef MEASUREMENT_DATA_H
#define MEASUREMENT_DATA_H

typedef nx_struct measurement_data {
  nx_int16_t rss;
  nx_uint16_t senderNodeId;
  nx_uint16_t receiverNodeId;
  nx_uint8_t channel;
} measurement_data_t;

enum {
  AM_MEASUREMENT_DATA = 0x89,
};

#endif
