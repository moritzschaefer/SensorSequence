#ifndef SERIAL_CONTROL_H
#define SERIAL_CONTROL_H

typedef nx_struct serial_control {
// add parameters here
    nx_uint8_t cmd; // 0 means start
    nx_uint16_t num_measurements;
    nx_uint8_t debug; // true or false
    nx_uint8_t data_collection_channel; //
    nx_uint16_t channel_wait_time;
    nx_uint16_t sender_channel_wait_time;
    nx_uint16_t id_request_wait_time;
} serial_control_t;

enum {
  AM_SERIAL_CONTROL = 0x90,
};

#endif
