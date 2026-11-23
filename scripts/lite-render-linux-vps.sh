#!/usr/bin/env bash
set -Eeuo pipefail

usage() {
  cat <<'EOF'
Usage:
  lite-render-linux-vps.sh [hyperframes render arguments...]

Runs HyperFrames with a single worker for a 1.5-vCPU Linux VPS.
It does not lower resolution, FPS, codec quality, or skip frames.
Run from the HyperFrames composition directory containing index.html.
EOF
}

if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then usage; exit 0; fi

CLI=()
if [[ -x "node_modules/.bin/hyperframes" ]]; then
  CLI=("./node_modules/.bin/hyperframes")
elif [[ -f "packages/cli/bin/hyperframes.mjs" && -f "packages/cli/dist/cli.js" ]]; then
  CLI=(node packages/cli/bin/hyperframes.mjs)
elif command -v hyperframes >/dev/null 2>&1; then
  CLI=(hyperframes)
elif command -v npx >/dev/null 2>&1; then
  CLI=(npx --no-install hyperframes)
else
  echo "ERROR: HyperFrames CLI not found (project-local, global, or npx)." >&2
  exit 127
fi

if [[ ! -f "index.html" ]]; then
  echo "ERROR: Run this command from a composition directory containing index.html." >&2
  exit 2
fi

HELP="$("${CLI[@]}" render --help 2>&1 || true)"
ARGS=("$@")

has_flag() {
  local flag="$1"
  [[ " ${ARGS[*]} " == *" ${flag} "* ]]
}

WORKERS="${HF_LITE_WORKERS:-1}"
if ! has_flag "--workers" && ! has_flag "-w"; then
  ARGS+=(--workers "$WORKERS")
fi

if grep -q -- "--experimental-fast-capture" <<<"$HELP" && ! has_flag "--experimental-fast-capture"; then
  ARGS+=(--experimental-fast-capture)
fi

LOW_MEMORY="${HF_LITE_LOW_MEMORY_MODE:-auto}"
if [[ "$LOW_MEMORY" == "auto" ]]; then
  LIMIT_BYTES="$(cat /sys/fs/cgroup/memory.max 2>/dev/null || true)"
  if [[ "$LIMIT_BYTES" =~ ^[0-9]+$ ]]; then
    (( LIMIT_BYTES <= 8589934592 )) && LOW_MEMORY=true || LOW_MEMORY=false
  else
    AVAILABLE_KB="$(awk '/MemAvailable:/ {print $2}' /proc/meminfo 2>/dev/null || echo 0)"
    if [[ "$AVAILABLE_KB" =~ ^[0-9]+$ ]] && (( AVAILABLE_KB <= 8388608 )); then
      LOW_MEMORY=true
    else
      LOW_MEMORY=false
    fi
  fi
fi

case "$LOW_MEMORY" in
  true|1|yes)
    export PRODUCER_LOW_MEMORY_MODE=true
    grep -q -- "--low-memory-mode" <<<"$HELP" && ARGS+=(--low-memory-mode) || true
    ;;
  false|0|no)
    export PRODUCER_LOW_MEMORY_MODE=false
    grep -q -- "--no-low-memory-mode" <<<"$HELP" && ARGS+=(--no-low-memory-mode) || true
    ;;
  *)
    echo "ERROR: HF_LITE_LOW_MEMORY_MODE must be auto, true, or false." >&2
    exit 2
    ;;
esac

echo "[hyperframes-lite] CPU budget target: ${HF_LITE_CPU_BUDGET:-1.5} vCPU"
echo "[hyperframes-lite] workers: $WORKERS (unless explicitly overridden)"
echo "[hyperframes-lite] quality/FPS/resolution: inherited unchanged"
exec "${CLI[@]}" render "${ARGS[@]}"
