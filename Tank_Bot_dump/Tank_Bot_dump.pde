/****************************************************	
 * sketch = Tank_Bot_dump
 * LWK's Arduino Tank
 * Copyright (c)2010 LWK All right reserved
 * Source = lwk.mjhosting.co.uk
 * 
 * Quick sketch to repeat incoming Mirf packets back out over the serial
 * Based off the Mirf libary example
 *
 ****************************************************/
#include <Spi.h>
#include <mirf.h>
#include <nRF24L01.h>

void setup(){
  Serial.begin(9600);
  
  /*
   * Setup pins / SPI.
   */
   
  Mirf.init();
  
  /*
   * Configure reciving address.
   */
   
  Mirf.setRADDR((byte *)"tank1");
  
  /*
   * Set the payload length to sizeof(unsigned long) the
   * return type of millis().
   *
   * NB: payload on client and server must be the same.
   */
   
  Mirf.payload = 16;
  
  /*
   * Write channel and payload config then power up reciver.
   */
   
  Mirf.config();
  
  Serial.println("Listening..."); 
}

void loop(){
  /*
   * A buffer to store the data.
   */
   
  char data[16] = {0};
  Serial.print(".");
  /*
   * If a packet has been recived.
   */
  if(Mirf.dataReady()){
    
    do{
      Serial.println("Got packet");
    
      /*
       * Get load the packet into the buffer.
       */
     
      Mirf.getData((byte *) &data);
    
      /*
       * Set the send address.
       */
     
     
     
      Serial.println((char *) &data);
    }while(!Mirf.rxFifoEmpty());
  }
}
