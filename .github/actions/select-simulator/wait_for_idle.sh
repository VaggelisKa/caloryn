#!/bin/bash
set -euo pipefail

busy_percent="${BUSY_PERCENT:-25}"
quiet_samples="${QUIET_SAMPLES:-6}"
minimum_seconds="${MINIMUM_SECONDS:-600}"
limit_seconds="${LIMIT_SECONDS:-900}"
interval=10

quiet=0
start=$SECONDS
while (( SECONDS - start < limit_seconds )); do
  usage="$(ps -Ao pcpu=,comm= | awk '/\.simruntime\// { total += $1 } END { printf "%d", total }')"
  echo "$(( SECONDS - start ))s simulator CPU ${usage}% load $(sysctl -n vm.loadavg)"
  if (( usage < busy_percent )); then
    quiet=$(( quiet + 1 ))
  else
    quiet=0
  fi
  if (( quiet >= quiet_samples && SECONDS - start >= minimum_seconds )); then
    echo "Simulator idle after $(( SECONDS - start ))s."
    exit 0
  fi
  sleep "$interval"
done

echo "Simulator still busy after ${limit_seconds}s; saving it as it is."
