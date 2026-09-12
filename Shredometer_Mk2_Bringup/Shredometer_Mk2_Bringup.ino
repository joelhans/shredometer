// Shredometer Mk2 bring-up
// ------------------------
// Tests each subsystem on the XIAO nRF52840 Sense, one at a time, and
// reports PASS or FAIL for each over USB serial. Wire one subsystem,
// flash this, read the report, wire the next. Nothing here logs a
// ride; that is Shredometer_Mk2 (to come).
//
// Board:  Seeed XIAO nRF52840 Sense
// FQBN:   Seeeduino:nrf52:xiaonRF52840Sense
// Build:  arduino-cli compile --fqbn Seeeduino:nrf52:xiaonRF52840Sense Shredometer_Mk2_Bringup
// Upload: arduino-cli upload -p /dev/ttyACM0 --fqbn Seeeduino:nrf52:xiaonRF52840Sense Shredometer_Mk2_Bringup
//
// See docs/mk2_build.md for the wiring table these pins come from.

#include <SPI.h>
#include <Wire.h>
#include <Adafruit_ADXL375.h>
#include <SdFat.h>
#include <Adafruit_LEDBackpack.h>

// ---------------- Pins (XIAO D numbers) ----------------
// Hardware SPI is fixed: D8 SCK, D9 MISO, D10 MOSI.
// Hardware I2C is fixed: D4 SDA, D5 SCL.
const uint8_t PIN_ADXL_CS   = 3;   // ADXL375 chip select
const uint8_t PIN_ADXL_INT1 = 0;   // ADXL375 INT1 (data ready), optional for bring-up
const uint8_t PIN_SD_CS     = 2;   // microSD chip select
const uint8_t PIN_BUTTON    = 1;   // start button, to GND, INPUT_PULLUP
const uint8_t PIN_HICHG     = PIN_CHARGING_CURRENT;  // P0.13: LOW = 100 mA charge, input = 50 mA

const uint8_t DISPLAY_ADDR  = 0x70;

// ---------------- Devices ----------------
Adafruit_ADXL375 adxl(PIN_ADXL_CS, &SPI, 12345);
SdFs sd;
Adafruit_7segment display;

bool okAdxl = false, okSd = false, okImu = false, okDisplay = false;

static void report(const char *name, bool ok, const char *detail = "") {
  Serial.print(ok ? "PASS  " : "FAIL  ");
  Serial.print(name);
  if (detail[0]) { Serial.print(": "); Serial.print(detail); }
  Serial.println();
}

// ---------------- ADXL375 over SPI ----------------
static void testAdxl() {
  char buf[96];
  if (!adxl.begin()) {
    report("ADXL375", false, "begin() failed. Check CS, SCK, MOSI, MISO, VIN, GND.");
    return;
  }
  uint8_t id = adxl.getDeviceID();
  if (id != 0xE5) {
    snprintf(buf, sizeof buf, "device ID 0x%02X, expected 0xE5", id);
    report("ADXL375", false, buf);
    return;
  }
  adxl.setDataRate(ADXL3XX_DATARATE_3200_HZ);

  // Time 1000 raw reads. Each is three 2-byte register reads through
  // the library; the real firmware will do one 6-byte burst instead.
  int16_t x = 0, y = 0, z = 0;
  uint32_t t0 = micros();
  for (int i = 0; i < 1000; i++) { x = adxl.getX(); y = adxl.getY(); z = adxl.getZ(); }
  uint32_t us = (micros() - t0) / 1000;

  float gx = x * 0.049f, gy = y * 0.049f, gz = z * 0.049f;
  float mag = sqrtf(gx * gx + gy * gy + gz * gz);
  snprintf(buf, sizeof buf, "ID 0xE5, %lu us per sample, at rest |a| = %.2f g (expect ~1.0)",
           (unsigned long)us, mag);
  okAdxl = true;
  report("ADXL375", true, buf);
  if (mag < 0.7f || mag > 1.3f) {
    Serial.println("      WARN: |a| at rest is not near 1 g. Hold the board still and rerun.");
  }
}

// ---------------- microSD over shared SPI ----------------
static void testSd() {
  char buf[96];
  if (!sd.begin(SdSpiConfig(PIN_SD_CS, SHARED_SPI, SD_SCK_MHZ(8)))) {
    report("microSD", false, "begin() failed. Check CS, CLK, DI, DO, power, and that a card is in.");
    if (sd.sdErrorCode()) {
      snprintf(buf, sizeof buf, "sdErrorCode 0x%02X, sdErrorData 0x%02X",
               sd.sdErrorCode(), sd.sdErrorData());
      Serial.print("      "); Serial.println(buf);
    }
    return;
  }
  uint32_t mb = (uint32_t)(sd.card()->sectorCount() / 2048);
  snprintf(buf, sizeof buf, "card %lu MB, FAT%d", (unsigned long)mb, sd.fatType());
  report("microSD", true, buf);

  // Write 200 x 512 bytes and record the slowest write. This is the
  // number that decides how much RAM buffering the logger needs.
  FsFile f = sd.open("BRINGUP.BIN", O_WRONLY | O_CREAT | O_TRUNC);
  if (!f) { report("microSD write", false, "could not open BRINGUP.BIN"); return; }
  static uint8_t block[512];
  for (int i = 0; i < 512; i++) block[i] = i;
  uint32_t worst = 0, total = 0;
  for (int i = 0; i < 200; i++) {
    uint32_t t0 = micros();
    f.write(block, sizeof block);
    uint32_t dt = micros() - t0;
    total += dt;
    if (dt > worst) worst = dt;
  }
  f.close();
  snprintf(buf, sizeof buf, "200 x 512 B: mean %lu us, worst %lu us",
           (unsigned long)(total / 200), (unsigned long)worst);
  okSd = true;
  report("microSD write", true, buf);
}

// After the SD card has been used, the ADXL375 must still answer. If
// this fails, the SD board is holding MISO when it is not selected.
static void testBusSharing() {
  if (!okAdxl || !okSd) { report("SPI bus sharing", false, "skipped, needs both SPI devices"); return; }
  uint8_t id = adxl.getDeviceID();
  report("SPI bus sharing", id == 0xE5,
         id == 0xE5 ? "ADXL375 still answers after SD use"
                    : "ADXL375 ID wrong after SD use: SD board is not releasing MISO");
}

// ---------------- Onboard LSM6DS3 IMU ----------------
// The Sense's IMU hangs off a second, internal I2C bus (Wire1, P0.07 and
// P0.27) and needs its power pin driven high. The Seeed LSM6DS3 library
// only switches to Wire1 under the mbed core, so on this core it would
// talk to the wrong bus. Bring-up reads WHO_AM_I directly instead. The
// logger firmware will handle the gyro properly.
static void testImu() {
  char buf[96];
  pinMode(PIN_LSM6DS3TR_C_POWER, OUTPUT);
  digitalWrite(PIN_LSM6DS3TR_C_POWER, HIGH);
  delay(50);
  Wire1.begin();
  Wire1.beginTransmission(0x6A);
  Wire1.write(0x0F);                       // WHO_AM_I
  if (Wire1.endTransmission(false) != 0 || Wire1.requestFrom(0x6A, 1) != 1) {
    report("LSM6DS3 (onboard)", false, "no answer on Wire1 at 0x6A. This is on the XIAO itself.");
    return;
  }
  uint8_t who = Wire1.read();
  snprintf(buf, sizeof buf, "WHO_AM_I 0x%02X (expect 0x6A or 0x69)", who);
  okImu = (who == 0x6A || who == 0x69);
  report("LSM6DS3 (onboard)", okImu, buf);
}

// ---------------- HT16K33 display over I2C ----------------
static void testDisplay() {
  Wire.setClock(100000);   // long cable to the bars: keep it slow
  Wire.beginTransmission(DISPLAY_ADDR);
  if (Wire.endTransmission() != 0) {
    report("HT16K33 display", false, "no ACK at 0x70. Check D (SDA=D4), C (SCL=D5), +, -, pull-ups.");
    return;
  }
  display.begin(DISPLAY_ADDR);
  display.setBrightness(15);
  display.print(8888);
  display.writeDisplay();
  okDisplay = true;
  report("HT16K33 display", true, "ACK at 0x70, showing 8888. Judge brightness at 3.3 V by eye.");
}

// ---------------- Button ----------------
static void testButton() {
  pinMode(PIN_BUTTON, INPUT_PULLUP);
  bool pressed = digitalRead(PIN_BUTTON) == LOW;
  report("Button", true, pressed ? "reads PRESSED now (should be released)" : "reads released");
}

// ---------------- Battery ----------------
static float readBattery() {
  // Divider on the XIAO is 1 M / 510 k, so Vbat = Vpin * 1510 / 510.
  // Reference 2.4 V internal, 12-bit.
  digitalWrite(VBAT_ENABLE, LOW);
  analogReference(AR_INTERNAL_2_4);
  analogReadResolution(12);
  uint32_t raw = 0;
  for (int i = 0; i < 8; i++) raw += analogRead(PIN_VBAT);
  raw /= 8;
  return raw * (2.4f / 4096.0f) * (1510.0f / 510.0f);
}

static void testBattery() {
  char buf[96];
  pinMode(VBAT_ENABLE, OUTPUT);
  pinMode(PIN_HICHG, OUTPUT);
  digitalWrite(PIN_HICHG, LOW);   // 100 mA charge; fine for a 500 mAh cell
  float v = readBattery();
  snprintf(buf, sizeof buf, "%.2f V (3.0 empty, 4.2 full; ~0 V means no cell on BAT pads)", v);
  report("Battery", true, buf);
}

void setup() {
  Serial.begin(115200);
  uint32_t t0 = millis();
  while (!Serial && millis() - t0 < 5000) {}
  Serial.println();
  Serial.println("Shredometer Mk2 bring-up");
  Serial.println("------------------------");

  pinMode(PIN_ADXL_CS, OUTPUT); digitalWrite(PIN_ADXL_CS, HIGH);
  pinMode(PIN_SD_CS, OUTPUT);   digitalWrite(PIN_SD_CS, HIGH);
  pinMode(PIN_ADXL_INT1, INPUT);

  SPI.begin();
  Wire.begin();

  testAdxl();
  testSd();
  testBusSharing();
  testImu();
  testDisplay();
  testButton();
  testBattery();

  Serial.println("------------------------");
  Serial.println("Live: peak |a| over each second, button, battery. Shake the board.");
}

void loop() {
  static uint32_t lastPrint = 0;
  static float peak = 0;
  static uint32_t samples = 0;

  if (okAdxl) {
    int16_t x = adxl.getX(), y = adxl.getY(), z = adxl.getZ();
    float gx = x * 0.049f, gy = y * 0.049f, gz = z * 0.049f;
    float mag = sqrtf(gx * gx + gy * gy + gz * gz);
    if (mag > peak) peak = mag;
    samples++;
  }

  if (millis() - lastPrint >= 1000) {
    lastPrint = millis();
    Serial.print("peak |a| ");
    Serial.print(peak, 1);
    Serial.print(" g over ");
    Serial.print(samples);
    Serial.print(" reads   button ");
    Serial.print(digitalRead(PIN_BUTTON) == LOW ? "PRESSED " : "released");
    Serial.print("   bat ");
    Serial.print(readBattery(), 2);
    Serial.println(" V");
    if (okDisplay) {
      display.print(peak, 1);
      display.writeDisplay();
    }
    peak = 0;
    samples = 0;
  }
}
