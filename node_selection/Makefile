COMPONENT=NodeSelectionAppC

# for serial data upload
TOSMAKE_PRE_EXE_DEPS += MeasurementData.py
TOSMAKE_CLEAN_EXTRA = *.pyc MeasurementData.py

MeasurementData.py:
	nescc-mig python $(CFLAGS) -python-classname=MeasurementData MeasurementData.h measurement_data -o $@

# for ctp:
CFLAGS += -I$(TINYOS_OS_DIR)/lib/net \
          -I$(TINYOS_OS_DIR)/lib/net/le \
          -I$(TINYOS_OS_DIR)/lib/net/ctp

CFLAGS += -DPRINTF_BUFFER_SIZE=250
CFLAGS += -I$(TINYOS_OS_DIR)/lib/printf

### For Drip:
CFLAGS += -I$(TINYOS_OS_DIR)/lib/net -I$(TINYOS_OS_DIR)/lib/net/drip
### For DIP:
#CFLAGS += -I$(TINYOS_OS_DIR)/lib/net -I%T/lib/net/dip -I%T/lib/net/dip/interfaces
### For Dhv
#CFLAGS += -I$(TINYOS_OS_DIR)/lib/net -I%T/lib/net/dhv -I%T/lib/net/dhv/interfaces
include $(TINYOS_ROOT_DIR)/Makefile.include

