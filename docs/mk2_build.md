# Mk2 build guide

Bench build of the Phase 2 logger on the 5 x 7 cm protoboard. See
[mk2.md](mk2.md) for the plan and the parts list. Phase 1 was skipped: all
the parts arrived together on 2026-09-12, so the ADXL375 goes straight onto
the XIAO.

Parts on hand: XIAO nRF52840 Sense Plus, ADXL375 breakout (Adafruit 5374),
microSD breakout+ (Adafruit 254), LiPo with JST, slide switch, tactile
button, 2.2k resistors, the existing HT16K33 bar display. Not bought: the
5 V boost and the BSS138 level shifter.

## Wiring

All logic is 3.3 V. Every module gets its power from the XIAO's 3V3 pin.

| XIAO pin | nRF52 port | Goes to |
|---|---|---|
| 3V3 | | ADXL375 VIN, microSD **3V** (not 5V, see below), display +, both pull-ups |
| GND | | ADXL375 GND, microSD GND, display -, button, switch |
| D8 | P1.13 | SCK: ADXL375 SCL and microSD CLK |
| D10 | P1.15 | MOSI: ADXL375 SDA and microSD DI |
| D9 | P1.14 | MISO: ADXL375 SDO and microSD DO |
| D3 | P0.29 | ADXL375 CS |
| D2 | P0.28 | microSD CS |
| D0 | P0.02 | ADXL375 INT1 (data ready; wire it now, the logger uses it later) |
| D4 | P0.04 | SDA: display SDA, with 10k to 3V3 |
| D5 | P0.05 | SCL: display SCL, with 10k to 3V3 |
| D1 | P0.03 | Start button; other side to GND (`INPUT_PULLUP`, pressed = LOW) |
| BAT+ pad | | Slide switch, then LiPo red wire |
| BAT- pad | | LiPo black wire |

The BAT pads are on the underside of the XIAO, next to the USB-C connector.
They are pads, not pins, so the battery wires solder directly to them. Keep
those two leads short and strain-relieve them with a dab of hot glue.

Notes on the choices:

- **microSD power goes to its 3V pin, not its 5V pin.** The 5V pin feeds
  the breakout's regulator. With only 3.3 V in, the regulator sits at its
  dropout, and the card browns out during its own initialization, which is
  its highest-current moment. Symptoms: init errors 0x17 (card stuck in
  idle) or 0x12 (card lost right after reporting ready), while a meter
  still shows 3.3 V at idle. Feeding the 3V pin directly bypasses the
  regulator; Adafruit's forum confirms it as an input on 3.3 V systems.
  Leave the 5V pin empty and never put 5 V on that board.
- **One SPI bus, two devices.** The ADXL375 uses SPI mode 3 and the SD card
  uses mode 0. That is fine: each library sets the mode inside its own
  transaction. What matters is that each device releases MISO when its CS
  is high. The ADXL375 does. The microSD breakout+ has a level-shifter
  buffer on DO for this reason. The bring-up sketch tests it.
- **ADXL375 CS.** The breakout ties CS to 3.3 V through a resistor to
  default to I2C. Driving CS from D3 overrides that. Keep CS high when idle,
  which the sketch does.
- **Button.** `INPUT_PULLUP`, button to ground. No external resistor. This
  is the opposite polarity from the Mk1 wiring.
- **Switch in the battery line.** The simplest safe power switch. With the
  switch off and USB plugged in, the XIAO runs from USB but the cell does
  not charge. Turn the switch on to charge.
- **Charge current.** Default is 50 mA. The sketch drives P0.13 low for
  100 mA, which is 0.2 C for a 500 mAh cell. Do not use 100 mA with a cell
  under 200 mAh.
- **Display voltage.** The HT16K33 datasheet says 4.5 to 5.5 V. The
  backpack usually runs at 3.3 V, dimmer. Its input-high threshold is
  0.7 x VDD, so at 5 V it wants 3.5 V logic and the XIAO gives 3.3 V. Run
  it at 3.3 V for now and judge brightness outdoors. If it is too dim, buy
  the boost converter and the level shifter and run it at 5 V.

## Layout on the protoboard

Physical placement is up to you, but these matter:

1. **The ADXL375 is the reference part.** Solder it flat and square to the
   board edges. Write down which board edge each sensor axis points along,
   because the case design and the analysis both need it. The axis arrows
   are printed on the breakout.
2. **XIAO at one short edge**, USB-C facing out. It must be reachable for
   flashing and for USB readout once the case exists.
3. **microSD at the other short edge**, slot facing out, so a card can go
   in without lifting the board.
4. **Button and switch on a long edge.** They will poke through the case
   wall later.
5. **LiPo under the board**, held with a foam pad. Do not put it under
   the ADXL375.

Use male headers on every module, solder the headers into the protoboard,
and run the 28 AWG silicone wire on the underside. Solder each end of a
wire before cutting the next one, and check each net with the multimeter's
continuity beeper before applying power.

## Bench log

**2026-09-12.** XIAO (a Sense Plus) soldered to the perfboard, nothing else
wired. Bring-up sketch flashed and reporting. Results with nothing wired:
ADXL375 fail, microSD fail, display no ACK, button released, battery about
3.7 V with no cell (the charger's open output). All as expected.

**The onboard IMU did not answer, now solved (2026-09-13).** Its internal
I2C bus (P0.07 SDA, P0.27 SCL) read low on both lines, on two different
Sense Plus boards, with the IMU supply pin P1.08 driven high. Seeed's
KiCad source for the Plus shows the IMU and its two 10k bus pull-ups all
fed from P1.08, exactly like the Sense. The cause: in the nRF52's standard
GPIO drive, P1.08 sags under the IMU's load and never reaches a high
level (it reads back low). In high-drive mode (`OUTPUT_H0H1`) it comes up,
and the bus follows within a millisecond. The plain Sense gets away with
standard drive; the Plus does not. Any code that powers this IMU on the
Plus must set the pin to high drive before the library's `begin()`. The
Seeed LSM6DS3 library does not, so it fails on the Plus as shipped. The
bring-up sketch does it. Gyro is back on the table.

**2026-09-12, later.** ADXL375 on female-female jumpers to the XIAO
headers. It answers: ID 0xE5, BW_RATE 0x0F (3200 Hz), DATA_FORMAT 0x0B,
POWER_CTL 0x08. Library path: 138 us per sample, about 6300 reads/s. Burst
path, 3000 samples at rest: mean vector 0.86 g (zero-g offset, per
datasheet), rms 0.16 to 0.19 g per axis (normal noise at 3200 Hz), 7 wild
samples including one all-zero triple. The wild samples are the jumpers,
not the sensor. Next: solder the seven wires, rerun, expect zero outliers.
The logger firmware must drop all-zero samples as a guard regardless.

**2026-09-12, ADXL375 soldered.** Seven wires on the underside. Report:
ID 0xE5, mean vector 0.67 g (x +0.60, y -0.02, z +0.29: zero-g offset,
needs a six-position trim later), rms 0.18 to 0.22 g per axis, minimum
0.10 g, maximum 1.83 g, no all-zero samples. The jumper glitches are gone.
Live resting peak through the library path is about 2.5 g: that is the
noise floor of 6300 raw samples a second at 3200 Hz bandwidth, and the
logger must not report raw single-sample peaks. Lower the bandwidth or
average a few samples, or both.

**2026-09-13, microSD.** Wired per the table, first with power on the
breakout's 5V pin: init failed every time (codes 0x17 and 0x12). Moved
power to the 3V pin: passes. Card 7580 MB FAT32. Write test, 200 x 512 B:
mean 1.8 ms, worst 38 ms. SPI bus sharing passes: the ADXL375 answers
after SD traffic. Onboard IMU passes on this board too with the
high-drive fix. Remaining: display, button, battery.

One trap for anyone probing the MISO line: the ADXL375 breakout has a
10k pull-down on SDO (it sets the I2C address). With nothing driving the
bus, MISO reads low against the MCU's pull-up. That is not a fault, and
it makes "DO stuck low" readings meaningless on this board.

**Logger buffer sizing.** A 38 ms SD stall at 1 kHz and 10 bytes per
sample is 380 bytes. A 4 KB ring buffer covers ten times that. RAM is not
a constraint; the nRF52840 has 256 KB.

**2026-09-13, display.** HT16K33 backpack on D4/D5 with one 10k pull-up
per line to 3V3, powered from 3V3, over the existing bar cable. Passes:
ACK at 0x70, shows 8888, then the live peak. Brightness outdoors not yet
judged; that decides the boost converter and level shifter. Note the
backpack's pins are labelled SDA and SCL, not D and C. Remaining: button,
switch and battery.

## Order of work

Do the steps in this order. Run the bring-up sketch after each step and
read the report. Each subsystem reports on its own, so a half-wired board
gives a half-passing report, which is what you want.

1. **Solder the headers.** ADXL375, microSD breakout, XIAO. Tin the iron,
   flux the pads, one pin at a time. Check for bridges with the beeper.
2. **Flash the bring-up sketch with nothing wired.** Confirm the toolchain
   and the USB serial link. Expect every test to fail except the onboard
   IMU, the button, and the battery.
3. **Wire power and the ADXL375.** 3V3, GND, SCK, MOSI, MISO, CS, INT1.
   Expect `PASS ADXL375` with ID 0xE5 and about 1.0 g at rest.
4. **Wire the microSD.** Add CLK, DI, DO, CS, and power to its 3V pin.
   Put a formatted FAT32 card in. Expect `PASS microSD`, `PASS microSD write`, and
   `PASS SPI bus sharing`. Note the worst-case write time; it sets the
   logger's buffer size.
5. **Wire the display.** SDA to D4, SCL to D5, + and -, and one 10k
   pull-up from each data line to 3V3. Expect 8888 on the display.
6. **Wire the button.** Expect the live line to flip to PRESSED.
7. **Solder the switch and the battery.** Expect a battery reading between
   3.0 and 4.2 V. Unplug USB and confirm the board runs on the cell.
8. **Measure everything with calipers** and update the footprint table in
   [mk2.md](mk2.md). This unblocks the case design.

## Toolchain

Installed on 2026-09-12:

```
arduino-cli config add board_manager.additional_urls https://files.seeedstudio.com/arduino/package_seeeduino_boards_index.json
arduino-cli core update-index
arduino-cli core install Seeeduino:nrf52
arduino-cli lib install "Adafruit ADXL375"
python3 -m venv ~/.local/share/adafruit-nrfutil-venv
~/.local/share/adafruit-nrfutil-venv/bin/pip install adafruit-nrfutil
ln -s ~/.local/share/adafruit-nrfutil-venv/bin/adafruit-nrfutil ~/.local/bin/
```

Use the `Seeeduino:nrf52` core, not the mbed one. It is the Adafruit-derived
core with TinyUSB, which is what USB mass-storage readout will need later.
The core needs `adafruit-nrfutil` on the PATH to build and upload. There is
no pipx on this machine, hence the venv.

Two library traps, both hit on 2026-09-12:

- **Do not install the SdFat library.** The core bundles SdFat 2.2.1, and
  the current library-manager release (2.3.0) fails to compile against this
  core's Print class. If `arduino-cli lib list` shows SdFat, uninstall it.
- **The Seeed LSM6DS3 library needs two things on the Sense Plus.** The
  right board target, so it picks the internal bus (Wire1): this core
  defines `TARGET_SEEED_XIAO_NRF52840_SENSE_PLUS`, so that part is fine.
  And the IMU power pin in high-drive mode, which the library does not do.
  Call `pinMode(PIN_LSM6DS3TR_C_POWER, OUTPUT_H0H1)` and drive it high
  before `begin()`. See the bench log. Also note `Adafruit_TinyUSB.h` must
  be included in any sketch that uses `Serial` but no other core library;
  `Wire.h` or `SPI.h` pull it in, a bare sketch does not link.
- **Never do an address-only I2C probe on this core.** The nRF52 Wire
  driver has no timeouts, and `endTransmission()` with zero data bytes
  waits forever for a start event that never comes. Always write at least
  one byte before `endTransmission()`. An I2C scanner sketch written for
  AVR hangs here for this reason.

**Which board.** The unit on the bench identifies its bootloader over USB
as "XIAO nRF52840 Sense Plus" (vendor 2886, product 0065). The plain Sense
bootloader is product 0045. Check with `lsusb -d 2886:` while the board is
in the bootloader. Build for the board you have. D0 to D10 are the same on
both, but the battery, charger, and IMU pin macros differ.

```
scripts/flash_xiao.sh Shredometer_Mk2_Bringup
```

The script compiles, then flashes the right way for the board's state. If
the board is running an app, it uses `arduino-cli upload`. If the board is
already in its bootloader, it calls `adafruit-nrfutil` directly, because
arduino-cli's 1200-baud port touch breaks a bootloader that is already
waiting and the upload fails with "No data received on serial port".
Set `FQBN=Seeeduino:nrf52:xiaonRF52840Sense` in the environment for a
plain Sense.

The bring-up sketch runs its tests when a host opens the port, not at
boot, so the report is never missed. Send `r` in the monitor to run the
tests again after wiring the next subsystem. No reflash needed.

**Serial monitor.** The XIAO is USB CDC, so any terminal works, unlike the
Nano Every. Start the monitor only after the upload has finished and the
board has come back.

```
arduino-cli board list
arduino-cli monitor -p /dev/ttyACM0 -c baudrate=115200
```

The board disconnects and re-enumerates on every upload and every reset.
A monitor that was open across that event keeps a dead handle and shows
nothing forever, and the board can come back as `/dev/ttyACM1` while the
dead handle holds `/dev/ttyACM0`. If the monitor sits at "Connecting",
press Ctrl-C, run `arduino-cli board list` to find the current port, and
start the monitor again. Never leave a monitor open during an upload: it
can also wedge the bootloader's DFU session, which then needs a USB
unplug and replug to recover.

If the upload cannot find the board, double-tap the reset button on the
XIAO. The board enters its bootloader and shows up as a USB drive. Upload
again.

## What the bring-up report should look like

```
Shredometer Mk2 bring-up
------------------------
PASS  ADXL375: ID 0xE5, 30 us per sample, at rest |a| = 1.02 g (expect ~1.0)
PASS  microSD: card 7580 MB, FAT32
PASS  microSD write: 200 x 512 B: mean 900 us, worst 45000 us
PASS  SPI bus sharing: ADXL375 still answers after SD use
PASS  LSM6DS3 (onboard): WHO_AM_I 0x6A (expect 0x6A or 0x69)
PASS  HT16K33 display: ACK at 0x70, showing 8888. Judge brightness at 3.3 V by eye.
PASS  Button: reads released
PASS  Battery: 3.87 V (3.0 empty, 4.2 full; ~0 V means no cell on BAT pads)
```

The timing numbers above are placeholders. Record the real ones here.
