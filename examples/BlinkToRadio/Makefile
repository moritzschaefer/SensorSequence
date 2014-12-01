COMPONENT=BlinkToRadioAppC

CFLAGS += -I$(TINYOS_OS_DIR)/lib/net \
					-I$(TINYOS_OS_DIR)/lib/net/le

CFLAGS += -DPRINTF_BUFFER_SIZE=250
CFLAGS += -I$(TINYOS_OS_DIR)/lib/printf

ifneq ($(filter iris,$(AKECMDGOALS)),)
	CFLAGS += -DRF230_RSSI_ENERGY
endif

TINYOS_ROOT_DIR?=../../..
include $(TINYOS_ROOT_DIR)/Makefile.include


