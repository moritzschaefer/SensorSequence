COMPONENT=NodeDiscoveryAppC

# for tcp:
CFLAGS += -I$(TINYOS_OS_DIR)/lib/net \
          -I$(TINYOS_OS_DIR)/lib/net/le \
          -I$(TINYOS_OS_DIR)/lib/net/ctp

### For Drip:
CFLAGS += -I$(TINYOS_OS_DIR)/lib/net -I$(TINYOS_OS_DIR)/lib/net/drip
### For DIP:
#CFLAGS += -I$(TINYOS_OS_DIR)/lib/net -I%T/lib/net/dip -I%T/lib/net/dip/interfaces
### For Dhv
#CFLAGS += -I$(TINYOS_OS_DIR)/lib/net -I%T/lib/net/dhv -I%T/lib/net/dhv/interfaces
include $(TINYOS_ROOT_DIR)/Makefile.include
