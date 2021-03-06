/****************************************************	
 * sketch = Tank_Processing
 * LWK's Arduino Tank
 * Copyright (c)2010 LWK All right reserved
 * Source = lwk.mjhosting.co.uk
 * 
 ****************************************************/

/*  
History
 	001 - Initial release  
               First hash up of tank processing client
        002 - Adding touchOSC pass through controls
        
 Known issues:
        None
 Future changes:
 	None

 ToDo:
 	Lots
*/


import processing.serial.*;

// OSC libaries
import oscP5.*;
import netP5.*;
OscP5 oscP5;

Serial Sarduino;       // setup arduino serial instance
PFont fontA;           // font

int leftDirPin = 4;    // varibles to hold arduino pin data
int leftSpeedPin = 3;
int rightDirPin = 6;
int rightSpeedPin = 5; 


int leftDir = 1;    // varibles to hold motor data
int rightDir = 1;
int leftSpeed = 0;
int rightSpeed = 0; 

int leftMotor = 0;
int rightMotor = 0;
int curX = 0;       // var's to hold translated mouse pos
int curY = 0;
String area = "";    
String packet = "";              // data packet
String lastPacket = "";
String stopPacket = "L1000#R1000#";     //Stop Packet
float lastSend;
boolean enabled = false;        // enable/disable serial output to make arduino move
boolean OSCenabled = false;     // enable/disable serial output to make arduino move via OSC
boolean masterserial = true;    // enable/disable serial functions

// OSC xy
boolean xyPadNeedsRedraw = true;
float xPad = 120, yPad = 120; 
int [] xyPadStrip = new int [5];


void setup() 
{
  if (masterserial) {
    Sarduino = new Serial(this, Serial.list()[0], 115200);
  }
  

  size(255, 255); 
  noStroke();
  colorMode(RGB, 255, 255, 255, 100);
  rectMode(CORNER);
  // Load the font. Fonts must be placed within the data 
  // directory of your sketch. A font must first be created
  // using the 'Create Font...' option in the Tools menu.
  fontA = loadFont("CourierNew36.vlw");
  textAlign(LEFT);

  // Set the font and its size (in units of pixels)
  textFont(fontA, 32);
  
  /* start oscP5, listening for incoming messages at port 8000 */
  oscP5 = new OscP5(this,8000);
  
}// end setuo()

void mouseClicked() {
  if (enabled){
    enabled = false;

    lastPacket = stopPacket;
    if (masterserial) {
      Sarduino.write(stopPacket); 
    }
  }else{
    enabled = true;
  }
}// end mouseClicked()

void oscEvent(OscMessage theOscMessage) {
    String addr = theOscMessage.addrPattern();     
//   println(addr);   // uncomment for seeing the raw message
    
    if(addr.indexOf("/3/xy") !=-1 && !(addr.indexOf("/3/xy/z") !=-1)){ // the 8 X Y area
    xPad =  (theOscMessage.get(0).floatValue());
    yPad =  (theOscMessage.get(1).floatValue());
    println(" x = "+xPad+" y = "+yPad);  // uncomment to see x & Y values
    xyPadNeedsRedraw = true;
    }
    if(addr.indexOf("/3/toggle") !=-1){   // the strip at the bottom
      int i = int((addr.charAt(9) )) - 0x30;   // retrns the ASCII number so convert into a real number by subtracting 0x30
      xyPadStrip[i]  = int(theOscMessage.get(0).floatValue());
//      println(" i = "+i);   // uncomment to see index value
      xyPadNeedsRedraw = true;
   }
}// end void oscEvent(OscMessage theOscMessage)

void draw() 
{   
  background(51); 
  if(xyPadStrip[1] == 1){     // if first box is on use osc enable
    OSCenabled = true;
    curX = round(xPad*255) - 127;
    curY = ( round(yPad*255) -127) * -1;
  } else {                    // use mouse of curXY
    OSCenabled = false;

    lastPacket = stopPacket;
    if (masterserial) {
      Sarduino.write(stopPacket); 
    }
    curX = mouseX - 127;
    curY = (mouseY -127) * -1;
  }
  
  
  fill(255, 80);
  rect(117, 0, 20, 255);
  rect(0, 117, 255, 20);


  if (masterserial && Sarduino.available() > 0) {  // If data is available,
    print(Sarduino.readString());         // read it and print to console
  }

  text(mouseX, 10 , 25);
  text(mouseY, 147, 25);
  text(curX, 10 , 50);
  text(curY, 147, 50);
  
  if (curY > -10 && curY < 10 && curX > -10 && curX < 10) {          // dead stop
    leftMotor = 0;
    rightMotor = 0;
  } else if (curY > -10 && curY < 10 && curX > -10) {                // spin left
    leftMotor = constrain(2 * curX, -255, 255);
    rightMotor = constrain(2 * curX, -255, 255) * -1;
  } else if (curY > -10 && curY < 10 && curX < 10) {                 // spin right
    leftMotor = constrain(2 * curX, -255, 255);
    rightMotor = constrain(2 * curX, -255, 255) * -1;
  } else if (curX > -10 && curX < 10 && curY > 10) {                 // forwards
    leftMotor = constrain(2 * curY, -255, 255);
    rightMotor = constrain(2 * curY, -255, 255);
  } else if (curX > -10 && curX < 10 && curY < -10) {                // backwards
    leftMotor = constrain(2 * curY, -255, 255);
    rightMotor = constrain(2 * curY, -255, 255);
  } else if (curY >= 0) {
    leftMotor = constrain(2 * curY + curX, -255, 255);
    rightMotor = constrain(2 * curY - curX, -255, 255);
  } else if (curY < 0) {
    leftMotor = constrain(2 * curY - curX, -255, 255);
    rightMotor = constrain(2 * curY + curX, -255, 255);  
  }
  
  if (leftMotor >= 0) {
    leftDir = 1;
    leftSpeed = leftMotor;
  } else {
    leftDir = 0;
    leftSpeed = leftMotor * -1;
  }
  
  if (rightMotor >= 0) {
    rightDir = 1;
    rightSpeed = rightMotor;
  } else {
    rightDir = 0;
    rightSpeed = rightMotor * -1;
  }
  
 
  // construct data packet


  packet = "L" + leftDir + leftSpeed + "#R" + rightDir + rightSpeed + "#";

  
  if (enabled || OSCenabled){
    text("enabled", 147, 225);
    if (!packet.equals(lastPacket)){
      if (millis() > lastSend + 100) {    // only transmit packets ever 100ms
        lastSend = millis();
        lastPacket = packet;
        if (masterserial) {
          Sarduino.write(packet); 
        }
      }
    }
  }
  
  text(leftDir, 10, 165);
  text(leftSpeed, 50, 165);
  text(rightDir, 147, 165);
  text(rightSpeed, 197, 165);
  text(leftMotor, 40, 200);
  text(rightMotor, 177, 200);
  text(area, 10, 245);  
  fill(0, 126, 255);
  rect(117,128, 10, (leftMotor*-1)/2);
  fill(255, 126, 0);
  rect(127,128, 10, (rightMotor*-1)/2);
 
}// end draw()

