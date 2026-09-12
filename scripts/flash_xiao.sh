#!/usr/bin/env bash
# Compile and flash a sketch to the XIAO nRF52840 Sense Plus, whether the
# board is running an app or sitting in its bootloader.
#
#   scripts/flash_xiao.sh Shredometer_Mk2_Bringup
#
# Why this exists: arduino-cli's upload does a 1200-baud "touch" to reboot
# the app into the bootloader. If the board is already in the bootloader
# (double-tapped reset, or a previous flash was interrupted), that touch
# breaks the DFU session and the upload fails with "No data received on
# serial port". In that case adafruit-nrfutil must be called directly.
set -euo pipefail

SKETCH=${1:?usage: $0 <sketch dir>}
FQBN=${FQBN:-Seeeduino:nrf52:xiaonRF52840SensePlus}
export PATH="$HOME/.local/bin:$PATH"

APP_PID=8065   # Sense Plus application
BL_PID=0065    # Sense Plus bootloader (plain Sense: 8045 / 0045)

arduino-cli compile --fqbn "$FQBN" "$SKETCH"

port() { arduino-cli board list 2>/dev/null | awk '/ttyACM/ {print $1; exit}'; }

if lsusb -d "2886:$BL_PID" >/dev/null; then
  echo "Board is in bootloader mode: flashing with adafruit-nrfutil directly."
  zip=$(find "$HOME/.cache/arduino/sketches" -name "$(basename "$SKETCH").ino.zip" -newer "$SKETCH"/*.ino -print -quit)
  [ -n "$zip" ] || zip=$(find "$HOME/.cache/arduino/sketches" -name "$(basename "$SKETCH").ino.zip" -print -quit)
  adafruit-nrfutil dfu serial -pkg "$zip" -p "$(port)" -b 115200 --singlebank
elif lsusb -d "2886:$APP_PID" >/dev/null; then
  arduino-cli upload -p "$(port)" --fqbn "$FQBN" "$SKETCH"
else
  echo "No XIAO found on USB (expected 2886:$APP_PID or 2886:$BL_PID)." >&2
  lsusb -d 2886: || true
  exit 1
fi

# Wait for the app to come back, then say where it is.
for _ in $(seq 1 50); do
  lsusb -d "2886:$APP_PID" >/dev/null && sleep 0.5 && break
  sleep 0.2
done
echo "Done. Board is on: $(port)"
