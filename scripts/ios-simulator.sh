#!/usr/bin/env bash
# DeviceHub.app is the only way to see the device on Xcode 27; simctl alone
# boots it headless.
set -euo pipefail

device="${1:?usage: ios-simulator.sh <device-name> [nowait]}"
mode="${2:-wait}"

if xcrun simctl list devices booted | grep -qF "$device"; then
  running=1
else
  running=0
  xcrun simctl boot "$device"
fi

open -a "$(xcode-select -p)/../Applications/DeviceHub.app"

if [ "$mode" = nowait ]; then
  if [ "$running" = 1 ]; then
    echo "$device already running"
  else
    echo "$device starting"
  fi
  exit 0
fi

xcrun simctl bootstatus "$device" >/dev/null
echo "$device ready"
