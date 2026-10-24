#!/bin/bash
set -euo pipefail

simulator_id="$1"
services=(com.apple.apsd)

xcrun simctl bootstatus "$simulator_id" -b > /dev/null
for service in "${services[@]}"; do
  xcrun simctl spawn "$simulator_id" launchctl disable "user/foreground/$service"
  xcrun simctl spawn "$simulator_id" launchctl bootout "user/foreground/$service" || true
done
echo "Stopped ${services[*]} in $simulator_id."
