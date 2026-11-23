#!/usr/bin/env bash
set -Eeuo pipefail

echo "== HyperFrames Lite / Linux VPS diagnostics =="
printf 'Kernel: '; uname -srmo
printf 'CPU online: '; getconf _NPROCESSORS_ONLN 2>/dev/null || echo unknown
printf 'Load average: '; cat /proc/loadavg 2>/dev/null || true
printf 'RAM: '; awk '/MemTotal|MemAvailable/ {printf "%s=%sMB ", $1, int($2/1024)} END {print ""}' /proc/meminfo 2>/dev/null || true
printf 'Cgroup v2 cpu.max: '; cat /sys/fs/cgroup/cpu.max 2>/dev/null || echo unavailable
printf 'Cgroup v2 memory.max: '; cat /sys/fs/cgroup/memory.max 2>/dev/null || echo unavailable
printf 'Disk: '; df -h . | tail -n 1
printf 'Node: '; node --version 2>/dev/null || echo missing
printf 'Bun: '; bun --version 2>/dev/null || echo missing
printf 'FFmpeg: '; ffmpeg -version 2>/dev/null | head -n 1 || echo missing
printf 'HyperFrames: '; hyperframes --version 2>/dev/null || echo project-local-or-missing
if command -v hyperframes >/dev/null 2>&1; then
  echo '--- hyperframes doctor --json ---'
  hyperframes doctor --json 2>/dev/null | python3 -m json.tool | head -n 120 || echo "doctor JSON unavailable"
fi
