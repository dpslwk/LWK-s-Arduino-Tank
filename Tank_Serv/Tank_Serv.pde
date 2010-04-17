/****************************************************	
 * sketch = Tank Server
 * LWK's Tank Server
 * Copyright (c)2010 LWK All right reserved
 * Source = lwk.mjhosting.co.uk
 * Target controller = Arduino (freeduino 328)
 * Clock speed = 16 MHz
 * Development platform = Arduino IDE 0018.
 * C compiler = WinAVR from Arduino IDE 0018
 * Programer = Arduino 
 * 
 * 328 Arduino, nRF24L01+, wiichuck
 * 
 ****************************************************/

/*  
History
 	001 - Initial release  
               First hash up of tank server
               Takes a commnad via serial and re-transmits via Mirf
        002 - Mirf update
               Now reads all available data off the serial buffer  
               and transmits in BUFFERLENGHT sieze packets via Mirf
               Can now transmit multiple commands via a singe Mirf packet
            - Updated Serial Speed to 115200
            - Started Adding WiiChuck
 
 Known issues:
        None
 Notes:
 	Max size of any single command is 16 bytes including '#' terminator as set by BUFFERLENGHT
        Commands are in the form xxyyy#
        Where xx is a two char command and yyy is parameter(varible size)
         and # is a command terminator

 ToDo:
 	Lots
        Speed up Mirf data rate
        003: Add WiiChuck to generate commands
*/

#include <Wire.h>
#include <Spi.h>
#include <mirf.h>
#include <nRF24L01.h>
#include <WiiChuckClass.h>


#define BUFFERLENGTH 16 
char commandEnd = '#';

WiiChuck chuck = WiiChuck();
//I2C power pins
int wirePwr = 17;
int wireGnd = 16;

void setup(){

  // Open serial port
  Serial.begin(115200);    // run serial port fast so buffer fills
  // Init I2C & Power Compass 
  pinMode(wirePwr, OUTPUT);
  pinMode(wireGnd, OUTPUT);
  digitalWrite(wireGnd, LOW);
  digitalWrite(wirePwr, HIGH);
  delay(10);
  Wire.begin();
  
  // Setup nRF24
  Mirf.init();  
  Mirf.setRADDR((byte *)"serv1");
  Mirf.payload = BUFFERLENGTH;
  Mirf.config();
  Mirf.setTADDR((byte *)"tank1");
  
  // Start WiiChuck
  chuck.begin();
  chuck.update();
  // chuck.calibrateJoy();
  
} // end setup()

void loop(){
 /**************************************************** 
 *  
 *  grabs form the serial buffer and passes
 *  it onto the Mirf
 *
 ****************************************************/
 int outputLength = 0;
 char outputBuffer[BUFFERLENGTH] = {0};
 if (Serial.available()){
  delay(1); // allow time for buffer to fill
  do {
    outputBuffer[outputLength] = Serial.read(); // read it in
  } while (Serial.available() && ++outputLength < BUFFERLENGTH);

 //MIRF to relay command 
  Mirf.send((byte *) outputBuffer);
  
  while(Mirf.isSending()){
  }
  Serial.print("Sent:\t");
  Serial.println(outputBuffer);
 }
 
 
} // end loop()


/**************************************************** 
 *  Deal with incoming commnad
 *  for 002 does nothing
 *
 ****************************************************/
void HandleCommand(char* input, int length) {
  Serial.println(input);
  if (length < 2) { // not a valid command
    return;
  }

} // end HandelCommand(char* input, int length)



