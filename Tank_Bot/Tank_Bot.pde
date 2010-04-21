/****************************************************	
 * sketch = Tank Bot
 * LWK's Tank Bot
 * Copyright (c)2010 LWK All right reserved
 * Source = lwk.mjhosting.co.uk
 * Target controller = Arduino (freeduino 328)
 * Clock speed = 16 MHz
 * Development platform = Arduino IDE 0018.
 * C compiler = WinAVR from Arduino IDE 0018
 * Programer = Arduino 
 * 
 * 328 Arduino, HMC6352, nRF24L01+, Arduino Tank, SN754410 
 * 
 ****************************************************/

/*  
History
 	001 - Initial release  
               First hash up of tank controler
               takes command in the form xxyyy#
               where xx is a two char command and yyy is parameter(varible size)
               and # is a command terminator
               
               reads commands via serial and Mirf
               current list is
                 L0xxx#    left motor back by pwm(0-255)
                 L1xxx#    left motor forwards by pwm(0-255)
                 R0xxx#    right motor back by pwm(0-255)
                 R1xxx#    right motor forwards by pwm(0-255)
                 HR#       Read Heading from HMC6352 and output to serial
        002 - Mirf update
                Update to the if(Mirf.dataReady()) routine
                Can now take multiple commands via a singe Mirf packet
                Max size of any single command is 16 bytes including '#' terminator
        003 - Adding Basic GP2D12 read and first Set Moves using compass
                Added suport for comands split over multiple Mirf packets
                Added Local WiiChuck Support
                New commands
                DR#        Read Distance from GP2D12 and output to serial
                HS#        Set Heading to xxx Degeres using a right spin
                SMyyxxx#   Set Move commands
                  SRxxx#   Spin Right by xxx degeres (0-359)
                  SLxxx#   Spin Left by xxx degeres  (0-359
                
 Known issues:
        002: Mirf truncates Commands that are split over multiple packets  
            
 Notes:
 	Max size of any single command is 16 bytes including '#' terminator as set by BUFFERLENGHT
        Commands are in the form xxyyy#
        Where xx is a two char command and yyy is parameter(varible size)
         and # is a command terminator


 ToDo:
 	Lots
        Speed up Mirf data rate and enable auto ack
        HR# DR# return via Mirf
        
 
*/

#include <Wire.h>
#include <Spi.h>
#include <mirf.h>
#include <nRF24L01.h>
#include <WiiChuckClass.h>

#define VERSION_NUM 003
#define USE_MIRF


/****************************************************	
 *  setup HMC6352 Compass global varaibles
 * 
 ****************************************************/
/****************************************************	
 * Shift the HMC6352 Compass device's documented slave address (0x42) 1 bit right
 * This compensates for how the TWI library only wants the
 * 7 most significant bits (with the high bit padded with 0)
 * This results in 0x21 as the address to pass to TWI
 ****************************************************/
int HMC6352Address = 0x21;


/****************************************************	
 *  setup SN754410 Motor varaibles
 * 
 ****************************************************/
// varibles to hold arduino pin data
int leftDirPin = 4;    
int leftSpeedPin = 3;
int rightDirPin = 6;
int rightSpeedPin = 5; 
// varibles to hold motor data
int leftDir = 1;    
int rightDir = 1;
int leftSpeed = 0;
int rightSpeed = 0; 
int leftMotor = 0;
int rightMotor = 0;

//buffer length for incoming serial and mirf packets
#define BUFFERLENGTH 16 

char commandEnd = '#';

//char inputBuffer[BUFFERLENGTH] = {0};

WiiChuck chuck = WiiChuck();

//I2C power pins
int wirePwr = 17;
int wireGnd = 16;

// GP2D12 Pin
int frontIRPin = 0;   //Analogue Pin A0

void setup(){

  // Open serial port
  Serial.begin(115200);
  Serial.print("Tank_Bot v:");
  Serial.println(VERSION_NUM);
  Serial.println("Hello...");
  // Init I2C & Power Compass 
  pinMode(wirePwr, OUTPUT);
  pinMode(wireGnd, OUTPUT);
  digitalWrite(wireGnd, LOW);
  digitalWrite(wirePwr, HIGH);
  delay(10);
  //Join I2c as Master
  Wire.begin();
  
  // Setup nRF24
  Mirf.init();  
  Mirf.setRADDR((byte *)"tank1");
  Mirf.payload = BUFFERLENGTH;
  Mirf.config();
  
    
  // Start WiiChuck
  chuck.begin();
  chuck.update();
  // chuck.calibrateJoy();
  
  // SN754410 Motor Pins
  pinMode(leftDirPin, OUTPUT);
  pinMode(leftSpeedPin, OUTPUT);
  pinMode(rightDirPin, OUTPUT);
  pinMode(rightSpeedPin, OUTPUT);
  
   
} // end setup()

void loop(){

/**************************************************** 
 *  orignaly borrowed from projectallusion.com
 *
 *
 ****************************************************/
  // get a command string form the serial port
// get a command string form the serial port
  int inputLength = 0;
  char inputBuffer[BUFFERLENGTH] = {0};

  if(Mirf.dataReady()){
//    Serial.println("Mirf dataready");
    
    do{
      Mirf.getData((byte *) &inputBuffer);
    }while(!Mirf.rxFifoEmpty());
/*
    Serial.print("Buffer: ");
    Serial.println(inputBuffer);
*/  
  
    /***********************************************************************
     * end is always == BUFFERLENGTH as sizeof()gets size of array. 
     * dont have a function like WString: 
     * int length() Returns the number of characters in the string
     **********************************************************************/
    int endstring = sizeof(inputBuffer);
    int hashpos = 0;
    int charpos = 0;
    char commandstring[BUFFERLENGTH];
    
    while ( hashpos <= endstring) {
      // TURE if not past end of array and NULL :: Prevent checking for null when hashpos has exceeded end of string
      if (hashpos < endstring && inputBuffer[hashpos] == 0) {           
         break;                                // found null terminator, drop out early

      // TRUE if work throught eniter BUFFERLENGTH of the array and not found NULL or #
      } else if (hashpos == endstring) {
        /***************************************************
        * past end of array and not yet found a #
        * command split over packets?????
        * get another packet and work thought that???
        * May need to check that there is data to be got
        * otherwise get another bufferfull
        ***************************************************/
        
        while(!Mirf.dataReady()); // loop till next packet arrives if not allready there
        do{
          Mirf.getData((byte *) &inputBuffer);
        }while(!Mirf.rxFifoEmpty());	// Get a new buffer load
/*          
        Serial.print("Buffer: ");
        Serial.println(inputBuffer);
*/
        hashpos = 0;	// Reset Hashpos to start at beginning of new buffer but leave charpos as this is for the commandstring that is still being built
        
      // TRUE if not past end of the array and not #
      } else if (hashpos != endstring && inputBuffer[hashpos] != commandEnd) {  
        commandstring[charpos] = inputBuffer[hashpos];
        ++charpos;
        ++hashpos;
  
      } else if (inputBuffer[hashpos] == commandEnd ) {
        commandstring[charpos] = 0;
  
        // debug prints
/*        Serial.print("Command: "); 
        Serial.println(commandstring);
        Serial.print(hashpos);
        Serial.print("\t");
        Serial.println(charpos);
*/  
        HandleCommand(commandstring, charpos + 1);         // Add 1 to charpos as this tells HandleCommand the correct number of characters.
  
        charpos = 0;
        ++hashpos;
  
      } // end if else
    } // end while
  } // if(Mirf.dataReady())
  
  if (Serial.available()) {
//    Serial.println("Serial dataready");
    do {
      while (!Serial.available()); // wait for input
      inputBuffer[inputLength] = Serial.read(); // read it in
    } while (inputBuffer[inputLength] != commandEnd && ++inputLength < BUFFERLENGTH);

    inputBuffer[inputLength] = 0; //  add null terminator
/*
    Serial.print("Buffer: ");
    Serial.println(inputBuffer);
    Serial.print("Got length of ");
    Serial.print(inputLength);
*/
    HandleCommand(inputBuffer, inputLength);
  } //end if (Serial.available())
  
 /**************************************************** 
 *  Check chuck for c button and gen move commands
 *  
 ****************************************************/
  chuck.update();
  if (chuck.buttonC) {  //hold button C to send move commands, 
    ChuckMove();
  } // end if (chuck.buttonC)
  
  
} // end loop()


/**************************************************** 
 *  orignaly borrowed from projectallusion.com
 *  process a command string
 *
 ****************************************************/
void HandleCommand(char* input, int length) {
  Serial.println(input);
  if (length < 2) { // not a valid command
    return;
  }
  int value = 0;
  // calculate number following command
  if (length > 2) {
    value = atoi(&input[2]);
  }
  int* command = (int*)input;
  // check commands
  // note that the two bytes are swapped, ie 'RA' means command AR
  switch(*command) {
    case '1L':
      // motor A forwards
      digitalWrite(leftDirPin, HIGH);
      analogWrite(leftSpeedPin, value);
      break;
    case '0L':
      // motor A reverse
      digitalWrite(leftDirPin, LOW);
      analogWrite(leftSpeedPin, value);
      break;
    case '1R':
      // motor B forwards
      digitalWrite(rightDirPin, HIGH);
      analogWrite(rightSpeedPin, value);
      break;
    case '0R':
      // motor B reverse
      digitalWrite(rightDirPin, LOW);
      analogWrite(rightSpeedPin, value);
      break;
    case 'MS':
      // Set move commands
      HandelSetMove(input);
      break;
    case 'RH':
      // read Heading
      int lastHeading;
      lastHeading = FetchHeading();
      Serial.print("Current heading: ");
      Serial.print(int (lastHeading / 10));     // The whole number part of the heading
      Serial.print(".");
      Serial.print(int (lastHeading % 10));     // The fractional part of the heading
      Serial.println(" degrees");
      break;
    case 'SH':
      // set heading
      SetHeading(value, 1, false);
      break;
    case 'RD':
      // read Distance
      float lastDistance;
      lastDistance = FetchDistance(frontIRPin);
      Serial.print("Current Distance: ");
      Serial.print(lastDistance, DEC);
      Serial.println("cm");
      break;
    default:
      break;
  } 
} // end HandelCommand(char* input, int length)


 /**************************************************** 
 *  sort out Set moves
 *  had to pull from main HandelCommand, in order to 
 *  sort out sub command and switch
 ****************************************************/
void HandelSetMove(char* input) {
  Serial.print("Set Move: ");
  Serial.println(input);
  int value = 0;
  value = atoi(&input[4]);
  char subCommand[3] ={0};
  subCommand[0] = input[2];
  subCommand[1] = input[3];
  int* command = (int*) subCommand;
  switch(*command) {
    case 'RS':
      // Spin Right
      Serial.println(" Spin Right");
      SetHeading(value, 1, true);
      break; 
    case 'LS': 
      // Spin Left
      Serial.println(" Spin Left");
      SetHeading(value, 0, true);
      break; 
    default:
      break;
  }  
} // end void HandelSetMove(char* input)
  
  
/**************************************************** 
 *  orignaly borrowed from HMC6352 example on 
 *  Arduino::Playground
 *  
 *  Reads Heading form HMC6352 and returns as int
 *
 ****************************************************/
int FetchHeading() {
  byte headingData[2];
  headingData[0] = 0;
  headingData[1] = 0;
  int i;
  int headingValue;
   // Send a "A" command to the HMC6352
  // This requests the current heading data
  Wire.beginTransmission(HMC6352Address);
  Wire.send("A");              // The "Get Data" command
  //Serial.println("sent A");
  //Serial.println(HMC6352Address, HEX);
  Wire.endTransmission();
  delay(10);                   // The HMC6352 needs at least a 70us (microsecond) delay
  // after this command.  Using 10ms just makes it safe
  // Read the 2 heading bytes, MSB first
  // The resulting 16bit word is the compass heading in 10th's of a degree
  // For example: a heading of 1345 would be 134.5 degrees
  Wire.requestFrom(HMC6352Address, 2);        // Request the 2 byte heading (MSB comes first)
  i = 0;
  while(Wire.available() && i < 2)
  { 
    headingData[i] = Wire.receive();
//    Serial.println("Got It!");
    i++;
  }
  headingValue = headingData[0]*256 + headingData[1];  // Put the MSB and LSB together
/*
  Serial.print("Current heading: ");
  Serial.print(int (headingValue / 10));     // The whole number part of the heading
  Serial.print(".");
  Serial.print(int (headingValue % 10));     // The fractional part of the heading
  Serial.println(" degrees");
*/
  
  return headingValue;
} // end int fetchHeading()



/**************************************************** 
 *  orignaly borrowed from read_gp2d12_range on 
 *  Arduino::Playground
 *  
 *  Reads Distance form GP2D12 and returns as float
 *
 ****************************************************/
float FetchDistance(byte pin) {
	int tmp;

	tmp = analogRead(pin);
	if (tmp < 3)
		return -1; // invalid value

	return (6787.0 /((float)tmp - 3.0)) - 4.0;
} // end float FetchDistance(byte pin)

/**************************************************** 
 *  Generate move commands off chuck joysticks
 *  
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
    digitalWrite(leftDirPin, HIGH);
    analogWrite(leftSpeedPin, leftMotor * 1.275);
  } else {
    digitalWrite(leftDirPin, LOW);
    analogWrite(leftSpeedPin, (leftMotor * -1) * 1.275);
  }
  
  if (rightMotor >= 0) {
    digitalWrite(rightDirPin, HIGH);
    analogWrite(rightSpeedPin, rightMotor * 1.275);
  } else {
    digitalWrite(rightDirPin, LOW);
    analogWrite(rightSpeedPin, (rightMotor * -1) * 1.275);
  }
  
 } // end void ChuckMove()
 
 /**************************************************** 
 *  sets robot heading using half speed spin in either 
 *  dir, (1= right, 0= left)
 *   
 *  
 *
 ****************************************************/
void SetHeading(int targetHeading, int dir, int offset) {
  int currentHeading;
  currentHeading = FetchHeading() / 10; 
  if(offset && dir == 1) {
    targetHeading = currentHeading + targetHeading;
    if(targetHeading >= 360)
      targetHeading -= 360;
  } else if(offset && dir == 0) {
    targetHeading = currentHeading - targetHeading;
    if(targetHeading < 0){
      targetHeading *= -1;
      targetHeading = 360 - targetHeading;
    }
  }
  Serial.print("Current Heading: ");
  Serial.println(currentHeading);
  Serial.print("Target Heading: ");
  Serial.println(targetHeading);
  switch(dir) {
    case 1:  // spin Right
      digitalWrite(leftDirPin, HIGH);
      digitalWrite(rightDirPin, LOW);
      break;
    case 0:  // spin Left
      digitalWrite(leftDirPin, LOW);
      digitalWrite(rightDirPin, HIGH);
      break;
    default:
      break;
  }
  analogWrite(leftSpeedPin, 128);
  analogWrite(rightSpeedPin, 128);
  do{
    currentHeading = FetchHeading() / 10; 
  }while(currentHeading != targetHeading);
  analogWrite(leftSpeedPin, 0);
  analogWrite(rightSpeedPin, 0);
  
  Serial.print("Final Heading: ");
  Serial.println(FetchHeading() / 10 ,DEC);
} // end void SetHeading(int degres, char* dir = '0')
