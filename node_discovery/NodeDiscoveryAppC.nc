configuration NodeDiscoveryAppC {}
implementation {
  components NodeDiscoveryC;

  components MainC;
  NodeDiscoveryC.Boot -> MainC;

  components ActiveMessageC;
  NodeDiscoveryC.RadioControl -> ActiveMessageC;

  components DisseminationC;
  NodeDiscoveryC.DisseminationControl -> DisseminationC;

  components new DisseminatorC(uint16_t, 0x1234) as Diss16C;
  NodeDiscoveryC.Value -> Diss16C;
  NodeDiscoveryC.Update -> Diss16C;


  components LedsC;
  NodeDiscoveryC.Leds -> LedsC;
}
