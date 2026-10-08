#!/usr/bin/env bash
# DeviceHub.app is the only way to see the device on Xcode 27; simctl alone
# boots it headless.
set -euo pipefail

device="${1:?usage: ios-simulator.sh <device-name-or-id> [nowait]}"
mode="${2:-wait}"

# simctl knows simulators only, and a substring test would take an iPhone
# named "iPhone" for one. A physical iPhone has no route back to this machine.
if ! flutter devices --machine | jq -e --arg d "$device" \
     'any(.[]; (.id == $d or .name == $d) and .emulator == true)' >/dev/null; then
  if [ "$mode" != nowait ] && [ "${ENV:-local}" = local ]; then
    echo "IOS: ENV=local cannot reach this machine from a physical iPhone." >&2
    echo "IOS: iOS has no adb reverse. Use ENV=dev, prod or pr-<number>." >&2
    exit 1
  fi
  if [ "$mode" = nowait ]; then echo "$device already attached"; else echo "$device ready"; fi
  exit 0
fi

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
