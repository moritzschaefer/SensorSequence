#include <Timer.h>
#include "printf.h"
//#include "AM.h"

module EasyDisseminationC {
  uses interface Boot;
  uses interface SplitControl as RadioControl;
  uses interface StdControl as DisseminationControl;
  uses interface DisseminationValue<uint16_t> as Value;
  uses interface DisseminationUpdate<uint16_t> as Update;
  uses interface Leds;
  uses interface Timer<TMilli>;
  uses interface Timer<TMilli> as ChannelSwitchTimer;

  // channel switching stuff
  uses interface GeneralIO as CSN;

  uses interface Resource as SpiResource;

  uses interface CC2420Ram as TXFIFO_RAM;
  uses interface CC2420Register as TXCTRL;
  uses interface CC2420Strobe as SNOP;
  uses interface CC2420Strobe as STXON;
  uses interface CC2420Strobe as STXONCCA;
  uses interface CC2420Strobe as SFLUSHTX;
  uses interface CC2420Register as MDMCTRL1;
  uses interface CC2420Register as FSCTRL;

  uses interface CC2420Strobe as SRFOFF;
  uses interface CC2420Strobe as SRXON;
}

implementation {
  // function declaration


  bool isSink = TRUE;
  uint8_t sinkNodeID = 0;
  const uint8_t startChannel = 11;
  uint8_t currentChannel = CC2420_DEF_CHANNEL;
  const uint8_t numChannels = 16;
  uint8_t curTxPower = CC2420_DEF_RFPOWER;
  uint8_t nextTxPower = CC2420_DEF_RFPOWER;
  bool changeChannel = FALSE, txpchanged = FALSE;

  // private/don't use.
  void setTxPower(uint8_t);
  void setChannel(uint8_t);
  // set changeChannel and txpchanged/nextTxPower and call acquireSpiResurce
  // TODO: refactor! bring this to separate file
  error_t acquireSpiResource();
  error_t releaseSpiResource();

  uint16_t counter;

  task void ShowCounter() {
    if (counter & 0x1)
      call Leds.led0On();
    else
      call Leds.led0Off();
    if (counter & 0x2)
      call Leds.led1On();
    else
      call Leds.led1Off();
    if (counter & 0x4)
      call Leds.led2On();
    else
      call Leds.led2Off();
  }

  event void Boot.booted() {
    call RadioControl.start();
  }

  event void RadioControl.startDone(error_t err) {
    if (err != SUCCESS)
      call RadioControl.start();
    else {
      call DisseminationControl.start();
      counter = 0;
      if ( TOS_NODE_ID  == 0 )
        call Timer.startPeriodic(1000);
    }
  }

  event void RadioControl.stopDone(error_t err) {}

  event void ChannelSwitchTimer.fired() {
    printf("Now changing channel");
    printfflush();
    changeChannel = TRUE;
    acquireSpiResource();
  }
  event void Timer.fired() {
    counter = counter + 1;
    // show counter in leds
    post ShowCounter();
    // disseminate counter value
    call Update.change(&counter);

  }

  event void Value.changed() {
    const uint16_t* newVal = call Value.get();
    // show new counter in leds
    counter = *newVal;
    printf("Received counter: %d, next channel in 30ms", counter);
    printfflush();
		call ChannelSwitchTimer.startOneShot(30);

  }


  event void SpiResource.granted() {

    printf("Request Granted\n"); printfflush();

    if (txpchanged) {
      setTxPower(nextTxPower);
      txpchanged = FALSE;
    }
    else if (changeChannel)
      setChannel(startChannel+(counter%numChannels));

    //if ( nextTxPower != curTxPower)
    //	setTxPower(nextTxPower);

    releaseSpiResource();
  }

  error_t acquireSpiResource() {
    error_t error = call SpiResource.immediateRequest();

    printf("AquireSpiResource()\n"); printfflush();

    if ( error != SUCCESS ) {
      printf("immediate not possible, requesting()\n"); printfflush();
      call SpiResource.request();
    }
    else {
      if (txpchanged) {
        setTxPower(nextTxPower);
        txpchanged = FALSE;
      }
      else if (changeChannel)
        setChannel(startChannel+(counter%numChannels));

      //if ( nextTxPower != curTxPower)
      //	setTxPower(nextTxPower);

      releaseSpiResource();
    }
    return error;
  }

  error_t releaseSpiResource() {
    printf("Spi resource releasing()\n"); printfflush();
    call SpiResource.release();
    return SUCCESS;
  }
  void setTxPower(uint8_t tpower) {
    uint8_t tx_power = tpower;
    uint16_t wr_power = 0;
    uint16_t rd_power = 0;
    cc2420_status_t status;

    call CSN.clr();
    call SRFOFF.strobe();
    call CSN.set();

    if ( !tx_power ) {
      tx_power = CC2420_DEF_RFPOWER;
    }
    printf ("Now will set power to %d\n", tx_power); printfflush();
    atomic{
      call CSN.clr();
      if ( curTxPower != tx_power ) {
        wr_power = ( 2 << CC2420_TXCTRL_TXMIXBUF_CUR ) |
          ( 3 << CC2420_TXCTRL_PA_CURRENT ) |
          ( 1 << CC2420_TXCTRL_RESERVED ) |
          ( (tx_power & 0x1F) << CC2420_TXCTRL_PA_LEVEL );

        status = call TXCTRL.write( wr_power );
      }
      call TXCTRL.read(&rd_power);
      call CSN.set();
    }

    call CSN.clr();
    call SRXON.strobe();
    call CSN.set();

    printf("Written: %d(%X), Read:%d(%X)", wr_power, wr_power, rd_power, rd_power); printfflush();

    if ( rd_power != wr_power)
      ;//call Leds.led0On();
    else {
      ;//call Leds.led0Off();
      curTxPower = tx_power;
    }

    if (curTxPower != tx_power) {
      printf("\t M_TX_POWER is set to %d from %d\n", tx_power, curTxPower);
      printfflush();
    }

    printfflush();
  }

  void setChannel (uint8_t tchannel) {
    uint8_t channel = tchannel;
    //currentChannel = tchannel;
    uint16_t wr_channel = 0;
    uint16_t rd_channel = 0;

    cc2420_status_t status = 0;

    if(!channel) {
      channel = CC2420_DEF_CHANNEL;
    }


    call CSN.clr();
    call SRFOFF.strobe();
    call CSN.set();

    printf("set to channel=%d currentChannel=%d ",channel, currentChannel);

    atomic {

      if (changeChannel) {
        call CSN.clr();
        call FSCTRL.read(&wr_channel);
        wr_channel = (wr_channel & 0xFE00) | ( ( (channel - 11)*5+357 ) << CC2420_FSCTRL_FREQ );
        call CSN.set();
        call CSN.clr();
        //wr_channel = ( 1 << CC2420_FSCTRL_LOCK_THR ) | ( ( (channel - 11)*5+357 ) << CC2420_FSCTRL_FREQ );
        status = call FSCTRL.write( wr_channel );
        call CSN.set();
      }

      do {
        call CSN.clr();
        call FSCTRL.read(&rd_channel);
        call CSN.set();
      } while (rd_channel & 0x1000);
    }

    call CSN.clr();
    call SRXON.strobe();
    call CSN.set();

    if (rd_channel != wr_channel) {
      printf("Problem: rd_channel=%d(0x%X) != wr_channel=%d(0x%X) && status = 0x%X SPI.owner=%d\n",rd_channel, rd_channel, wr_channel, wr_channel, status, call SpiResource.isOwner());
      call Leds.led0On();
    }
    else {
      call Leds.led0Off();
      if ( TOS_NODE_ID == sinkNodeID || isSink )
        call Leds.led1Toggle();
      //else
      //call Leds.led0Toggle();
      call Leds.led2Toggle();
      currentChannel = channel;
    }

    printfflush();
  }
}
