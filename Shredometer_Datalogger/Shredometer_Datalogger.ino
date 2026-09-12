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

// The open datalog file. Opened once in setup(), kept open for the
// whole run, and flushed periodically instead of closed each write.
File dataFile;

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

// Raw-count to m/s^2 conversion for the accelerometer, matching what
// getEvent() does internally: 0.732 mg/LSB (the 16G range's sensitivity)
// scaled to g and then to m/s^2. That sensitivity across a 16-bit output is
// what makes the axis rail near 235.2 m/s^2 -- about 24 g, not the 16 g the
// range's name suggests. Logs bear this out: 61 samples in DL_61 sit on
// 235.20 m/s^2 and none go past it.
const float ACCEL_MPS2_PER_LSB = 0.732f / 1000.0f * 9.80665f;

// How often to write a row. The accelerometer produces a new reading at
// 952 Hz; between rows we read it as fast as I2C allows and keep the
// largest magnitude, so a hard hit can't fall between two logged rows.
//
// Measured on hardware, this buys very little at the current 100 kHz bus
// speed: one readAccel() costs ~946 us, and a row costs ~6.5 ms without the
// SD write (~8.8 ms with it, judging by the 113 Hz seen in real logs). So
// roughly one extra read fits per window. The Burst Samples column reports
// the real figure. The peak-hold is kept because it is correct and becomes
// worth having as soon as the bus gets faster, but on its own it will not
// rescue the peaks.
const unsigned long LOG_INTERVAL_MS = 8;
unsigned long lastLogTime = 0;

// Largest |acceleration|^2 seen since the last logged row, in raw counts
// squared, plus how many reads went into it. Squared counts keep the
// oversampling loop free of floating point and sqrt; both are converted
// once per row. Three axes at full scale give 3 * 32767^2 = 3.22e9, which
// fits a uint32_t (max 4.29e9).
uint32_t burstPeakSq = 0;
uint16_t burstCount = 0;

// Function for setting up the LSM9DS1 sensor
void setupSensor()
{
  // 1.) Set the accelerometer range and output data rate.
  // Pass the data rate explicitly. The library's second parameter defaults
  // to LSM9DS1_ACCELDATARATE_10HZ, so calling setupAccel() with one
  // argument reads as though it asks for 10 Hz. It never got 10 Hz: on the
  // LSM9DS1, whenever the gyroscope is powered on, the accelerometer rate
  // is dictated by ODR_G in CTRL_REG1_G and the ODR_XL bits written here
  // are ignored. begin() sets ODR_G to 952 Hz. Stating 952 Hz here makes
  // the register write agree with what the part actually does.
  //lsm.setupAccel(lsm.LSM9DS1_ACCELRANGE_2G, lsm.LSM9DS1_ACCELDATARATE_952HZ);
  //lsm.setupAccel(lsm.LSM9DS1_ACCELRANGE_4G, lsm.LSM9DS1_ACCELDATARATE_952HZ);
  //lsm.setupAccel(lsm.LSM9DS1_ACCELRANGE_8G, lsm.LSM9DS1_ACCELDATARATE_952HZ);
  lsm.setupAccel(lsm.LSM9DS1_ACCELRANGE_16G, lsm.LSM9DS1_ACCELDATARATE_952HZ);
  
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

void writeDataToFile(String dataString) {
  // write to the already-open file. dataString already ends in "\n",
  // so use print(), not println(), to avoid a doubled line ending.
  // No per-sample serial echo: nothing reads it live at this sample
  // rate, and it only costs loop time.
  if (dataFile) {
    dataFile.print(dataString);
  }
  // if the file isn't open, pop up an error:
  else {
    Serial.println("error: datalog file not open");
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

// Write a shred score into a pair of adjacent digit positions.
// Below 10, shows one decimal place (e.g. "7.3"). At 10 and above, the
// display can't fit both a whole number >9 and a decimal digit, so it
// drops the decimal and shows the rounded whole number instead (e.g.
// "12"), clamped to the two-digit max of 99.
void writeScoreDigits(uint8_t posInt, uint8_t posDec, float score) {
  boolean drawDot = true;
  if (score < 10.0) {
    uint16_t intDigit = uint16_t(score);
    uint16_t decDigit = uint16_t(score * 10) % 10;
    matrix.writeDigitNum(posInt, intDigit, drawDot);
    matrix.writeDigitNum(posDec, decDigit, !drawDot);
  } else {
    uint16_t rounded = uint16_t(score + 0.5);
    if (rounded > 99) rounded = 99;
    matrix.writeDigitNum(posInt, rounded / 10, !drawDot);
    matrix.writeDigitNum(posDec, rounded % 10, !drawDot);
  }
}

// Function to update the LED matrix to display shred scores
void updateLedMatrix() {
  writeScoreDigits(0, 1, instShredScore);
  matrix.drawColon(true);
  writeScoreDigits(3, 4, maxShredScore);
  matrix.writeDisplay();
}

void setup() {
  // Open serial communications and wait for port to open:
  Serial.begin(115200);
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

  // Do NOT raise the I2C clock to 400 kHz here. Both chips support it on
  // paper, but on this wiring it wedges the bus: measured twice on real
  // hardware, the first readAccel() after Wire.setClock(400000) never
  // returns, and only a power cycle clears it. The likely cause is rise
  // time: the cable to the bar-mounted display puts about a metre of wire
  // across the bus, and the two breakouts' pull-ups in parallel (~5k) cannot
  // meet fast mode's 300 ns rise time into that capacitance. 2.2k pull-ups
  // fix it. See "Sensor limits" for the numbers.

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

  // Open the file once. It stays open for the rest of the run.
  dataFile = SD.open(fileName, FILE_WRITE);
  if (!dataFile) {
    Serial.println("error opening datalog");
    // don't do anything more
    while (1);
  }

  // Write table header string
  // The Accel/Mag/Gyro columns are a single instantaneous reading, as before.
  // Peak |a| is the largest acceleration magnitude seen across every
  // oversampled read since the previous row, and Burst Samples is how many
  // reads that covers.
  String headerString = "Time Elapsed (ms), Accel X (m/s^2), Accel Y (m/s^2), Accel Z (m/s^2), Mag X (uT), Mag Y (uT), Mag Z (uT), Gyro X (rad/s), Gyro Y (rad/s), Gyro Z (rad/s), Peak |a| (m/s^2), Burst Samples\n";
  writeDataToFile(headerString);

  // Get ten sensor events that are not recorded, to clear the buffer
  for (int ii=0; ii<10; ii++){
    lsm.getEvent(&a, &m, &g, &temp); 
  }

  lastLogTime = millis();
}

void loop() {
  // Oversample the accelerometer. It produces a new reading at 952 Hz while
  // rows go out near 125 Hz, so reading it once per row would show us about
  // one sample in eight and miss the peak of most impacts. Read it as fast
  // as the bus allows and keep the largest magnitude seen since the last
  // row. Integer math only: this runs several thousand times a second.
  lsm.readAccel();
  int32_t rawX = (int32_t)lsm.accelData.x;
  int32_t rawY = (int32_t)lsm.accelData.y;
  int32_t rawZ = (int32_t)lsm.accelData.z;
  uint32_t magSq = (uint32_t)(rawX * rawX)
                 + (uint32_t)(rawY * rawY)
                 + (uint32_t)(rawZ * rawZ);
  if (magSq > burstPeakSq) {
    burstPeakSq = magSq;
  }
  burstCount++;

  // Everything below runs once per logged row. Until the interval is up,
  // go back and take another accelerometer reading.
  unsigned long now = millis();
  if (now - lastLogTime < LOG_INTERVAL_MS) {
    return;
  }
  lastLogTime = now;

  // Convert the burst peak to m/s^2. One sqrt per row, not per read.
  float peakMps2 = sqrt((float)burstPeakSq) * ACCEL_MPS2_PER_LSB;

  // Increment the counter
  counter+=1;
  
  // make a string for assembling the data to log:
  String dataString = "";

  // Append the time since code start to the string
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
  dataString += g.gyro.z;  dataString += ",";
  dataString += peakMps2;  dataString += ",";
  dataString += burstCount;  dataString += "\n";

  // Write the dataString to the file
  writeDataToFile(dataString);

  // Reset the burst now that it has been written out
  burstPeakSq = 0;
  burstCount = 0;

  // Update the varShredScore from the burst peak, not from the single
  // instantaneous reading logged above, so the display shows the hardest
  // hit in the window rather than whichever moment we happened to sample.
  varShredScore = peakMps2/9.8;

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
    // Flush buffered writes to the card. This caps data loss on power
    // loss to the last maxCounterVal samples.
    dataFile.flush();
  }
  
}
