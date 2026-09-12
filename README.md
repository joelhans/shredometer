# Shredometer

Arduino Nano Every datalogger for a 9-DOF IMU (LSM9DS1), originally written
by Ryan T Cutshall (last updated 17 Sep 2022) for a classic Nano, and later
tuned on real hardware (see "Firmware changes" below). Logs
accelerometer/magnetometer/gyroscope readings to an SD card at high rate and
displays a rolling "shred score" (peak acceleration in g) on a 7-segment LED
display.

## Hardware

- Arduino Nano Every (ATmega4809 — confirmed via `arduino-cli board list`,
  FQBN `arduino:megaavr:nona4809`). Pin-compatible with the classic Nano,
  but a different chip: more flash and RAM, and a different toolchain/core.
- Adafruit LSM9DS1 9-DOF breakout (I2C)
- microSD card module (SPI)
- Adafruit 0.56" 4-digit 7-segment LED backpack (I2C, address `0x70`)
- Momentary push button

### Wiring

| Signal              | Nano Every pin |
|---------------------|----------|
| SD card CS          | D10      |
| SD card MOSI/MISO/SCK | D11/D12/D13 (hardware SPI) |
| Start button         | D2       |
| LSM9DS1 SDA/SCL       | A4/A5 (hardware I2C) |
| LED backpack SDA/SCL  | A4/A5 (shared I2C bus) |

The button is read with a plain `INPUT` (not `INPUT_PULLUP`), and the code
waits for the pin to go `HIGH` to start logging — so it must be wired with an
external pull-down resistor to GND, with the button connecting the pin to 5V
when pressed.

## Firmware

Sketch: [`Shredometer_Datalogger/Shredometer_Datalogger.ino`](Shredometer_Datalogger/Shredometer_Datalogger.ino)

### Firmware changes

Tuned after testing on the real board:

- Accelerometer range raised from 4G to 16G. At 4G, hard hits clipped at
  the sensor's own ceiling, which capped the shred score below its real
  value. 16G costs some resolution on smaller movements but stops the
  clipping.
- The LED display shows one decimal place below 10g (e.g. `7.3`). At 10g
  and above, it rounds to a whole number instead (e.g. `12`), since the
  display can't fit both an extra digit and the decimal. Clamped at 99.
- The SD file is opened once at the start of a run and kept open, instead
  of being reopened on every sample. It's flushed to the card every 15
  samples. This, combined with raising the serial baud rate below, took
  the sample rate from about 15 Hz to over 100 Hz.
- Serial baud rate raised from 9600 to 115200. At 9600, printing each
  sample line over serial took about as long as the rest of the loop
  combined, and was the main bottleneck. This was the biggest single
  factor in the sample-rate jump above.
- Fixed a bug where every logged line was followed by a blank line in the
  file, caused by a doubled line ending (`println()` on a string that already
  ended in `\n`). **This fix has never reached the board.** Every log through
  DL_61 still ends its lines with `\n\r\n`, which only the old `println()`
  path produces. DL_51 onward runs at 113-117 Hz, so the keep-file-open and
  115200-baud changes from the same commit *are* running — the flashed build
  sits between those edits and this one. Expect the blank lines to disappear
  on the next upload. (They are harmless either way: the analysis script
  skips blank lines.)
- The accelerometer is oversampled and peak-held between logged rows. See
  "Sensor limits" below for why, and "Log format" for the two columns it
  adds.

### Dependencies

Installed via `arduino-cli`:

- `Adafruit LSM9DS1 Library` (pulls in `Adafruit Unified Sensor`, `Adafruit BusIO`, `Adafruit LIS3MDL`)
- `Adafruit GFX Library`
- `Adafruit LED Backpack Library`
- `SD`

### Build environment setup

```sh
sudo pacman -S arduino-cli   # or install per https://arduino.github.io/arduino-cli/latest/installation/
arduino-cli config init
arduino-cli core update-index
arduino-cli core install arduino:megaavr
arduino-cli lib install "Adafruit LSM9DS1 Library" "Adafruit GFX Library" "Adafruit LED Backpack Library"
```

### Compile

```sh
arduino-cli compile --fqbn arduino:megaavr:nona4809 Shredometer_Datalogger
```

Compiling currently reports ~63% flash and ~24% RAM used, leaving about
4.6 KB free for local variables — comfortable headroom on the Nano Every's
ATmega4809. (An earlier revision of this sketch targeted a classic Nano,
which has a third of the flash and RAM; on that chip the same code left
under 100 bytes free, which is why the resource-tightness warning used to
live here. If you're building for a classic Nano, use `arduino:avr:nano`
and `arduino:avr` instead, and budget for that headroom.)

### Upload

Your serial port permissions need to allow access to the board. On Arch,
that means being in the `uucp` group (elsewhere, often `dialout`):

```sh
sudo usermod -aG uucp $USER   # then log out and back in
```

Plug in the board, find its serial port, then:

```sh
arduino-cli board list                 # find the port, e.g. /dev/ttyACM0
arduino-cli upload -p /dev/ttyACM0 --fqbn arduino:megaavr:nona4809 Shredometer_Datalogger
```

### Monitor

```sh
arduino-cli monitor -p /dev/ttyACM0 -c baudrate=115200
```

## Usage

1. Power on. The LED display cycles `2.2:2.2` → `1.1:1.1` → `0.0:0.0` as the
   IMU and SD card initialize.
2. Once at `0.0:0.0`, press the start button to begin logging.
3. Data is written to the next available `DL_N.TXT` file on the SD card
   (`DL_0.TXT`, `DL_1.TXT`, ...), as CSV with a header row.
4. The display shows `instantaneous shred score : max shred score` (in g),
   updated every 15 samples. Below 10g, each side shows one decimal place
   (e.g. `7.3`). At 10g and above, that side shows a whole number instead
   (e.g. `12`), since the display can't fit both an extra digit and the
   decimal.

## Analyzing logs

`scripts/analyze_log.py` parses a `DL_N.TXT` file and prints summary stats
(sample count, duration, sample rate, peak/mean shred score). It skips rows
damaged by a bad SD write (a run of `0xFF` mid-line) and reports how many it
dropped; `DL_61.TXT` contains one such row.

```sh
python3 -m venv .venv
.venv/bin/pip install -r scripts/requirements.txt
.venv/bin/python scripts/analyze_log.py path/to/DL_0.TXT
```

It can also produce output in two formats:

- `-o plot.png` — a static matplotlib plot of acceleration and shred score.
- `-H report.html` — a self-contained, interactive HTML report (open it in
  any browser, no server needed): acceleration and shred-score charts with
  hover tooltips, drag-to-zoom, a per-axis legend, and a per-minute data
  table. Uses `scripts/report_template.html` as its template.

```sh
.venv/bin/python scripts/analyze_log.py path/to/DL_0.TXT -H report.html
```

Pass `--accel-range` to set where the accelerometer saturates, in g. It
controls the report's clipping detection and the reference line on the
shred-score chart.

The default is `24`, which looks wrong next to the firmware's
`LSM9DS1_ACCELRANGE_16G` but is correct. The LSM9DS1's "±16 g" mode has a
sensitivity of 0.732 mg/LSB, and a full-scale int16 reading of 32767 counts
is therefore 23.99 g, not 16 g. The Adafruit library scales by 9.80665, so
the rail lands at 235.20 m/s², which this script's `G = 9.8` turns into
exactly 24.0000 g. The datasheet's range label and its sensitivity constant
disagree; the sensitivity is what the hardware does. DL_61 confirms it: 61
samples sit on 235.20 m/s² and nothing goes past it.

Use `--accel-range 6` for any log captured before the 16G change (the same
1.5x applies to the "±4 g" setting).

Two things follow from this that are easy to get wrong when reading a report:

- The rail is **per axis**. The shred score is a 3-axis magnitude, so it can
  legitimately reach √3 × 24 = 41.6 g with no axis railing. A shred score
  above 24 g is not by itself evidence of clipping.
- A sample with an axis on the rail was truncated, so its shred score is a
  lower bound, not a measurement. In DL_61 that includes the headline 35.07 g
  peak, and 20 of the top 30 hits.

## Questions to ask and answer

- What's the "correct" ceiling to set? The LSM9DS1 has no range above the
  one we're already using, and DL_61 railed 61 times against DL_55's 2, so
  answering this probably means a different accelerometer. See "Sensor
  limits" below.
- Does not having the Shredometer _firmly_ mounted to the bike have an impact on
  the data? If it's on there really firmly, do we get "cleaner" data?
- Does the starting angle of the Shredometer have any impact on the data? Right
  now it's sitting at an angle because it's attached to the downtube like a
  water bottle might be.
- Does the positioning of the accelerometer on the bike have an impact on the
  data? What if I put it on the rear triangle, which has all the suspension
  motion?
- Do we need any kind of calibration? At the start of a session? Based on
  anything the rider is doing?

## Sensor limits

Two separate ceilings constrain the data, and they are easy to confuse.

### 1. Amplitude: the 24 g per-axis rail

Covered under "Analyzing logs" above. DL_61 railed 61 times; DL_55 railed
twice. The tail of the unrailed distribution falls off by a factor of e
every ~3.5 g, so clearing DL_61 entirely would need roughly
24 + 3.5 x ln(61) = **~38 g**. A ±50 g or ±100 g part would leave margin for
a harder ride. The LSM9DS1 has nothing above the range we already use, so
this means a different accelerometer (the usual shock-logging parts are the
ADXL375 at ±200 g or the H3LIS331DL at ±100/200/400 g).

### 2. Bandwidth: we are aliasing, and this is the bigger problem

The accelerometer's real output data rate is **952 Hz**, with a 408 Hz
anti-aliasing filter. We poll it at 113 Hz. Nyquist is 56.6 Hz, so
everything between 56.6 Hz and 408 Hz folds back down into the measurement.

This is not obvious from the sketch. `setupSensor()` calls
`lsm.setupAccel(lsm.LSM9DS1_ACCELRANGE_16G)` with one argument, and the
library's second parameter defaults to `LSM9DS1_ACCELDATARATE_10HZ` — so the
code appears to ask for 10 Hz. It does not get it. On the LSM9DS1, whenever
the gyroscope is powered on, the accelerometer ODR is dictated by `ODR_G` in
`CTRL_REG1_G` and the `ODR_XL` bits are ignored. `begin()` writes
`CTRL_REG1_G = 0xC0`, which is 952 Hz. The log confirms this: no two
consecutive accelerometer readings in DL_61 are identical, which could not
happen at a 10 Hz ODR polled at 113 Hz.

The aliasing shows up in the spectrum. Accelerometer power does not roll off
toward Nyquist the way a band-limited signal must — the 40-56.6 Hz band still
holds 29% as much power as the entire 0-10 Hz band. That energy is folded in
from above.

The practical consequence: **a recorded peak is not a repeatable measurement
of an impact.** A frame hit rings in the hundreds of Hz. What we log is
whatever the ring happened to be at the instant we polled. Two identical hits
will produce different numbers. Raising the range without fixing this gives
bigger numbers that are still not reproducible.

### What the firmware now does about it (not yet flashed)

The sketch oversamples. `loop()` reads only the accelerometer as fast as the
bus allows, tracks the largest magnitude it sees, and writes a row every
`LOG_INTERVAL_MS` (8 ms, so ~125 Hz). The row carries both the single
instantaneous reading it always did *and* the peak across the burst.

Three supporting changes went with it:

- I2C now runs at 400 kHz instead of 100 kHz, which fits about four times as
  many reads into each window.
- `setupAccel()` states the 952 Hz data rate explicitly. This changes no
  behavior — `ODR_G` already governed it — but the call no longer reads as
  though it asks for 10 Hz.
- The LED display's shred score comes from the burst peak rather than one
  instantaneous sample, so it shows the hardest hit in the window.

### 3. The I2C bus is the real bottleneck (measured on hardware)

An on-board diagnostic settled how much the oversampling actually buys. At the
current 100 kHz bus speed:

| Measurement | Value |
|---|---|
| One `readAccel()` | **946 us** |
| One logged row, no SD write | 6.5 ms |
| One logged row, with SD (from the 113 Hz in real logs) | ~8.8 ms |
| Spare time in an 8 ms window | ~1.5 ms |
| Extra oversampled reads that fit | **1** |

A new sensor sample arrives every 1050 us at 952 Hz, and a single read costs
946 us. **At 100 kHz the bus can barely move one sample in the time the sensor
produces one**, and the per-row work consumes the window on its own. Six bytes
per sample at 952 Hz is 5.7 kB/s, against roughly 5.5 kB/s of usable 100 kHz
I2C throughput. We are at the wire's limit, not the sensor's.

So the oversampling as it stands gains about one extra reading per row. It is
kept because it is correct and becomes valuable the moment the bus is faster,
but it does not fix the peaks by itself.

**400 kHz is not available on this wiring.** It hung the bus on two separate
runs: the first `readAccel()` after `Wire.setClock(400000)` never returns, and
only a power cycle clears it.

The cause is almost certainly the cable to the bar-mounted display. That cable
puts the LED backpack on the far end of roughly a metre of wire, and its
capacitance sits across the same bus the accelerometer uses. Fast mode allows
a 300 ns rise time; with the two breakouts' pull-ups in parallel (about 5k)
the bus does not meet it:

| Bus capacitance | Pull-ups 5k | Pull-ups 2.2k |
|---|---|---|
| 60 pF (bench wiring only) | 254 ns — OK | 112 ns — OK |
| 100 pF (~0.7 m to the bars) | **424 ns — over** | 186 ns — OK |
| 150 pF (~1.2 m to the bars) | **635 ns — over** | 280 ns — OK |

So 400 kHz is not out of reach: it needs 2.2k pull-ups, which is a one-dollar
fix. Note that this stops mattering once the accelerometer moves to SPI, since
the I2C bus would then carry only the display, which updates a few times a
second and does not care about bus speed.
The sketch no longer sets 400 kHz.

Note that a wedged bus *can* be cleared in software, without a power cycle:
clock SCL up to 16 times until the stuck slave releases SDA, then issue a
manual STOP. The diagnostic does this at startup and recovers reliably. Worth
adding to the datalogger if the bus ever wedges during a ride.

**What this means for the FIFO.** Draining 32 FIFO samples is 192 bytes, which
at 100 kHz takes about 17 ms — longer than the logging window it is meant to
fill. The FIFO does not help until the bus is faster. Raising the bus speed
(or moving the accelerometer to SPI) comes first; the FIFO comes after.

Do all of this before buying a new accelerometer. It is the cheap experiment,
and it sizes the amplitude problem properly: with a real peak-hold the 24 g
rail will be hit far more often than 61 times, which is what tells us how
much range we actually need.

## Log format

Rows are CSV with a header. The first ten columns are unchanged from earlier
logs, so old files and new ones parse the same way:

| Column | Meaning |
|---|---|
| `Time Elapsed (ms)` | milliseconds since logging started |
| `Accel X/Y/Z (m/s^2)` | one instantaneous reading, as before |
| `Mag X/Y/Z (uT)` | magnetometer |
| `Gyro X/Y/Z (rad/s)` | gyroscope |
| `Peak \|a\| (m/s^2)` | **new** — largest acceleration magnitude across every oversampled read since the previous row |
| `Burst Samples` | **new** — how many reads that peak covers |

Keep the instantaneous columns for anything distributional: means, spectra,
and orientation all stay valid, and they stay comparable with DL_46 through
DL_61. Use `Peak |a|` for anything about impacts.

`scripts/analyze_log.py` does not read the two new columns yet. It still
computes the shred score from the instantaneous accelerometer columns, so it
runs unchanged on both old and new logs. Switching the shred score over to
`Peak |a|` is a small change, but it would make new reports incomparable with
the existing ones, so it should wait until there is a log to test it against.

## Mk2

The next version replaces the Nano Every and the LSM9DS1 with a XIAO
nRF52840 Sense and an ADXL375 (±200 g, SPI), logs binary at 1 kHz, and puts
the electronics in a printed case that bolts straight to the bottle bosses.
The staged plan, bill of materials, vendor list, and open decisions are in
[docs/mk2.md](docs/mk2.md). Parts are ordered as of 2026-09-07.

## To build

- A snap-in cage that mounts to standard water bottle mounts. The current
  attempt is `hardware/bottle_cage_mount.scad` (v2 cradle, unproven on a
  print). Mk2 replaces it with a case that is its own mount; see
  [docs/mk2.md](docs/mk2.md).
- A handlebar mount for the screen.

## To do

- **Teach `analyze_log.py` about `Peak |a|`.** The firmware now logs a
  peak-held magnitude per row (see "Log format"), and the script still
  ignores it: the shred score comes from the instantaneous accelerometer
  columns. Switching over would make peaks meaningful, but it also makes new
  reports incomparable with DL_46 through DL_61, so it needs a deliberate
  choice: either a `--peak` flag, or report both series side by side. Wait
  for a log that actually has the column before doing it.
- **Get the accelerometer off the shared 100 kHz I2C bus.** This is the
  binding constraint on data quality (see "Sensor limits"). Either fix the
  pull-ups so 400 kHz is stable, or put the accelerometer on SPI. The FIFO
  and any higher-range sensor both depend on this being solved first.
- **Uploads need `pyserial`, not `arduino-cli monitor`.** Reading this board's
  serial output requires DTR asserted. `arduino-cli monitor` and `cat
  /dev/ttyACM0` both return nothing; a short pyserial script works. Note also
  that `avrdude` prints `jtagmkII_initialize(): Cannot locate "flash" and
  "boot" memories in description` on every upload. It is harmless — the flash
  write completes and reports its byte count.
