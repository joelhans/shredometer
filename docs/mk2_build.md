# Mk2 build guide

Bench build of the Phase 2 logger on the 5 x 7 cm protoboard. See
[mk2.md](mk2.md) for the plan and the parts list. Phase 1 was skipped: all
the parts arrived together on 2026-09-12, so the ADXL375 goes straight onto
the XIAO.

Parts on hand: XIAO nRF52840 Sense, ADXL375 breakout (Adafruit 5374),
microSD breakout+ (Adafruit 254), LiPo with JST, slide switch, tactile
button, 2.2k resistors, the existing HT16K33 bar display. Not bought: the
5 V boost and the BSS138 level shifter.

## Wiring

All logic is 3.3 V. Every module gets its power from the XIAO's 3V3 pin.

| XIAO pin | nRF52 port | Goes to |
|---|---|---|
| 3V3 | | ADXL375 VIN, microSD 5V (its regulator accepts 3.3 to 6 V), display +, both pull-ups |
| GND | | ADXL375 GND, microSD GND, display -, button, switch |
| D8 | P1.13 | SCK: ADXL375 SCL and microSD CLK |
| D10 | P1.15 | MOSI: ADXL375 SDA and microSD DI |
| D9 | P1.14 | MISO: ADXL375 SDO and microSD DO |
| D3 | P0.29 | ADXL375 CS |
| D2 | P0.28 | microSD CS |
| D0 | P0.02 | ADXL375 INT1 (data ready; wire it now, the logger uses it later) |
| D4 | P0.04 | SDA: display D, with 2.2k to 3V3 |
| D5 | P0.05 | SCL: display C, with 2.2k to 3V3 |
| D1 | P0.03 | Start button; other side to GND (`INPUT_PULLUP`, pressed = LOW) |
| BAT+ pad | | Slide switch, then LiPo red wire |
| BAT- pad | | LiPo black wire |

The BAT pads are on the underside of the XIAO, next to the USB-C connector.
They are pads, not pins, so the battery wires solder directly to them. Keep
those two leads short and strain-relieve them with a dab of hot glue.

Notes on the choices:

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
4. **Wire the microSD.** Add CLK, DI, DO, CS, and power. Put a formatted
   FAT32 card in. Expect `PASS microSD`, `PASS microSD write`, and
   `PASS SPI bus sharing`. Note the worst-case write time; it sets the
   logger's buffer size.
5. **Wire the display.** D, C, +, -, and the two 2.2k pull-ups. Expect
   8888 on the display.
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
- **The Seeed LSM6DS3 library talks to the wrong bus on this core.** The
  Sense's IMU is on an internal second I2C bus (Wire1) and the library only
  switches to it under the mbed core. The bring-up sketch reads WHO_AM_I on
  Wire1 directly. The logger firmware will need the same treatment, or the
  build flag `-DTARGET_SEEED_XIAO_NRF52840_SENSE`.

```
arduino-cli compile --fqbn Seeeduino:nrf52:xiaonRF52840Sense Shredometer_Mk2_Bringup
arduino-cli upload -p /dev/ttyACM0 --fqbn Seeeduino:nrf52:xiaonRF52840Sense Shredometer_Mk2_Bringup
```

If the upload cannot find the board, double-tap the reset button on the
XIAO. The board enters its bootloader and shows up as a USB drive named
XIAO-SENSE. Upload again.

Serial monitor: the XIAO is USB CDC, so any terminal works, unlike the
Nano Every.

```
arduino-cli monitor -p /dev/ttyACM0 -c baudrate=115200
```

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
