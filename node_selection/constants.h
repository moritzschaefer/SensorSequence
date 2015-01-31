#ifndef CONSTANTS
#define CONSTANTS

#define DEBUG 0


// number of measurements per channel and node
#define NUM_CHANNELS 16
#define NUM_MEASUREMENTS_PER_NODE 48

#define EMPTY_PACKETS 15

#define SEND_SINGLE_MEASUREMENT_DATA 1

uint8_t numChannels = 4;
uint8_t channels[] = {11,12,13,14,15,16,17,18,19,20,21,22,23,24,25,26}; // TODO: right now first channel must be 11

#endif

