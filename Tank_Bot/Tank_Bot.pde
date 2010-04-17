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
                 L0xxx#    left motor back by pwm(xxx)
                 L1xxx#    left motor forwards by pwm(xxx)
                 R0xxx#    right motor back by pwm(xxx)
                 R1xxx#    right motor forwards by pwm(xxx)
                 HR#       Read Heading from HMC6352 and output to serial
        002 - Mirf update
                Update to the if(Mirf.dataReady()) routine
                Can now take multiple commands via a singe Mirf packet
                Max size of any single command is 16 bytes including '#' terminator
                
                
 Known issues:
        002: Mirf truncates Commands that are split over multiple packets
            
 Notes:
 	Max size of any single command is 16 bytes including '#' terminator as set by BUFFERLENGHT
        Commands are in the form xxyyy#
        Where xx is a two char command and yyy is parameter(varible size)
         and # is a command terminator


 ToDo:
 	Lots
        Speed up Mirf data rate
        003: Add suport for comands split over multiple Mirf packets
 
*/

#include <Wire.h>
#include <Spi.h>
#include <mirf.h>
#include <nRF24L01.h>

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

//I2C power pins
int wirePwr = 17;
int wireGnd = 16;

void setup(){

  // Open serial port
  Serial.begin(9600);
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
    Serial.println("Mirf dataready");
    
    do{
      Mirf.getData((byte *) &inputBuffer);
    }while(!Mirf.rxFifoEmpty());
    Serial.print("Buffer: ");
    Serial.println(inputBuffer);
  
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
  
      // TRUE if not past end of the array and not #
      } else if (hashpos != endstring && inputBuffer[hashpos] != commandEnd) {  
        commandstring[charpos] = inputBuffer[hashpos];
        ++charpos;
        ++hashpos;
  
      // TRUE if work throught eniter BUFFERLENGTH of the array and not found NULL or #
      } else if (hashpos == endstring) {
        /***************************************************
        * past end of array and not yet found a #
        * command split over packets?????
        * get another packet and work thought that???
        * or just truncate command and HandleCommand with what we have?
        ***************************************************/
  
        // just truncate for now
        commandstring[charpos] = 0;
        HandleCommand(commandstring, charpos + 1);         // Add 1 to charpos as this tells HandleCommand the correct number of characters.
        break;                                 // worked all of inputBuffer so break
  
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
  
        //commandstring = 0;                         // dont need to NULL the comand string as long as its all over written next loop and we add NULL
        charpos = 0;
  
        //  if (hashpos == endstring) ++hashpos;                 // dont need this if() as split the else if() above but kept the below
        ++hashpos;
  
      } // end if else
    } // end while
  } // if(Mirf.dataReady())
  
  if (Serial.available()) {
    Serial.println("Serial dataready");
    do {
      while (!Serial.available()); // wait for input
      inputBuffer[inputLength] = Serial.read(); // read it in
    } while (inputBuffer[inputLength] != commandEnd && ++inputLength < BUFFERLENGTH);

    inputBuffer[inputLength] = 0; //  add null terminator

    Serial.print("Buffer: ");
    Serial.println(inputBuffer);
    Serial.print("Got length of ");
    Serial.print(inputLength);

    HandleCommand(inputBuffer, inputLength);
  } //end if (Serial.available())
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
      analogWrite(leftSpeedPin, value);
      digitalWrite(leftDirPin, HIGH);
      break;
    case '0L':
      // motor A reverse
      analogWrite(leftSpeedPin, value);
      digitalWrite(leftDirPin, LOW);
      break;
    case '1R':
      // motor B forwards
      analogWrite(rightSpeedPin, value);
      digitalWrite(rightDirPin, HIGH);
      break;
    case '0R':
      // motor B reverse
      analogWrite(rightSpeedPin, value);
      digitalWrite(rightDirPin, LOW);
      break;
    case 'RH':
      // read heading
      Serial.println(FetchHeading(), DEC);
      break;
    default:
      break;
  } 
} // end HandelCommand(char* input, int length)


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
    Serial.println("Got It!");
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
} // end fetchHeading()

