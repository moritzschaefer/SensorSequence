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

## Node Selection

The directory node_selection contains all the necessary code to generate measurements:

It contains the code for the nodes(based on tinyOS) along with the Makefile to compile and flash it.

And it contains the python code (host_controller.py) to control the sink node (see documentation).

## Node Algorithm

This directory contains the code to calculate the sequence from generated measurements. This is not part of the project (besides doing evaluation) and is not further discussed.

# Documentation

The documentation website is located at https://www.tkn.tu-berlin.de/menue/tknteaching/student_projects/project_summaries/a_reliable_multi-channel_rss_measurement_tool_for_wireless_sensor_networks/

The same content is provided in the file documentation.pdf
