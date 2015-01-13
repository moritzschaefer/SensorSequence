#ifndef SERIAL_CONTROL_H
#define SERIAL_CONTROL_H

typedef nx_struct serial_control {
// add parameters here
    nx_uint8_t cmd;
} serial_control_t;

enum {
  AM_SERIAL_CONTROL = 0x90,
};

#endif
