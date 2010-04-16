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
 Known issues:
        None
 Future changes:
 	None

 ToDo:
 	Lots
        Add WiiChuck to generate commands
*/

#include <Wire.h>
#include <Spi.h>
#include <mirf.h>
#include <nRF24L01.h>

#define BUFFERLENGTH 16 
char commandEnd = '#';

//I2C power pins
int wirePwr = 17;
int wireGnd = 16;

void setup(){

  // Open serial port
  Serial.begin(9600);
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
  
} // end setup()

void loop(){
 /**************************************************** 
 *  
 *  grabs a command form the serial buffer and passes
 *  it onto the HandleCommnad
 *
 ****************************************************/
  int inputLength = 0;
  char inputBuffer[BUFFERLENGTH] = {0};
  do {
    while (!Serial.available()); // wait for input
    inputBuffer[inputLength] = Serial.read(); // read it in
  } while (inputBuffer[inputLength] != commandEnd && ++inputLength < BUFFERLENGTH);

  HandleCommand(inputBuffer, inputLength);
  
} // end loop()


/**************************************************** 
 *  Deal with incoming commnad
 *  for now it just re-transmits via the Mirf
 *
 ****************************************************/
void HandleCommand(char* input, int length) {
  Serial.println(input);
  if (length < 2) { // not a valid command
    return;
  }
  //MIRF to relay command 

  Mirf.setTADDR((byte *)"tank1");
  
  Mirf.send((byte *) input);
  
  while(Mirf.isSending()){
  }
  Serial.println("Finished sending");
} // end HandelCommand(char* input, int length)



