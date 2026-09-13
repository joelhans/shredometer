// Shredometer Mk2 bring-up
// ------------------------
// Tests each subsystem on the XIAO nRF52840 Sense, one at a time, and
// reports PASS or FAIL for each over USB serial. Wire one subsystem,
// flash this, read the report, wire the next. Nothing here logs a
// ride; that is Shredometer_Mk2 (to come).
//
// Board:  Seeed XIAO nRF52840 Sense Plus (bootloader reports USB PID 0x0065)
// FQBN:   Seeeduino:nrf52:xiaonRF52840SensePlus
//         (plain Sense: Seeeduino:nrf52:xiaonRF52840Sense, bootloader PID 0x0045)
// Build:  arduino-cli compile --fqbn Seeeduino:nrf52:xiaonRF52840SensePlus Shredometer_Mk2_Bringup
// Upload: arduino-cli upload -p /dev/ttyACM0 --fqbn Seeeduino:nrf52:xiaonRF52840SensePlus Shredometer_Mk2_Bringup
// D0 to D10 are the same on both boards. The battery, charger, and IMU
// pins come from the variant's macros, so the FQBN must match the board.
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
    // Say what came back, so a wiring fault can be located.
    //   0x00 every time: MISO stuck low, or the sensor never selected (CS, or no power).
    //   0xFF every time: MISO floating or open (SDO wire), or no power to the sensor.
    //   other, varying:  clock or data wire swapped or open.
    uint8_t ids[4];
    for (int i = 0; i < 4; i++) ids[i] = adxl.getDeviceID();
    pinMode(PIN_SPI_MISO, INPUT_PULLDOWN); delayMicroseconds(200); bool misoDown = digitalRead(PIN_SPI_MISO);
    pinMode(PIN_SPI_MISO, INPUT_PULLUP);   delayMicroseconds(200); bool misoUp   = digitalRead(PIN_SPI_MISO);
    SPI.begin();  // give the pin back to SPI
    snprintf(buf, sizeof buf, "no ID 0xE5. Read %02X %02X %02X %02X. MISO idle: %s",
             ids[0], ids[1], ids[2], ids[3],
             (misoDown != misoUp) ? "floating (SDO wire open, or sensor unpowered)"
                                  : (misoUp ? "driven high" : "driven low"));
    report("ADXL375", false, buf);
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
  adxlStats();
}

// Read a register directly, outside the library.
static uint8_t adxlReg(uint8_t reg) {
  SPI.beginTransaction(SPISettings(1000000, MSBFIRST, SPI_MODE3));
  digitalWrite(PIN_ADXL_CS, LOW);
  SPI.transfer(reg | 0x80);
  uint8_t v = SPI.transfer(0);
  digitalWrite(PIN_ADXL_CS, HIGH);
  SPI.endTransaction();
  return v;
}

// One 6-byte burst read of X, Y, Z. This is how the logger will read.
static void adxlBurst(int16_t *x, int16_t *y, int16_t *z) {
  uint8_t b[6];
  SPI.beginTransaction(SPISettings(1000000, MSBFIRST, SPI_MODE3));
  digitalWrite(PIN_ADXL_CS, LOW);
  SPI.transfer(0x32 | 0x80 | 0x40);   // DATAX0, read, multi-byte
  for (int i = 0; i < 6; i++) b[i] = SPI.transfer(0);
  digitalWrite(PIN_ADXL_CS, HIGH);
  SPI.endTransaction();
  *x = (int16_t)(b[0] | (b[1] << 8));
  *y = (int16_t)(b[2] | (b[3] << 8));
  *z = (int16_t)(b[4] | (b[5] << 8));
}

// 3000 burst samples at rest: mean vector, scatter per axis, outliers.
// Clean data is a mean magnitude near 1 g, rms of a few counts (0.1 to
// 0.3 g), and zero outliers. Outliers with an otherwise clean mean point
// at the wiring, not the sensor.
static void adxlStats() {
  char buf[120];
  snprintf(buf, sizeof buf, "      regs: BW_RATE 0x%02X (0x0F = 3200 Hz), DATA_FORMAT 0x%02X, POWER_CTL 0x%02X",
           adxlReg(0x2C), adxlReg(0x31), adxlReg(0x2D));
  Serial.println(buf);
  const int N = 3000;
  static int16_t xs[N], ys[N], zs[N];
  double sx = 0, sy = 0, sz = 0;
  int zeros = 0;
  for (int i = 0; i < N; i++) {
    adxlBurst(&xs[i], &ys[i], &zs[i]);
    sx += xs[i]; sy += ys[i]; sz += zs[i];
    if (xs[i] == 0 && ys[i] == 0 && zs[i] == 0) zeros++;
    delayMicroseconds(320);   // about one 3200 Hz sample period
  }
  float mx = sx / N, my = sy / N, mz = sz / N;
  // Scatter about the mean, and glitches: samples further than 1.5 g
  // from the mean vector. Noise at 0.2 g rms per axis essentially never
  // gets there, so any count here is the wiring.
  double sxx = 0, syy = 0, szz = 0; int far = 0; float devMax = 0;
  for (int i = 0; i < N; i++) {
    float dx = xs[i] - mx, dy = ys[i] - my, dz = zs[i] - mz;
    sxx += dx * dx; syy += dy * dy; szz += dz * dz;
    float d = sqrtf(dx * dx + dy * dy + dz * dz) * 0.049f;
    if (d > devMax) devMax = d;
    if (d > 1.5f) far++;
  }
  snprintf(buf, sizeof buf, "      mean  x %+.2f  y %+.2f  z %+.2f g   |mean| %.2f g (offsets make this differ from 1.0)",
           mx * 0.049f, my * 0.049f, mz * 0.049f, sqrtf(mx * mx + my * my + mz * mz) * 0.049f);
  Serial.println(buf);
  snprintf(buf, sizeof buf, "      rms   x %.2f  y %.2f  z %.2f g   worst deviation %.2f g   glitches %d, all-zero %d, of %d",
           sqrtf(sxx / N) * 0.049f, sqrtf(syy / N) * 0.049f, sqrtf(szz / N) * 0.049f, devMax, far, zeros, N);
  Serial.println(buf);
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

// The nRF52 Wire driver has no timeouts: a bus held low hangs it forever.
// Check both lines idle high (with the internal pull-up) before using it.
// Returns 0 if OK, else a bitmask: 1 = SDA low, 2 = SCL low.
static uint8_t i2cBusHeldLow(uint8_t sda, uint8_t scl) {
  pinMode(sda, INPUT_PULLUP); pinMode(scl, INPUT_PULLUP);
  delayMicroseconds(200);
  uint8_t bad = 0;
  if (digitalRead(sda) == LOW) bad |= 1;
  if (digitalRead(scl) == LOW) bad |= 2;
  return bad;
}

// ---------------- Onboard LSM6DS3 IMU ----------------
// The Sense's IMU hangs off a second, internal I2C bus (Wire1, P0.07 and
// P0.27) and is powered from a GPIO, P1.08, which also feeds the bus
// pull-ups. On the Sense Plus that pin MUST be in high-drive mode: in
// standard drive it sags under the IMU's load, the supply never comes
// up, and the bus reads low (measured 2026-09-13 on two boards). The
// Seeed LSM6DS3 library uses plain OUTPUT, so it fails on the Plus
// unless the pin is set up like this before its begin().
// Bring-up reads WHO_AM_I directly, with no library.
static void testImu() {
  char buf[96];
  pinMode(PIN_LSM6DS3TR_C_POWER, OUTPUT_H0H1);
  digitalWrite(PIN_LSM6DS3TR_C_POWER, HIGH);
  delay(50);
  uint8_t bad = i2cBusHeldLow(PIN_WIRE1_SDA, PIN_WIRE1_SCL);
  if (bad) {
    snprintf(buf, sizeof buf, "internal bus held low (SDA %s, SCL %s): IMU unpowered or on other pins",
             (bad & 1) ? "LOW" : "ok", (bad & 2) ? "LOW" : "ok");
    report("LSM6DS3 (onboard)", false, buf);
    return;
  }
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
  uint8_t bad = i2cBusHeldLow(PIN_WIRE_SDA, PIN_WIRE_SCL);
  if (bad) {
    report("HT16K33 display", false, (bad & 1) ? "SDA (D4) held low" : "SCL (D5) held low");
    return;
  }
  Wire.begin();
  Wire.setClock(100000);   // long cable to the bars: keep it slow
  // Probe with one data byte. The nRF52 Wire driver has no timeouts,
  // and a zero-length write never raises TXSTARTED, so an address-only
  // probe hangs forever. 0x21 is the HT16K33 "oscillator on" command,
  // which begin() sends anyway.
  Wire.beginTransmission(DISPLAY_ADDR);
  Wire.write(0x21);
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
  pinMode(PIN_ADXL_CS, OUTPUT); digitalWrite(PIN_ADXL_CS, HIGH);
  pinMode(PIN_SD_CS, OUTPUT);   digitalWrite(PIN_SD_CS, HIGH);
  pinMode(PIN_ADXL_INT1, INPUT);
  pinMode(PIN_BUTTON, INPUT_PULLUP);
  SPI.begin();
}

// The tests run once a host opens the port, not at boot, so the report
// is never missed. Send 'r' over serial to run them again after wiring
// the next subsystem; no reflash needed.
static void runTests() {
  Serial.println();
  Serial.println("Shredometer Mk2 bring-up");
  Serial.println("------------------------");
  // One line before each test, so a hang shows which test it is in.
  Serial.println("-- ADXL375");         testAdxl();
  Serial.println("-- microSD");         testSd();
  Serial.println("-- SPI bus sharing"); testBusSharing();
  Serial.println("-- LSM6DS3");         testImu();
  Serial.println("-- display");         testDisplay();
  Serial.println("-- button");          testButton();
  Serial.println("-- battery");         testBattery();
  Serial.println("------------------------");
  Serial.println("Live: peak |a| over each second, button, battery. Send 'r' to rerun the tests.");
}

void loop() {
  static bool ran = false;
  static uint32_t lastPrint = 0;
  static float peak = 0;
  static uint32_t samples = 0;

  if (!Serial) { ran = false; return; }   // wait for a host; rerun on reconnect
  if (!ran) { delay(300); runTests(); ran = true; }
  if (Serial.available() && Serial.read() == 'r') { ran = false; return; }

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
