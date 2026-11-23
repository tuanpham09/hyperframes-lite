# HyperFrames Lite — Linux VPS optimization track

This repository is a fork of [heygen-com/hyperframes](https://github.com/heygen-com/hyperframes). HyperFrames Lite keeps the upstream authoring/rendering contract while adding a measured optimization track for Linux VPS workloads capped at **1.5 vCPU**.

## Engineering contract

- Preserve composition semantics, total frame count, frame timestamps, FPS, resolution, codec quality, audio samples/mix, and A/V sync.
- Never claim a speedup until the same fixture has been rendered on the same machine with equivalent settings.
- Keep every optimization reversible and behind a configuration switch until parity tests pass.
- Optimize the actual bottleneck; do not blindly replace upstream capture/encode routes that already exist.

## Current first-stage tooling

- `profiles/linux-vps.env`: conservative 1-worker profile.
- `scripts/lite-render-linux-vps.sh`: invokes the repository CLI with a single worker and explicit container-aware low-memory policy.
- `scripts/lite-doctor-linux.sh`: records CPU quota, memory cgroup, disk, Node, FFmpeg and CLI diagnostics.
- `tools/lite-benchmark.py`: warm-up + repeated wall-clock benchmark with JSON output.
- `docs/hyperframes-lite/optimization-roadmap.md`: staged plan and quality gates.

## Setup

Use the upstream contributor setup for this monorepo (Bun version is pinned in the root package manifest). On a Linux VPS:

```bash
bash scripts/lite-doctor-linux.sh
```

From a HyperFrames composition directory containing `index.html`, run:

```bash
bash /path/to/hyperframes-lite/scripts/lite-render-linux-vps.sh --help
bash /path/to/hyperframes-lite/scripts/lite-render-linux-vps.sh -o ../output/final.mp4
```

Benchmark baseline and Lite using the exact same project and output arguments:

```bash
python3 /path/to/hyperframes-lite/tools/lite-benchmark.py \
  --project /path/to/composition \
  --output-dir /path/to/benchmarks/baseline \
  --runs 3 --warmup 1 \
  --command "bunx hyperframes render -o ../output/baseline.mp4"

python3 /path/to/hyperframes-lite/tools/lite-benchmark.py \
  --project /path/to/composition \
  --output-dir /path/to/benchmarks/lite \
  --runs 3 --warmup 1 \
  --command "bash /path/to/hyperframes-lite/scripts/lite-render-linux-vps.sh -o ../output/lite.mp4"
```

## Memory policy

The wrapper estimates available headroom as cgroup v2 `memory.max - memory.current`, falling back to `MemAvailable`. It explicitly exports `PRODUCER_LOW_MEMORY_MODE`, because a container's host-visible RAM can differ from its actual memory limit. The current 6-GB VPS profile enters Low Memory Mode at 4.5 GiB or less of available headroom; with roughly 4 GB normally available, it will choose the safer route by default.

- `HF_LITE_LOW_MEMORY_MODE=auto`: choose a conservative mode based on the visible memory limit.
- `HF_LITE_LOW_MEMORY_MODE=true`: force Low Memory Mode.
- `HF_LITE_LOW_MEMORY_MODE=false`: force normal mode; use only after measuring memory headroom.

Low Memory Mode can change the capture route and may be slower. Do not assume it is the best performance setting; benchmark both modes on the target VPS.

## Status

This is the instrumentation/bootstrap stage, not a claim of completed engine optimization. The first performance gate is a trustworthy baseline. A 2× target means median render time at or below 50% of baseline without changing output quality or timing.
