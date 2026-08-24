# Shredometer

Arduino Nano datalogger for a 9-DOF IMU (LSM9DS1), originally written by Ryan T
Cutshall (last updated 17 Sep 2022). Logs accelerometer/magnetometer/gyroscope
readings to an SD card at high rate and displays a rolling "shred score"
(peak acceleration in g) on a 7-segment LED display.

## Hardware

- Arduino Nano
- Adafruit LSM9DS1 9-DOF breakout (I2C)
- microSD card module (SPI)
- Adafruit 0.56" 4-digit 7-segment LED backpack (I2C, address `0x70`)
- Momentary push button

### Wiring

| Signal              | Nano pin |
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
arduino-cli core install arduino:avr
arduino-cli lib install "Adafruit LSM9DS1 Library" "Adafruit GFX Library" "Adafruit LED Backpack Library"
```

### Compile

```sh
arduino-cli compile --fqbn arduino:avr:nano Shredometer_Datalogger
```

Note: this sketch is tight on resources on the Nano — compiling currently
reports ~91% flash and ~93% RAM used, leaving only ~137 bytes free for local
variables. If you see erratic behavior (garbled serial output, hangs), this
is the likely first suspect (heap fragmentation from the `String` usage
throughout the sketch is a common culprit on AVR).

### Upload

Plug in the Nano, find its serial port, then:

```sh
arduino-cli board list                 # find the port, e.g. /dev/ttyUSB0
arduino-cli upload -p /dev/ttyUSB0 --fqbn arduino:avr:nano Shredometer_Datalogger
```

### Monitor

```sh
arduino-cli monitor -p /dev/ttyUSB0 -c baudrate=115200
```

## Usage

1. Power on. The LED display cycles `2.2:2.2` → `1.1:1.1` → `0.0:0.0` as the
   IMU and SD card initialize.
2. Once at `0.0:0.0`, press the start button to begin logging.
3. Data is written to the next available `DL_N.TXT` file on the SD card
   (`DL_0.TXT`, `DL_1.TXT`, ...), as CSV with a header row.
4. The display shows `max shred score : instantaneous shred score` (in g),
   updated every 15 samples.

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

Pass `--accel-range` (default `4`, matching the sketch's
`LSM9DS1_ACCELRANGE_4G` setting) if you change the firmware's accelerometer
range — it controls the report's clipping detection and the reference line
on the shred-score chart.
