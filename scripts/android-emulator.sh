#!/usr/bin/env bash
# Boots the named AVD if it is not already running and prints its adb serial.
# The serial is required because adb refuses a bare command once a second
# emulator is attached, and a phone plus a tablet is the normal local setup.
set -euo pipefail

avd="${1:?usage: android-emulator.sh <avd-name>}"

serial_of() {
  local s
  for s in $(adb devices | awk '/^emulator-/ {print $1}'); do
    if [ "$(adb -s "$s" emu avd name 2>/dev/null | head -1 | tr -d '\r')" = "$avd" ]; then
      echo "$s"
      return 0
    fi
  done
  return 1
}

if ! serial_of >/dev/null; then
  flutter emulators --launch "$avd" >&2
  until serial_of >/dev/null; do sleep 2; done
fi

serial=$(serial_of)
until [ "$(adb -s "$serial" shell getprop sys.boot_completed 2>/dev/null | tr -d '\r')" = 1 ]; do
  sleep 2
done

echo "$serial"
