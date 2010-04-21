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
        003 - First WiiChuck Support added
               If holding buttonC reads joyX & joyY and sends move commands via Mirf
               maths is out and doesn't reach top speed,
               chuck only reports between 0-100~ not 0-128 
               
            
               
 Known issues:
        003: WiiChuck maths is out and doesn't reach top speed!!
             Realse of buttonC does not send stop commands so tank continues on lastPacket
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
#include <stdio.h>

#define VERSION_NUM 003
#define BUFFERLENGTH 16 
char commandEnd = '#';

WiiChuck chuck = WiiChuck();
//I2C power pins
int wirePwr = 17;
int wireGnd = 16;

void setup(){

  // Open serial port
  Serial.begin(115200);    // run serial port fast so buffer fills
  Serial.print("Tank_Serv v:");
  Serial.println(VERSION_NUM);
  Serial.println("Hello...");
  
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
 *  grabs form the serial buffer and passes
 *  it onto the Mirf
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
/*    
    Serial.print("Sent:\t");
    Serial.println(outputBuffer);  //not this sends a junk char if ouputBuffer is full and has no NULL
*/
  } // end  if (Serial.available())
 
 /**************************************************** 
 *  Check chuck for c button and gen move commands
 *  
 ****************************************************/
  chuck.update();
  if (chuck.buttonC) {  //hold button C to send move commands, 
    ChuckMove();
  }
 
 
 
} // end loop()


/**************************************************** 
 *  Generate move commands off chuck joysticks
 *  and transmit via Mirf
 *
 ****************************************************/
void ChuckMove() {
  int leftDir = 1;    // varibles to hold motor data
  int rightDir = 1;
  int leftSpeed = 0;
  int rightSpeed = 0; 
  
  int leftMotor = 0;
  int rightMotor = 0;
  int curX = chuck.readJoyX();       // var's to hold translated mouse pos
  int curY = chuck.readJoyY();
  char packet[BUFFERLENGTH + 1] = {0};              // data packet
  char lastPacket[BUFFERLENGTH + 1] = {0};
  //char stopPacket[BUFFERLENGTH] = "L1000#R1000#";     //Stop Packet
  float lastSend;
  
  if (curY > -5 && curY < 5 && curX > -5 && curX < 5) {          // dead stop
    leftMotor = 0;
    rightMotor = 0;
  } else if (curY > -5 && curY < 5 && curX > -5) {                // spin left
    leftMotor = constrain(2 * curX, -200, 200);
    rightMotor = constrain(2 * curX, -200, 200) * -1;
  } else if (curY > -5 && curY < 5 && curX < 5) {                 // spin right
    leftMotor = constrain(2 * curX, -200, 200);
    rightMotor = constrain(2 * curX, -200, 200) * -1;
  } else if (curX > -5 && curX < 5 && curY > 5) {                 // forwards
    leftMotor = constrain(2 * curY, -200, 200);
    rightMotor = constrain(2 * curY, -200, 200);
  } else if (curX > -5 && curX < 5 && curY < -5) {                // backwards
    leftMotor = constrain(2 * curY, -200, 200);
    rightMotor = constrain(2 * curY, -200, 200);
  } else if (curY >= 0) {
    leftMotor = constrain(2 * curY + curX, -200, 200);
    rightMotor = constrain(2 * curY - curX, -200, 200);
  } else if (curY < 0) {
    leftMotor = constrain(2 * curY - curX, -200, 200);
    rightMotor = constrain(2 * curY + curX, -200, 200);  
  }
  
  if (leftMotor >= 0) {
    leftDir = 1;
    leftSpeed = leftMotor * 1.275;
  } else {
    leftDir = 0;
    leftSpeed = (leftMotor * -1) * 1.275 ;
  }
  
  if (rightMotor >= 0) {
    rightDir = 1;
    rightSpeed = rightMotor * 1.275;
  } else {
    rightDir = 0;
    rightSpeed = (rightMotor * -1) * 1.275;
  }
  
 
  // construct data packet
  // java method
  // packet = 'L' + leftDir + leftSpeed + "#R" + rightDir + rightSpeed + '#';
  
  sprintf(packet, "L%d%d#R%d%d#", leftDir, leftSpeed, rightDir, rightSpeed);

/* 
  Serial.print("Chuck X,Y:\t");
  Serial.print(curX);
  Serial.print("\t");
  Serial.println(curY);
  Serial.print("Chuck Packet:\t");
  Serial.println(packet);
*/
  if (packet != lastPacket ){
      if (millis() > lastSend + 100) {    // only transmit packets ever 100ms
        lastSend = millis();
        // lastPacket = packet;     // this dont work in arduino use :-
        memcpy(lastPacket, packet, sizeof(lastPacket)); 


        Mirf.send((byte *) packet);
  
        while(Mirf.isSending()){
        }
        
      }
  }

} // end ChuckMove()


/**************************************************** 
 *  Deal with incoming commnad
 *  for 002 does nothing
 *
 ****************************************************/
void HandleCommand(char* input, int length) {
/*  
  Serial.println(input);
*/  
  if (length < 2) { // not a valid command
    return;
  }

} // end HandelCommand(char* input, int length)



