interface ChannelSwitch {
  event void switched();
  command void changeChannel();
  //async command uint8_t uiae();
}
