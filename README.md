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
  file, caused by a doubled line ending.

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
(sample count, duration, sample rate, peak/mean shred score).

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

Pass `--accel-range` if it differs from the sketch's `setupAccel()` setting
— it controls the report's clipping detection and the reference line on the
shred-score chart. The default is `16`, matching the current firmware's
`LSM9DS1_ACCELRANGE_16G`. Use `--accel-range 4` for any log captured before
that change.

## Questions to ask and answer

- What's the "correct" celing to set?
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

## To build

- A snap-in cage that mounts to standard water bottle mounts.
- A handlebar mount for the screen.
