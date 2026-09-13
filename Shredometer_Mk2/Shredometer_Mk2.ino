// Shredometer Mk2 logger
// ----------------------
// XIAO nRF52840 Sense Plus + ADXL375 (SPI) + microSD (SPI) + onboard
// LSM6DS3 (internal I2C). Logs from power-on until power-off. No display,
// no button: the power switch is the start button.
//
// Data path
//   ADXL375 runs at ADXL_ODR_HZ with its 32-entry FIFO in stream mode.
//   The main loop drains the FIFO as often as it can, packs samples into
//   512-byte sectors, and writes each full sector to a pre-allocated file.
//   The FIFO is the cushion against SD write stalls: at 1600 Hz it holds
//   20 ms. A stall longer than that loses samples, and the sensor reports
//   it through its overrun bit, which is counted and logged, so a gap is
//   always visible in the data rather than silently absent.
//   The LSM6DS3 gyro and accelerometer are read at about 104 Hz on the
//   internal bus and logged alongside.
//
// Log format (MK2_NNN.BIN)
//   Sector 0: Header (below), rest zero.
//   Every later sector: 64 records of 8 bytes. The first record in each
//   sector is a REC_TIME marker: millis() when the sector was started, a
//   sector sequence number, and the overrun count during the previous
//   sector. The other 63 are samples in the order they were taken.
//   scripts/mk2_to_csv.py turns this into the CSV the analysis reads.
//
// Serial (USB) is optional. Commands when connected:
//   i  print counters      s  stop and close the current file
//   r  start a new file    d  dump the last closed file (raw bytes)
//
// Build: scripts/flash_xiao.sh Shredometer_Mk2

#include <Adafruit_TinyUSB.h>
#include <SPI.h>
#include <Wire.h>
#include <SdFat.h>

// ---------------- Pins ----------------
const uint8_t PIN_ADXL_CS   = 3;
const uint8_t PIN_ADXL_INT1 = 0;   // wired, unused: the FIFO is polled
const uint8_t PIN_SD_CS     = 2;

// ---------------- Rates ----------------
// ADXL375 BW_RATE codes: 0x0F 3200 Hz, 0x0E 1600 Hz, 0x0D 800 Hz.
// Lower halves the FIFO's time cushion per step up, and cuts noise by
// about 1.4 per step down. 1600 gives 800 Hz bandwidth and 20 ms of FIFO.
const uint8_t  ADXL_BW_RATE_REG = 0x0E;
const float    ADXL_ODR_HZ      = 1600.0f;
const float    ADXL_G_PER_LSB   = 0.049f;
const uint32_t IMU_PERIOD_US    = 9615;    // 104 Hz, the LSM6DS3's own rate
const float    GYRO_DPS_PER_LSB = 0.070f;  // 2000 dps full scale
const float    IMUACC_G_PER_LSB = 0.000488f; // 16 g full scale
const uint32_t SYNC_PERIOD_MS   = 5000;    // directory entry update
const uint32_t PREALLOC_BYTES   = 256UL * 1024 * 1024;

// ---------------- Log format ----------------
struct __attribute__((packed)) Rec { uint8_t type; uint8_t flags; int16_t a, b, c; };
enum : uint8_t { REC_ADXL = 0, REC_GYRO = 1, REC_IMUACC = 2, REC_TIME = 3 };
struct __attribute__((packed)) Header {
  char     magic[8];        // "SHRDMK2"
  uint16_t version;         // 1
  uint16_t rec_size;        // 8
  uint16_t sector_size;     // 512
  uint16_t reserved;
  float    adxl_odr_hz;
  float    adxl_g_per_lsb;
  float    gyro_dps_per_lsb;
  float    imuacc_g_per_lsb;
  float    imu_hz;
  uint32_t start_millis;
};
static_assert(sizeof(Rec) == 8, "record size");
const int SECTOR = 512;
const int RECS_PER_SECTOR = SECTOR / sizeof(Rec);

// ---------------- State ----------------
SdFs sd;
FsFile file;
char lastName[16] = "";
bool logging = false, adxlOk = false, imuOk = false, sdOk = false;

uint8_t  sector[SECTOR];
int      fill = 0;
uint16_t seq = 0;
uint32_t overrunsTotal = 0, overrunsSinceMarker = 0, zerosTotal = 0;
uint32_t sectorsWritten = 0, worstWriteUs = 0, adxlSamples = 0, imuSamples = 0;
uint32_t lastSync = 0, lastImuUs = 0, lastBlink = 0;

// ---------------- LEDs (active low) ----------------
static void led(uint8_t pin, bool on) { digitalWrite(pin, on ? LOW : HIGH); }
static void ledsOff() { led(LED_RED, false); led(LED_GREEN, false); led(LED_BLUE, false); }

// ---------------- ADXL375, direct SPI ----------------
static const SPISettings ADXL_SPI(4000000, MSBFIRST, SPI_MODE3);
static uint8_t adxlRead(uint8_t reg) {
  SPI.beginTransaction(ADXL_SPI); digitalWrite(PIN_ADXL_CS, LOW);
  SPI.transfer(reg | 0x80); uint8_t v = SPI.transfer(0);
  digitalWrite(PIN_ADXL_CS, HIGH); SPI.endTransaction();
  return v;
}
static void adxlWrite(uint8_t reg, uint8_t v) {
  SPI.beginTransaction(ADXL_SPI); digitalWrite(PIN_ADXL_CS, LOW);
  SPI.transfer(reg & 0x3F); SPI.transfer(v);
  digitalWrite(PIN_ADXL_CS, HIGH); SPI.endTransaction();
}
static void adxlBurst(int16_t *x, int16_t *y, int16_t *z) {
  uint8_t b[6];
  SPI.beginTransaction(ADXL_SPI); digitalWrite(PIN_ADXL_CS, LOW);
  SPI.transfer(0x32 | 0x80 | 0x40);
  for (int i = 0; i < 6; i++) b[i] = SPI.transfer(0);
  digitalWrite(PIN_ADXL_CS, HIGH); SPI.endTransaction();
  *x = (int16_t)(b[0] | (b[1] << 8));
  *y = (int16_t)(b[2] | (b[3] << 8));
  *z = (int16_t)(b[4] | (b[5] << 8));
}
static bool adxlInit() {
  pinMode(PIN_ADXL_CS, OUTPUT); digitalWrite(PIN_ADXL_CS, HIGH);
  pinMode(PIN_ADXL_INT1, INPUT);
  if (adxlRead(0x00) != 0xE5) return false;
  adxlWrite(0x2D, 0x00);              // standby while configuring
  adxlWrite(0x31, 0x0B);              // full resolution, 4-wire SPI, +/-200 g
  adxlWrite(0x2C, ADXL_BW_RATE_REG);  // output data rate
  adxlWrite(0x38, 0x9F);              // FIFO stream mode
  adxlWrite(0x2E, 0x00);              // no interrupts
  adxlWrite(0x2D, 0x08);              // measure
  return true;
}

// ---------------- LSM6DS3, direct I2C on the internal bus ----------------
const uint8_t IMU_ADDR = 0x6A;
static bool imuWrite(uint8_t reg, uint8_t v) {
  Wire1.beginTransmission(IMU_ADDR); Wire1.write(reg); Wire1.write(v);
  return Wire1.endTransmission() == 0;
}
static bool imuRead(uint8_t reg, uint8_t *buf, uint8_t n) {
  Wire1.beginTransmission(IMU_ADDR); Wire1.write(reg);
  if (Wire1.endTransmission(false) != 0) return false;
  if (Wire1.requestFrom(IMU_ADDR, n) != n) return false;
  for (uint8_t i = 0; i < n; i++) buf[i] = Wire1.read();
  return true;
}
static bool imuInit() {
  // The Sense Plus needs its IMU supply pin in high-drive mode, or the
  // IMU never powers up (measured 2026-09-13, see docs/mk2_build.md).
  pinMode(PIN_LSM6DS3TR_C_POWER, OUTPUT_H0H1);
  digitalWrite(PIN_LSM6DS3TR_C_POWER, HIGH);
  delay(50);
  // The nRF52 Wire driver hangs forever on a bus held low. Check first.
  pinMode(PIN_WIRE1_SDA, INPUT_PULLUP); pinMode(PIN_WIRE1_SCL, INPUT_PULLUP); delayMicroseconds(200);
  if (!digitalRead(PIN_WIRE1_SDA) || !digitalRead(PIN_WIRE1_SCL)) return false;
  Wire1.begin();
  Wire1.setClock(400000);
  uint8_t who = 0;
  if (!imuRead(0x0F, &who, 1) || (who != 0x6A && who != 0x69)) return false;
  imuWrite(0x12, 0x44);   // CTRL3_C: block data update, auto-increment
  imuWrite(0x10, 0x44);   // CTRL1_XL: 104 Hz, +/-16 g
  imuWrite(0x11, 0x4C);   // CTRL2_G: 104 Hz, 2000 dps
  return true;
}

// ---------------- Sector assembly ----------------
static void writeSector();
static void pushRec(uint8_t type, uint8_t flags, int16_t a, int16_t b, int16_t c) {
  if (fill == 0) {
    // Start every sector with a time marker.
    uint32_t ms = millis();
    Rec m = { REC_TIME, (uint8_t)min<uint32_t>(overrunsSinceMarker, 255),
              (int16_t)(ms & 0xFFFF), (int16_t)(ms >> 16), (int16_t)seq++ };
    overrunsSinceMarker = 0;
    memcpy(sector, &m, sizeof m); fill = sizeof m;
  }
  Rec r = { type, flags, a, b, c };
  memcpy(sector + fill, &r, sizeof r); fill += sizeof r;
  if (fill >= SECTOR) writeSector();
}
static void writeSector() {
  uint32_t t0 = micros();
  if (file.write(sector, SECTOR) != SECTOR) {
    led(LED_RED, true);
    logging = false;
    Serial.println("SD write failed; logging stopped");
  }
  uint32_t dt = micros() - t0;
  if (dt > worstWriteUs) worstWriteUs = dt;
  sectorsWritten++;
  fill = 0;
}

// ---------------- Sensors into the stream ----------------
static void drainAdxl() {
  uint8_t entries = adxlRead(0x39) & 0x3F;
  if (entries == 0) return;
  if (adxlRead(0x30) & 0x01) { overrunsTotal++; overrunsSinceMarker++; }
  for (uint8_t i = 0; i < entries; i++) {
    int16_t x, y, z;
    adxlBurst(&x, &y, &z);
    delayMicroseconds(5);   // datasheet minimum between FIFO reads
    if (x == 0 && y == 0 && z == 0) { zerosTotal++; continue; }
    pushRec(REC_ADXL, 0, x, y, z);
    adxlSamples++;
  }
}
static void pollImu() {
  if (!imuOk) return;
  uint32_t now = micros();
  if (now - lastImuUs < IMU_PERIOD_US) return;
  lastImuUs = now;
  uint8_t st = 0;
  if (!imuRead(0x1E, &st, 1) || !(st & 0x02)) return;
  uint8_t b[12];
  if (!imuRead(0x22, b, 12)) return;   // gyro X..Z then accel X..Z
  pushRec(REC_GYRO,   0, (int16_t)(b[0] | b[1] << 8), (int16_t)(b[2] | b[3] << 8),  (int16_t)(b[4] | b[5] << 8));
  pushRec(REC_IMUACC, 0, (int16_t)(b[6] | b[7] << 8), (int16_t)(b[8] | b[9] << 8),  (int16_t)(b[10] | b[11] << 8));
  imuSamples++;
}

// ---------------- Files ----------------
static bool startLog() {
  char name[16];
  for (int n = 0; n < 1000; n++) {
    snprintf(name, sizeof name, "MK2_%03d.BIN", n);
    if (!sd.exists(name)) break;
  }
  if (!file.open(name, O_WRONLY | O_CREAT | O_EXCL)) return false;
  if (!file.preAllocate(PREALLOC_BYTES) && !file.preAllocate(PREALLOC_BYTES / 4)) {
    Serial.println("preAllocate failed; writes may stall on cluster allocation");
  }
  Header h = {};
  memcpy(h.magic, "SHRDMK2", 8);
  h.version = 1; h.rec_size = sizeof(Rec); h.sector_size = SECTOR;
  h.adxl_odr_hz = ADXL_ODR_HZ; h.adxl_g_per_lsb = ADXL_G_PER_LSB;
  h.gyro_dps_per_lsb = GYRO_DPS_PER_LSB; h.imuacc_g_per_lsb = IMUACC_G_PER_LSB;
  h.imu_hz = 1e6f / IMU_PERIOD_US; h.start_millis = millis();
  memset(sector, 0, SECTOR); memcpy(sector, &h, sizeof h);
  if (file.write(sector, SECTOR) != SECTOR) { file.close(); return false; }
  file.sync();
  strncpy(lastName, name, sizeof lastName);
  fill = 0; seq = 0; overrunsSinceMarker = 0;
  overrunsTotal = zerosTotal = sectorsWritten = worstWriteUs = adxlSamples = imuSamples = 0;
  // Flush whatever the FIFO gathered while we were busy, so the log
  // starts fresh.
  adxlWrite(0x38, 0x00); adxlWrite(0x38, 0x9F);
  lastSync = millis(); lastImuUs = micros();
  logging = true;
  Serial.print("logging to "); Serial.println(name);
  return true;
}
static void stopLog() {
  if (!logging) return;
  logging = false;
  if (fill > 0) { memset(sector + fill, 0, SECTOR - fill); writeSector(); }
  file.truncate();
  file.close();
  Serial.print("closed "); Serial.println(lastName);
}
static void printInfo() {
  Serial.print(logging ? "logging " : "idle "); Serial.println(lastName);
  Serial.print("  adxl samples "); Serial.print(adxlSamples);
  Serial.print("  imu samples "); Serial.print(imuSamples);
  Serial.print("  sectors "); Serial.print(sectorsWritten);
  Serial.print("  worst write us "); Serial.print(worstWriteUs);
  Serial.print("  overruns "); Serial.print(overrunsTotal);
  Serial.print("  zero samples dropped "); Serial.println(zerosTotal);
}
static void dumpLast() {
  if (logging) { Serial.println("stop first (s)"); return; }
  FsFile f = sd.open(lastName, O_RDONLY);
  if (!f) { Serial.println("no file"); return; }
  Serial.print("DUMP "); Serial.print(lastName); Serial.print(" "); Serial.println((uint32_t)f.fileSize());
  Serial.flush();
  static uint8_t buf[512];
  int n;
  while ((n = f.read(buf, sizeof buf)) > 0) { Serial.write(buf, n); }
  f.close();
  Serial.flush();
  Serial.println(); Serial.println("END");
}
static void handleSerial() {
  if (!Serial || !Serial.available()) return;
  char c = Serial.read();
  switch (c) {
    case 'i': printInfo(); break;
    case 's': stopLog(); break;
    case 'r': stopLog(); if (!startLog()) Serial.println("start failed"); break;
    case 'd': dumpLast(); break;
    default: break;
  }
}

// ---------------- Setup and loop ----------------
void setup() {
  Serial.begin(115200);
  pinMode(LED_RED, OUTPUT); pinMode(LED_GREEN, OUTPUT); pinMode(LED_BLUE, OUTPUT);
  ledsOff();
  led(LED_BLUE, true);
  pinMode(PIN_SD_CS, OUTPUT); digitalWrite(PIN_SD_CS, HIGH);
  SPI.begin();

  adxlOk = adxlInit();
  imuOk  = imuInit();
  sdOk   = sd.begin(SdSpiConfig(PIN_SD_CS, SHARED_SPI, SD_SCK_MHZ(8)));

  uint32_t t0 = millis();
  while (!Serial && millis() - t0 < 1500) {}
  Serial.println("Shredometer Mk2 logger");
  Serial.print("  ADXL375 "); Serial.println(adxlOk ? "ok" : "MISSING");
  Serial.print("  LSM6DS3 "); Serial.println(imuOk ? "ok" : "missing (logging without gyro)");
  Serial.print("  microSD "); Serial.println(sdOk ? "ok" : "MISSING");

  ledsOff();
  if (!adxlOk || !sdOk) { led(LED_RED, true); return; }   // solid red: cannot log
  if (!startLog()) { led(LED_RED, true); return; }
}

void loop() {
  handleSerial();
  if (!logging) return;
  drainAdxl();
  pollImu();
  uint32_t now = millis();
  if (now - lastSync >= SYNC_PERIOD_MS) { file.sync(); lastSync = now; }
  if (now - lastBlink >= 500) { lastBlink = now; digitalWrite(LED_GREEN, !digitalRead(LED_GREEN)); }
}
