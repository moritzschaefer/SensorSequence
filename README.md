# Setup/Installation

- Get TinyOS (i installed to /opt).
- Uninstall kate-data (it conflicts with nescc due to a bug) and install nescc.
- Go to /opt/tinyos/tools and run  (compare http://tinyos.stanford.edu/tinyos-wiki/index.php/Installing_From_Source):
    cd tinyos-main/tools
    ./Bootstrap
    ./configure
    make
    make install
- Install gcc-msp430
- Now write your project and run "make tmote" to build and "make tmote install" for programming the device. You're done :)

# Protocols to use

In the project we will be using Radio interface, Serial interface, ActiveMessage and Networking Protocols (Dissemination and CTP). These are some readings for you:
http://tinyos.stanford.edu/tinyos-wiki/index.php/Mote-mote_radio_communication
http://tinyos.stanford.edu/tinyos-wiki/index.php/Network_Protocols

# Ressources

- The sensor module is called tmote.
- Tinyos getting started: http://tinyos.stanford.edu/tinyos-wiki/index.php/TinyOS_Tutorials#Getting_Started_with_TinyOS
    - especially http://tinyos.stanford.edu/tinyos-wiki/index.php/Getting_Started_with_TinyOS

- Maybe interesting: http://www.tinyos.net/dist-2.0.0/tinyos-2.x/doc/html/tutorial/lesson12.html. Not really important. is the same as http://tinyos.stanford.edu/tinyos-wiki/index.php/Network_Protocols
- Maybe interesting: http://tinyos.stanford.edu/tinyos-wiki/index.php/TOSSIM
- Tutorial from Onur: (important:)
