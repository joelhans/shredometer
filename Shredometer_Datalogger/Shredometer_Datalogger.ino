/*
  Shredometer Datalogger
  Written by: Ryan T Cutshall
  Date of last update: 17 SEP 2022
*/

#include <Wire.h>
#include <SPI.h>
#include <SD.h>
#include <Adafruit_LSM9DS1.h>
#include <Adafruit_Sensor.h>  // not used in this file but required! <-- TO DO: Is this true?
#include <Adafruit_GFX.h>
#include "Adafruit_LEDBackpack.h"

// Set the chipSelect pin to pin 10
const int chipSelect = 10;

// Set the startButtonPin
const int startButtonPin = 2;

// Initialize some variables for keeping track of button states
int startButtonState = 0;

// Initialize the LSM9DS1 object, assign to lsm variable
Adafruit_LSM9DS1 lsm = Adafruit_LSM9DS1();

// Initialize vectors for sensor data
sensors_event_t a, m, g, temp;

// Initialize a string for the fileName
String fileName = "";

// Initialize the LED matrix
Adafruit_7segment matrix = Adafruit_7segment();

// Initialze the variable, instantaneous, and max shred scores
float varShredScore = 0.0;
float instShredScore = 0.0;
float maxShredScore = 0.0;

// Initialize instShredScore update counter and max counter value
int counter = 0;
int maxCounterVal = 15;

// Initialize a variable to keep track of datalog start time
unsigned long startTime;

// Function for setting up the LSM9DS1 sensor
void setupSensor()
{
  // 1.) Set the accelerometer range
  //lsm.setupAccel(lsm.LSM9DS1_ACCELRANGE_2G);
  lsm.setupAccel(lsm.LSM9DS1_ACCELRANGE_4G);
  //lsm.setupAccel(lsm.LSM9DS1_ACCELRANGE_8G);
  //lsm.setupAccel(lsm.LSM9DS1_ACCELRANGE_16G);
  
  // 2.) Set the magnetometer sensitivity
  //lsm.setupMag(lsm.LSM9DS1_MAGGAIN_4GAUSS);
  lsm.setupMag(lsm.LSM9DS1_MAGGAIN_8GAUSS);
  //lsm.setupMag(lsm.LSM9DS1_MAGGAIN_12GAUSS);
  //lsm.setupMag(lsm.LSM9DS1_MAGGAIN_16GAUSS);

  // 3.) Setup the gyroscope
  //lsm.setupGyro(lsm.LSM9DS1_GYROSCALE_245DPS);
  lsm.setupGyro(lsm.LSM9DS1_GYROSCALE_500DPS);
  //lsm.setupGyro(lsm.LSM9DS1_GYROSCALE_2000DPS);
}

void writeDataToFile(String fileName, String dataString) {
  // open the file
  File dataFile = SD.open(fileName, FILE_WRITE);

  // if the file is available, write to it, then close the file:
  if (dataFile) {
    dataFile.println(dataString);
    dataFile.close();
    // print to the serial port too:
    Serial.println(dataString);
  }
  // if the file isn't open, pop up an error:
  else {
    Serial.println("error opening datalog");
  }
}

void setFileName() {
  // loop through file names, until we find one that doesn't already exist
  int ii=0;
  fileName = "DL_" + String(ii) + ".TXT";
  while (SD.exists(fileName)) {
    ii+=1;
    fileName = "DL_" + String(ii) + ".TXT";
  }
  Serial.println("Writing data to " + fileName);
}

// Function to initialize the LED matrix to display 0.0:0.0
void initLedMatrix(int initValType) {
  matrix.begin(0x70);
  boolean drawDot = true;
  if (initValType == 0){
    uint16_t uint16_val = 0;
    matrix.writeDigitNum(0, uint16_val, drawDot);
    matrix.writeDigitNum(1, uint16_val, !drawDot);
    matrix.drawColon(true);
    matrix.writeDigitNum(3, uint16_val, drawDot);
    matrix.writeDigitNum(4, uint16_val, !drawDot);
  }
  if (initValType == 1){
    uint16_t uint16_val = 1;
    matrix.writeDigitNum(0, uint16_val, drawDot);
    matrix.writeDigitNum(1, uint16_val, !drawDot);
    matrix.drawColon(true);
    matrix.writeDigitNum(3, uint16_val, drawDot);
    matrix.writeDigitNum(4, uint16_val, !drawDot);
  }
  if (initValType == 2){
    uint16_t uint16_val = 2;
    matrix.writeDigitNum(0, uint16_val, drawDot);
    matrix.writeDigitNum(1, uint16_val, !drawDot);
    matrix.drawColon(true);
    matrix.writeDigitNum(3, uint16_val, drawDot);
    matrix.writeDigitNum(4, uint16_val, !drawDot);
  }
  matrix.writeDisplay();
}

// Function to update the LED matrix to display shred scores
void updateLedMatrix() {
  boolean drawDot = true;
  uint16_t val4 = uint16_t(maxShredScore*10) % 10;
  uint16_t val3 = maxShredScore;
  matrix.writeDigitNum(4, val4, !drawDot);
  matrix.writeDigitNum(3, val3, drawDot);
  matrix.drawColon(true);
  uint16_t val1 = uint16_t(instShredScore*10) % 10;
  uint16_t val0 = instShredScore;
  matrix.writeDigitNum(1, val1, !drawDot);
  matrix.writeDigitNum(0, val0, drawDot);
  matrix.writeDisplay();
}

void setup() {
  // Open serial communications and wait for port to open:
  Serial.begin(9600);
  while (!Serial) {
    ; // wait for serial port to connect. Needed for native USB port only
  }

  // Display 2.2:2.2 to the LED display to indicate that sensor is initializing
  int initVal = 2;
  initLedMatrix(initVal);

  // Try to initialise the LSM9DS1 and warn if we couldn't detect the chip
  if (!lsm.begin())
  {
    Serial.println("Oops ... unable to initialize the LSM9DS1. Check your wiring!");
    // don't do anything more
    while (1);
  }
  Serial.println("Found LSM9DS1 9DOF");

  // Set the default scaling we want to use with the LSM9DS1 using the setupSensor function defined above
  setupSensor();

  // Display 1.1:1.1 to the LED display to indicate that sensor is initializing
  initVal = 1;
  initLedMatrix(initVal);

   // Print SD card initialization message
  Serial.print("Initializing SD card...");

  // see if the SD card is present and can be initialized:
  while (!SD.begin(chipSelect)) {
    Serial.println("Card initialization failed, retry in 1 second...");
    delay(1000);
  }
  Serial.println("card initialized.");

  // Display 0.0:0.0 to the LED display to indicate that we're waiting for button press
  initVal = 0;
  initLedMatrix(initVal);

  // Wait to start until button is pressed
  Serial.println("Waiting for start button press...");
  pinMode(startButtonPin, INPUT);
  while( startButtonState == LOW){
    startButtonState = digitalRead(startButtonPin);
    delay(100);
  }
  
  Serial.println("Start button pressed! Starting data log.");
  startTime = millis();

  // Find a unique file name
  setFileName();

  // Write table header string
  String headerString = "Time Elapsed (ms), Accel X (m/s^2), Accel Y (m/s^2), Accel Z (m/s^2), Mag X (uT), Mag Y (uT), Mag Z (uT), Gyro X (rad/s), Gyro Y (rad/s), Gyro Z (rad/s)\n";
  writeDataToFile(fileName, headerString);

  // Get ten sensor events that are not recorded, to clear the buffer
  for (int ii=0; ii<10; ii++){
    lsm.getEvent(&a, &m, &g, &temp); 
  }
}

void loop() {
  // Increment the counter
  counter+=1;
  
  // make a string for assembling the data to log:
  String dataString = "";

  // Get the time since code start
  unsigned long now = millis();
  // Append to string
  dataString += String(now - startTime);
  dataString += ",";

  // Get a new sensor event 
  lsm.getEvent(&a, &m, &g, &temp); 

  // Append the data to the dataString
  dataString += a.acceleration.x;  dataString += ",";
  dataString += a.acceleration.y;  dataString += ",";
  dataString += a.acceleration.z;  dataString += ",";
  dataString += m.magnetic.x;  dataString += ",";
  dataString += m.magnetic.y;  dataString += ",";
  dataString += m.magnetic.z;  dataString += ",";
  dataString += g.gyro.x;  dataString += ",";
  dataString += g.gyro.y;  dataString += ",";
  dataString += g.gyro.z;  dataString += "\n";

  // Write the dataString to the file
  writeDataToFile(fileName, dataString);

  // Update the varShredScore
  varShredScore = sqrt(sq(a.acceleration.x) + sq(a.acceleration.y) + sq(a.acceleration.z))/9.8;

  // If varShredScore is greater than instShredScore, update instShredScore
  if (varShredScore > instShredScore){
    instShredScore = varShredScore;
  }

  // If counter has reached max value, update instShredScore and maxShredScore
  if (counter == maxCounterVal){
    if (instShredScore > maxShredScore){
      maxShredScore = instShredScore;
    }
    updateLedMatrix();
    // Reset instShredScore
    instShredScore = 0.0;
    // Reset the counter
    counter = 0;
  }
  
}
