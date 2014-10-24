COMPONENT=TestSerialAppC
TOSMAKE_PRE_EXE_DEPS += TestSerialMsg.py
TOSMAKE_CLEAN_EXTRA = *.pyc TestSerialMsg.py

TestSerialMsg.py:
	nescc-mig python $(CFLAGS) -python-classname=TestSerialMsg TestSerial.h test_serial_msg -o $@


include $(TINYOS_ROOT_DIR)/Makefile.include

