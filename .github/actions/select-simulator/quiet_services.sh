#!/bin/bash
set -euo pipefail

simulator_id="$1"
services=(com.apple.apsd com.apple.PosterBoard com.apple.chronod)

xcrun simctl bootstatus "$simulator_id" -b > /dev/null
for service in "${services[@]}"; do
  xcrun simctl spawn "$simulator_id" launchctl disable "user/foreground/$service"
done
xcrun simctl shutdown "$simulator_id"
xcrun simctl boot "$simulator_id"
echo "Rebooted $simulator_id with ${services[*]} disabled."
