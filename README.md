# Setup/Installation

- Uninstall kate-data (it conflicts with nescc due to a bug) and install nescc.
- As the tarball version of tinyos is old and python is not full supported, clone tinyos-main and install with
    - cd tinyos-main/tools
    - ./Bootstrap
    - ./configure
    - make
    - sudo make install
- Install gcc-msp430
- You need TINYOS_ROOT_DIR to be set to the root of your TINYOS installation and you have to 'include $(TINYOS_ROOT_DIR)/Makefile.include' to your tinyos project
- Now write your project and run "make tmote" to build and "make tmote install" for programming the device. You're done :)

# Protocols to use

In the project we will be using Radio interface, Serial interface, ActiveMessage and Networking Protocols (Dissemination and CTP). These are some readings for you:
http://tinyos.stanford.edu/tinyos-wiki/index.php/Mote-mote_radio_communication
http://tinyos.stanford.edu/tinyos-wiki/index.php/Network_Protocols

# Python access

This tutorial describes everything to get you started. Call the datalogger.py with an argument like "serial@path/to/serialdev:baudrate" baudrate can be the name of the device (e.g. tmote) as well.
http://wiesel.ece.utah.edu/redmine/projects/hacks/wiki/How_to_use_Python_and_MIG_to_interact_with_a_TinyOS_application
The code doesn't work as is (you have to modify some things but you will notice that on your own).

# Ressources

- The sensor module is called tmote.
- Tinyos getting started: http://tinyos.stanford.edu/tinyos-wiki/index.php/TinyOS_Tutorials#Getting_Started_with_TinyOS
    - especially http://tinyos.stanford.edu/tinyos-wiki/index.php/Getting_Started_with_TinyOS

- Maybe interesting: http://www.tinyos.net/dist-2.0.0/tinyos-2.x/doc/html/tutorial/lesson12.html. Not really important. is the same as http://tinyos.stanford.edu/tinyos-wiki/index.php/Network_Protocols
- Maybe interesting: http://tinyos.stanford.edu/tinyos-wiki/index.php/TOSSIM
- Tutorial from Onur: (important:)
