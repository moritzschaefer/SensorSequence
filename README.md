# Environment

Ubuntu 14.10
TinyOS 2.1.2 (from Git, see below)
Python 2.7

# Setup/Installation instructions

- Uninstall kate-data (it conflicts with nescc due to a bug) and install nescc.
- As the tarball version of tinyos is old and python is not fully supported, clone tinyos-main(from github) and install with
    - cd tinyos-main/tools
    - ./Bootstrap
    - ./configure
    - make
    - sudo make install
- Install gcc-msp430 (apt)
- You need TINYOS_ROOT_DIR to be set to the root of your TINYOS installation and you have to 'include $(TINYOS_ROOT_DIR)/Makefile.include' to your tinyos project Makefiles (as it is normal for newer versions of tinyos. Just check the examples)

# Debugging Python Serial Access (not important)

This file includes the main code for python serial communictation. If you want to debug something, look there.

/usr/local/lib/python2.7/dist-packages/tinyos/message/MoteIF.py

# Structure


