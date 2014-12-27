module ChannelSwitchC {
  uses interface ChannelSwitch;
}
implementation
{
  event void ChannelSwitch.switched()
  {

  }

  event void Timer0.fired()
  {
    call Leds.led0Toggle();
  }

  event void Timer1.fired()
  {
    call Leds.led1Toggle();
  }

  event void Timer2.fired()
  {
    call Leds.led2Toggle();
  }
}
