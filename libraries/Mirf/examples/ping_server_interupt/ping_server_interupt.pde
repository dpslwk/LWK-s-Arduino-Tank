/**
 * An Mirf example which copies back the data it recives.
 * While wating the arduino goes to sleep and will be woken up
 * by the interupt pin of the mirf.
 * 
 * Warning: Due to the sleep mode the Serial output donsn't work.
 *
 * Pins:
 * Hardware SPI:
 * MISO -> 12
 * MOSI -> 11
 * SCK -> 13
 *
 * Configurable:
 * CE -> 8
 * CSN -> 7
 */

#include <Spi.h>
#include <mirf.h>
#include <nRF24L01.h>
#include <avr/sleep.h>

void wakeupFunction(){
}

void toSleep(){
  attachInterrupt(0,wakeupFunction,LOW);
  sleep_mode();
  detachInterrupt(0);
}

void setup(){
  Serial.begin(9600);
  
  /*
   * Setup pins / SPI.
   */
   
  Mirf.init();
  
  /*
   * Configure reciving address.
   */
   
  Mirf.setRADDR((byte *)"serv1");
  
  /*
   * Set the payload length to sizeof(unsigned long) the
   * return type of millis().
   *
   * NB: payload on client and server must be the same.
   */
   
  Mirf.payload = sizeof(unsigned long);
  
  /*
   * Write channel and payload config then power up reciver.
   */
   
  Mirf.config();
  
  /*
   * Configure seep mode to save power.
   */
   
  set_sleep_mode(SLEEP_MODE_PWR_DOWN);
  sleep_enable();
  
  Serial.println("Listening..."); 
}

void loop(){
  /*
   * A buffer to store the data.
   */
   
  byte data[Mirf.payload];
  
  /*
   * If a packet has been recived.
   */
  if(Mirf.dataReady()){
    
    
    do{
    
      /*
       * Get load the packet into the buffer.
       */
     
      Mirf.getData(data);
    
      /*
       * Set the send address.
       */
     
      Mirf.setTADDR((byte *)"clie1");
    
      /*
       * Send the data back to the client.
       */
     
      Mirf.send(data);
    
      /*
       * Wait untill sending has finished
       *
       * NB: isSending returns the chip to receving after returning true.
       */
     
      while(Mirf.isSending()){
        delay(100);
      }
      
      /*
       * Are there any more packets in the RX Fifo.
       */
       
    }while(!Mirf.rxFifoEmpty());
    
  }else{
    /* No data - night night. */
    toSleep();
  }    
}
