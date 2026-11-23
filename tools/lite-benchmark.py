#!/usr/bin/env python3
"""Repeatable wall-clock benchmark wrapper for HyperFrames render commands."""

from __future__ import annotations

import argparse
import json
import os
import platform
import statistics
import subprocess
import time
from datetime import datetime, timezone
from pathlib import Path


def read_text(path: str) -> str | None:
    try:
        return Path(path).read_text().strip()
    except OSError:
        return None


def machine_info() -> dict:
    memory = {}
    try:
        for line in Path("/proc/meminfo").read_text().splitlines():
            key, value = line.split(":", 1)
            if key in {"MemTotal", "MemAvailable"}:
                memory[key] = int(value.strip().split()[0]) // 1024
    except (OSError, ValueError):
        pass
    return {
        "platform": platform.platform(),
        "machine": platform.machine(),
        "logical_cpu_count": os.cpu_count(),
        "memory_mb": memory,
        "cgroup_v2_cpu_max": read_text("/sys/fs/cgroup/cpu.max"),
        "cgroup_v2_memory_max": read_text("/sys/fs/cgroup/memory.max"),
    }


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--project", required=True, help="Composition directory containing index.html")
    parser.add_argument("--output-dir", required=True)
    parser.add_argument("--runs", type=int, default=3)
    parser.add_argument("--warmup", type=int, default=1)
    parser.add_argument("--command", required=True, help="Command executed through bash -lc")
    args = parser.parse_args()

    project = Path(args.project).resolve()
    output_dir = Path(args.output_dir).resolve()
    if not (project / "index.html").is_file():
        parser.error(f"{project} does not contain index.html")
    if args.runs < 1 or args.warmup < 0:
        parser.error("--runs must be >= 1 and --warmup must be >= 0")

    output_dir.mkdir(parents=True, exist_ok=True)
    records = []
    for index in range(args.warmup + args.runs):
        label = f"warmup-{index + 1}" if index < args.warmup else f"run-{index - args.warmup + 1}"
        log_path = output_dir / f"{label}.log"
        started = time.perf_counter()
        with log_path.open("w", encoding="utf-8") as log:
            process = subprocess.run(
                ["bash", "-lc", args.command],
                cwd=project,
                stdout=log,
                stderr=subprocess.STDOUT,
                check=False,
                env=os.environ.copy(),
            )
        elapsed = time.perf_counter() - started
        record = {
            "label": label,
            "seconds": round(elapsed, 3),
            "exit_code": process.returncode,
            "log": str(log_path),
        }
        records.append(record)
        print(f"{label}: {elapsed:.2f}s (exit={process.returncode})", flush=True)
        if process.returncode != 0:
            print(f"Render failed; inspect {log_path}", flush=True)
            break

    measured = [
        item["seconds"]
        for item in records
        if item["label"].startswith("run-") and item["exit_code"] == 0
    ]
    summary = {
        "created_at": datetime.now(timezone.utc).isoformat(),
        "project": str(project),
        "command": args.command,
        "machine": machine_info(),
        "runs": records,
        "successful_measured_runs": len(measured),
        "median_seconds": round(statistics.median(measured), 3) if measured else None,
        "min_seconds": round(min(measured), 3) if measured else None,
        "max_seconds": round(max(measured), 3) if measured else None,
    }
    summary_path = output_dir / "benchmark.json"
    summary_path.write_text(json.dumps(summary, indent=2), encoding="utf-8")
    print(f"Summary: {summary_path}")
    return 0 if len(measured) == args.runs else 1


if __name__ == "__main__":
    raise SystemExit(main())
