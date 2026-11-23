# Optimization roadmap — Linux 1.5 vCPU

## Non-negotiable invariants

1. Same composition semantics and deterministic seek result.
2. Same frame count, frame timestamps, FPS, resolution and output duration.
3. Same decoded audio samples/mix and A/V synchronization.
4. No quality reduction hidden behind a "fast" preset.
5. Every optimization has a kill switch and an A/B parity test.

## Stage 0 — Establish a trustworthy baseline

Collect at least three measured runs after one warm-up. Save:

- HyperFrames CLI version and upstream commit SHA.
- `hyperframes doctor --json` output.
- CPU quota (`/sys/fs/cgroup/cpu.max`), memory limit and available RAM.
- Stage timings: compile, setup, extraction, capture, encode, assemble.
- Peak RSS, disk I/O, output metadata and SHA-256.
- Representative decoded frames at identical timestamps.

A speedup claim is valid only when comparing the same machine, project, output settings, warm/cold cache policy and successful output checks.

## Stage 1 — Linux single-worker routing

Test the following combinations on the actual VPS:

- One worker + BeginFrame + streaming encode.
- One worker + screenshot capture + streaming encode.
- Low Memory Mode on/off.
- Browser GPU auto-detection versus software GPU.

The current upstream CLI/producer already contains multiple capture and streaming routes. Inspect route selection and runtime diagnostics before adding a parallel implementation. Low Memory Mode may select a safer but slower screenshot path.

## Stage 2 — Instrumentation before algorithm changes

Add stage-level counters/timings around:

- Browser launch, page navigation and readiness.
- Seek and page-side timeline work.
- BeginFrame / screenshot capture.
- Frame buffer copies and reorder queue.
- Encoder stdin backpressure.
- FFmpeg CPU utilization and output flush.
- Media extraction and temporary-file I/O.

Use `perf` / `pidstat` when available; keep them optional.

## Stage 3 — Candidate optimizations

Prioritize by measured bottleneck:

- Remove redundant CDP round trips while retaining required seek barriers.
- Bound the capture-to-encoder queue to prevent unbounded memory growth.
- Avoid extra Buffer copies only where ownership/lifetime is proven.
- Tune FFmpeg thread count to the cgroup CPU quota, not host CPU count.
- Reuse browser/page resources only where lifecycle tests prove safe.
- Defer or window source-video extraction only for supported formats.
- Improve cache hit rate for immutable extracted media.
- Reduce repeated page-side work only when it cannot change rendered pixels.

## Stage 4 — Parity and regression

For each optimization:

- Compare decoded frames at every frame for short fixtures, or all frames for the benchmark fixture.
- Require exact pixel equality where deterministic; otherwise record PSNR/SSIM and document tolerance.
- Compare decoded audio PCM, duration, sample rate and channel layout.
- Compare frame count, timestamps, codec profile, dimensions and FPS.
- Test fonts, SVG filters, shadows, transparency, WebGL transitions, video layers, motion blur and sub-compositions.

A candidate that changes visible output or timing is not enabled by default.

## Stage 5 — 2× target gate

Target: median wall-clock time at or below 50% of baseline on the same 1.5-vCPU VPS.

If capture is already near the theoretical CPU floor, 2× may not be achievable without changing the workload or using acceleration. Report the measured ceiling honestly; do not fake a win by lowering quality, FPS or resolution.
