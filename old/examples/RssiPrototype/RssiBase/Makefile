COMPONENT=RssiBaseAppC

INCLUDES= -I..               \
          -I../InterceptBase
CFLAGS += -I$(TINYOS_OS_DIR)/lib/net \
					-I$(TINYOS_OS_DIR)/lib/let/le

CFLAGS += $(INCLUDES)
CFLAGS += -DPRINTF_BUFFER_SIZE=250
CFLAGS += -I$(TINYOS_OS_DIR)/lib/printf

ifneq ($(filter iris,$(MAKECMDGOALS)),)
	CFLAGS += -DRF230_RSSI_ENERGY
endif

TINYOS_ROOT_DIR?=../../../..
include $(TINYOS_ROOT_DIR)/Makefile.include
