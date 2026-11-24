# Render lifecycle profiling

The render lifecycle profiler is opt-in and does not alter capture, encoding, output quality, or process shutdown behavior.

## Enable

Run a representative render with the environment variable enabled:

```bash
HF_RENDER_LIFECYCLE_PROFILE=1 node packages/cli/bin/hyperframes.mjs render \
  --quality looks --workers 1 --no-low-memory-mode \
  -o results/lifecycle-profile.mp4 2>&1 | tee results/lifecycle-profile.log
```

Keep the shell/session alive until the command exits. Do not background the render under a parent process that may exit; the producer intentionally cancels work when its parent disappears.

## Read the diagnostic

At render-context disposal, the log emits one `[Render lifecycle] cleanup summary` record containing:

- `cleanupDurationMs`: total time spent flushing progress and disposing resources.
- `cleanupSteps`: each registered disposer, in actual LIFO execution order, with duration and any contained cleanup error.
- `activeResourceCount` and `activeResources`: Node's `process.getActiveResourcesInfo()` snapshot after cleanup. Values are counts grouped by resource type, not references to individual handles.
- `eventFlushError`: present if progress delivery failed. Cleanup still runs before that error is rethrown.

The profiler is intentionally diagnostic: it does not call `process.exit()`, forcibly destroy handles, or treat every active resource as a leak. Node's own stdout/stderr and host runtime may legitimately remain active. Compare the snapshot with a clean short render and a long render from the same runtime.

## Suggested investigation

1. Capture one clean 30-second render and one 180-second render with this flag.
2. Compare the remaining resource types and cleanup-step durations.
3. If the CLI still hangs, capture a process/handle dump while it is hung; the summary narrows the suspects but does not identify a specific handle or prove causality.
4. Keep the raw log and the exact command with the benchmark result.
