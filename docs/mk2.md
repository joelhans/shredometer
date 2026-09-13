# Shredometer Mk2

A staged plan for rebuilding the logger around a sensor that can see the
real hits, on a bus fast enough to carry them, in a case that is its own
bottle mount.

Written 2026-08-30 from DL_55, DL_61, and on-board timing. Originally a
Claude artifact:
https://claude.ai/code/artifact/996e3555-30bf-40b6-853d-b44880566f15.
This file is the copy of record. Update it here.

Status (2026-09-12): all Phase 2 parts are on hand. Phase 1 is skipped: the
ADXL375 goes straight onto the XIAO. The bench build is in
[mk2_build.md](mk2_build.md), with the bring-up sketch in
`Shredometer_Mk2_Bringup/`. No logger firmware yet. No Mk2 CAD yet;
`hardware/` still holds the v2 cradle for the current enclosure, which Mk2
replaces.

## Why a rebuild, not a part swap

Three ceilings, and they are coupled:

1. **Amplitude.** The LSM9DS1 rails at 24 g. DL_61 hit that 61 times, and
   20 of its top 30 hits are floors, not measurements. The LSM9DS1 has no
   higher range.
2. **Bus.** One `readAccel()` costs 946 µs on the 100 kHz I2C bus. A new
   sample arrives every 1050 µs. 400 kHz wedges the bus, almost certainly
   because of the cable to the bar display (see "Sensor limits" in the
   README).
3. **Bandwidth.** Logging at 113 Hz against a 408 Hz sensor bandwidth
   aliases ring-down into the data. Peaks are not repeatable.

A bigger sensor on the same bus gives the same aliasing at coarser
resolution. The size problem is downstream of this: the enclosure is
99 x 55 x 43 mm because it houses a Nano Every plus three breakouts and
their wiring. The electronics want about 40 x 25 mm.

The mount is the other reason. The v1 cradle failed on its first ride, and
v2 is four printed parts, eight screws, and four foam pads whose only job is
to grip a box that was never designed to be gripped. If the case is the
mount, none of that has to exist.

## Phases

Each phase is useful on its own. Do them in order: each answers a question
the next depends on.

### Phase 1: prove the sensor

Wire an ADXL375 breakout to the existing Nano Every over SPI, alongside the
existing hardware. Ride once. Look at the peaks.

- **Answers:** how hard the bike actually hits. The 38 g figure in the
  README is an extrapolation from clipped, aliased data.
- **Why SPI:** the I2C bus is saturated. The SD card is already on SPI; the
  ADXL375 needs only its own chip-select pin.
- **Also try:** 2.2k pull-ups on SDA and SCL, then retry 400 kHz. The two
  breakouts' pull-ups in parallel are about 5k, which across a metre of
  cable gives roughly a 424 ns rise time. Fast mode allows 300 ns. At 2.2k
  the bus lands near 186 ns.
- **If you stop here:** you know the range to specify, and you have a
  working high-g logger in the old box.

### Phase 2: prove the architecture

Replace the Nano Every with a XIAO nRF52840 Sense, switch the log format
from CSV to binary, and target 1 kHz logging. Confirm the rate with the
burst counter already in the firmware. The display stays wired as it is.

- **Why nRF52840, not RP2040:** wireless is planned for Phase 3, so pick
  the radio-capable part now and port the firmware once. 64 MHz over SPI
  covers 1 kHz logging with room to spare. It also has onboard LiPo
  charging.
- **Why Sense:** the Sense variant has a 6-axis IMU onboard, which covers
  the gyro at no extra part. No magnetometer, which nothing uses.
- **Why binary:** a CSV row is about 65 bytes. Three `int16` values plus a
  timestamp is 8 to 10. Eight times the rate for the same file size.
- **Proves:** that aliasing is gone. Sample above about 800 Hz and the
  folding stops.
- **Bench build:** hand-wired on a 5 x 7 cm FR4 protoboard. Its layout sets
  the post positions and cavity for the Phase 4 case, so build this before
  designing the case.
- **If you stop here:** the data is valid. Correct amplitude, no aliasing.
  Everything after is size and convenience.

### Phase 3: carrier PCB and the radio link

A small board (about 40 x 25 mm) with footprints for the breakouts, not
bare chips. KiCad, JLCPCB or PCBWay or OSH Park, order five.

- **Cutting the cable means a second device.** The bar end needs its own
  MCU, cell, charging, enclosure, firmware, and a reconnect story. That is
  the real cost of wireless, not the radio.
- **Sequence:** logger board first. Leave the bar end as a hand-wired plain
  XIAO nRF52840 plus the existing HT16K33 display for a while.
- **Why BLE:** it is what the nRF52840 is built for, and a phone can talk
  to the logger too.

### Phase 4: case as mount

One printed body with the bottle-boss bolt pattern through it, and a
bolt-on lid. The spine, both collars, the separate lid, and the foam pads
stop existing.

- **Governing constraint:** 64 mm bolt spacing. The body spans both bosses,
  so it lands near 85 mm long. Target about 85 x 35 x 20 mm, one body plus
  one lid, about 60 cm³ against the current 234 cm³.
- **Carries over from `hardware/bottle_cage_mount.scad`:** the M5
  counterbore geometry, the captive M3 nut scheme for the lid, and the
  print-orientation and volume-intersection checks.
- **Structure:** boards on printed posts inside a rigid body. No sliding
  fit, no `FIT_CLEARANCE`, no foam. Foam was a mechanical filter with an
  uncharacterised transfer function, so removing it also removes an
  unknown from the data.
- **Bolt heads:** recess both M5 heads into the floor inside the body. Bolt
  the empty body to the frame, fit the electronics, close the lid.
- **Sealing:** a gasket (silicone sheet or O-ring cord, 1 to 2 mm) at the
  lid. Readout over USB-C, so the bottom face is solid and there is no SD
  hatch facing road spray.
- **Cable exit:** the display is wired until Phase 3, so the body needs one
  sealed exit (4-pin connector or gland) until then. After Phase 3 it has
  none.
- **Fasteners:** two M5 bottle bolts, four M3x10 lid screws with captive
  nuts. Down from twelve.
- **Hard mounting changes the data.** A rigidly mounted sensor sees more
  high-frequency content than the foam-cradled one did. Note the change in
  the log naming so Mk1 and Mk2 rides are not compared blindly.

## Bill of materials

Prices are approximate US retail as of 2026-08-30.

| Part | Why this one | Phase | Qty | ~USD |
|---|---|---|---|---|
| ADXL375 breakout, Adafruit 5374, ±200 g | Purpose-built shock sensor. 3200 Hz output, SPI and I2C. 25.5 x 17.8 mm. Buy genuine: a relabelled ADXL345 gives ±16 g and nothing in the data would tell you. | 1 | 1 | 13 |
| Jumper wires + protoboard, FR4, plated holes, 0.1" pitch | Female-female jumpers plus 28 AWG silicone stranded wire. Assorted pack (2x8 through 5x7 cm); use the 5x7 for Phase 2. Avoid phenolic board. | 1 | 1 | 8 |
| 2.2k resistors | I2C pull-ups, the one-dollar 400 kHz fix. | 1 | 2 | 1 |
| XIAO nRF52840 Sense | 21 x 17.5 mm, BLE, USB-C, onboard 6-axis IMU, LiPo charging, castellated pads. | 2 | 1 | 18 |
| microSD breakout, SPI, 3 V logic | Capacity. Replace with a bare push-push socket on the Phase 3 board. | 2 | 1 | 8 |
| LiPo cell, 500 to 1000 mAh, about 30 x 20 x 6 mm | With protection circuit and JST fitted. Not a bare pouch cell. | 2 | 1 | 9 |
| Tactile button + slide switch | Start and power. Wire the button to `INPUT_PULLUP`; the current external pull-down is unnecessary. | 2 | 2 | 2 |
| Resistors and capacitors: 2.2k, 0.1 µF, 10 µF | Pull-ups and decoupling near every module. | 2 | - | 6 |
| I2C level shifter, BSS138, 4-channel (Adafruit 757) | The bar display runs at 5 V; the XIAO at 3.3 V. Required once the display is on the boost. | 2 | 1 | 4 |
| 5 V boost converter (Adafruit MiniBoost 4654) | Required, not optional: the display's LED current through the XIAO's 3.3 V regulator corrupts the ADXL375 (see the bench log). Runs the display from the battery. | 2 | 1 | 5 |
| 100 µF electrolytic capacitors, 6.3 V or more | One at the backpack's power pins, one at the boost input. | 2 | 2 | 1 |
| Second XIAO nRF52840, plain | The bar end's brain once the cable goes. | 3 | 1 | 16 |
| Second LiPo cell | Bar end. 50 to 90 mA with the display lit, so 500 mAh is several rides. | 3 | 1 | 9 |
| Custom PCB, 5 pcs | Boards are about $5; shipping is most of it. | 3 | 5 | 25 |
| 4-pin connector + cable gland, JST-GH or similar | Only if the case is built before the cable goes. | 4, maybe | 1 | 6 |
| Silicone gasket sheet or O-ring cord, 1 to 2 mm | Seals the lid. | 4 | 1 | 8 |
| M5 bottle bolts + washers | Already measured. | 4 | 2 | 3 |
| M3x10 socket screws + nuts | Same captive-nut scheme as the v2 cradle. Already owned. | 4 | 4 | - |

Totals: Phase 1 about $22. Phases 1 and 2 core parts about $65. All
phases, optionals excluded, about $126.

### Module footprints (datasheet values, unverified with calipers)

| Module | Size |
|---|---|
| XIAO nRF52840 Sense | 21 x 17.5 mm |
| ADXL375 breakout | 25.5 x 17.8 mm |
| microSD breakout | about 25 x 24 mm |
| LiPo | about 30 x 20 x 6 mm |
| 5 x 7 cm protoboard | 50 x 70 mm, about 19 x 27 holes |

Measure every one of these before sizing the Phase 4 case. Do not design
fits from this table.

## Where to buy

Shop by vendor, not by search engine.

| What | Where | Why there |
|---|---|---|
| ADXL375 breakout | Adafruit 5374. Also Pimoroni, Jameco, Digi-Key, Mouser. | Genuine part matters. |
| XIAO nRF52840 Sense | seeedstudio.com direct. Also Amazon, Newegg. | Seeed ships from CN, US, and DE warehouses. Pick the local one. |
| microSD breakout, level shifter, 5 V boost | Adafruit or SparkFun | Documented boards, libraries the examples assume. |
| LiPo cells | Adafruit or SparkFun | Protection circuit and JST fitted. |
| Passives, connectors, exact values | Digi-Key or Mouser | Real stock numbers, no counterfeits. |
| Protoboard, hookup wire, assortments | Amazon | A resistor is a resistor. |
| Soldering iron, multimeter | Amazon, or Pine64 direct for a Pinecil | Buy on reviews. |
| M3 and M5 fasteners, gasket sheet | McMaster-Carr, or Amazon assortments | McMaster tells you exactly what you get. |
| PCB fabrication | JLCPCB, PCBWay, OSH Park | Upload Gerbers from KiCad. |

## Tools

| Item | Needed for | Notes | ~USD |
|---|---|---|---|
| Temperature-controlled soldering iron (e.g. Pinecil) | Phase 2 on | The single most important purchase. | 40 |
| Solder, flux pen, desoldering wick | Phase 2 on | Leaded 63/37 is easier to learn on. Flux matters more than technique. | 20 |
| Multimeter | Phase 1 on | Continuity beeper is 90% of its use. | 25 |
| Flush cutters, tweezers, helping hands | Phase 2 on | The vise matters more than it sounds. | 30 |
| 3D printer | Phase 4 | Already owned. | - |
| KiCad, OpenSCAD, arduino-cli | Phases 3 and 4 | All free. | - |

What is genuinely hard, ranked: PCB design (the only new discipline), the
firmware port to the nRF52840 (moderate: SPI setup and the binary format
are new), soldering castellated modules (easier than it looks with flux),
the enclosure (easiest, the hard constraints are already solved).

Deliberately out of scope: bare surface-mount chips, hot-air rework, paid
assembly. Not worth it until the Phase 3 board works.

## Decisions

- **Display: wired now, BLE at Phase 3.** Decided. Once the accelerometer
  moves to SPI, the I2C bus carries only the display, and a slow bus down a
  long cable is fine for a few updates a second. Test the HT16K33 backpack
  at 3.3 V first. If it is too dim in daylight, add the boost and level
  shifter.
- **Storage: keep microSD, read it over USB-C.** The nRF52840 can present
  the card as a USB drive. No card removal, no hatch. Costs firmware work.
- **Gyro and magnetometer:** the Sense Plus's onboard IMU gives the gyro
  for free, with one catch: its power pin must be driven in high-drive
  mode or the IMU never powers up. See the bench log in
  [mk2_build.md](mk2_build.md). The magnetometer goes away; nothing used
  it.
- **Open:** whether the bar end ever gets its own PCB or stays a hand-wired
  XIAO in a printed box. Live with it before deciding.
- **Open:** the Phase 2 protoboard layout. This gates the Phase 4 case.
- **Open:** peak detection on the ADXL375. At 49 mg per count and 3200 Hz
  bandwidth the resting noise is about 0.2 g rms per axis, so the largest
  of 6300 raw samples a second sits near 2.5 g. The logger cannot report
  raw single-sample peaks. Choose between a lower output data rate (each
  halving cuts noise by about 1.4), a short moving average, or both, and
  verify with a tap test. Also trim the zero-g offset (six-position)
  before trusting anything below a few g.

## Next

1. Parts arrive. Measure every module with calipers and update the
   footprint table above.
2. Phase 1: ADXL375 on the Nano Every over SPI, plus the 2.2k pull-up
   test. One ride.
3. Phase 2: port the firmware to the XIAO, binary log, 1 kHz. Build it on
   the 5 x 7 cm protoboard.
4. Phase 4 CAD: a new parametric SCAD file for the body and lid, sized to
   the real protoboard. Reuse the bolt interface and the nut scheme from
   `hardware/bottle_cage_mount.scad`.
