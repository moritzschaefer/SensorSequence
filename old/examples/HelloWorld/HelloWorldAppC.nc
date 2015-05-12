configuration PowerupAppC {
}

implementation {
  components MainC, LedsC, PowerupC;
  MainC.Boot -> PowerupC.Boot;
  PowerupC.Leds -> LedsC.Leds;
}

