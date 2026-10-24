#!/bin/bash
i=0
while true; do
  echo "== $(date -u +%T) load $(sysctl -n vm.loadavg)"
  ps -Ao pcpu=,comm= -r | head -6 | awk '{p=$1; $1=""; sim=($0 ~ /\.simruntime\//) ? "sim:" : ""; n=split($0,a,"/"); printf "  %5s %s%s\n", p, sim, a[n]}'
  if (( i % 6 == 0 )); then
    ps -Ao pid=,ppid=,pcpu=,etime=,command= | grep -E '[d]iagnosticd|[a]psd|[ /]log (stream|collect|show)|[l]ogd' | cut -c1-200 | sed 's/^/  ## /'
  fi
  i=$(( i + 1 ))
  sleep 10
done
