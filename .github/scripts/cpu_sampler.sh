#!/bin/bash
while true; do
  echo "== $(date -u +%T) load $(sysctl -n vm.loadavg)"
  ps -Ao pcpu=,comm= -r | head -6 | awk '{p=$1; $1=""; n=split($0,a,"/"); printf "  %5s %s\n", p, a[n]}'
  sleep 10
done
