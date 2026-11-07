#!/bin/bash
page=$(sysctl -n hw.pagesize)
while true; do
  echo "== $(date -u +%T) load $(sysctl -n vm.loadavg | tr -d '{}') swap $(sysctl -n vm.swapusage | awk '{print $6}') pressure $(sysctl -n kern.memorystatus_vm_pressure_level)"
  vm_stat | awk -v p="$page" '/Pages free/ {f=$3} /Pages occupied by compressor/ {c=$5} /Swapouts/ {s=$2} /Pageouts/ {o=$2} END {printf "  free %d MB  compressed %d MB  pageouts %s swapouts %s\n", f*p/1048576, c*p/1048576, o, s}'
  ps -Ao pcpu=,rss=,comm= -r | head -8 | awk '{p=$1; r=$2; $1=""; $2=""; n=split($0,a,"/"); printf "  %5s%% %6d MB %s\n", p, r/1024, a[n]}'
  sleep 5
done
