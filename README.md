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

# Ressources

- The sensor module is called tmote.
- Tinyos getting started: http://tinyos.stanford.edu/tinyos-wiki/index.php/TinyOS_Tutorials#Getting_Started_with_TinyOS
    - especially http://tinyos.stanford.edu/tinyos-wiki/index.php/Getting_Started_with_TinyOS

