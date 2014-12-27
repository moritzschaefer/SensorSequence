#ifndef MEASUREMENT_DATA_H
#define MEASUREMENT_DATA_H

typedef nx_struct measurement_data {
  nx_uint16_t rss;
  nx_uint16_t nodeId;
} measurement_data_t;

enum {
  AM_MEASUREMENT_DATA = 0x89,
};

#endif
