#!/usr/bin/env python3
"""Finish a slim release tree: link the Engram shards and write its index.

Run after both the range-fetched body shards and the full Engram shards are in
place. The slim index keeps every release tensor except the native MXFP4 expert
tensors (those are replaced by the EXL3 pack in the spliced TP3 pack).
"""
import argparse
import json
import os
import re
import sys

EXPERT_RE = re.compile(r"^layers\.(\d+)\.ffn\.experts\.(\d+)\.")


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--release-index", required=True)
    ap.add_argument("--slim", required=True)
    ap.add_argument("--engram-dir", required=True)
    args = ap.parse_args()

    with open(args.release_index) as f:
        weight_map = json.load(f)["weight_map"]

    slim_map: dict[str, str] = {}
    missing: dict[str, str] = {}
    for name, fname in weight_map.items():
        if EXPERT_RE.match(name):
            continue
        src = os.path.join(args.engram_dir, fname)
        dst = os.path.join(args.slim, fname)
        if not os.path.exists(dst) and os.path.exists(src):
            try:
                os.link(src, dst)
            except OSError:
                import shutil
                shutil.copy2(src, dst)
        if os.path.exists(dst):
            slim_map[name] = fname
        else:
            missing[name] = fname

    if missing:
        byfile: dict[str, int] = {}
        for fname in missing.values():
            byfile[fname] = byfile.get(fname, 0) + 1
        print(f"INCOMPLETE: {len(missing)} tensors still absent, e.g. "
              f"{sorted(byfile.items())[:5]}")
        return 1

    files = sorted(set(slim_map.values()))
    total = sum(os.path.getsize(os.path.join(args.slim, f)) for f in files)
    with open(os.path.join(args.slim, "model.safetensors.index.json"), "w") as f:
        json.dump({"metadata": {"total_size": total}, "weight_map": slim_map}, f, indent=1)
    print(f"slim tree complete: {len(slim_map)} tensors in {len(files)} shards, "
          f"{total/1e9:.1f} GB")
    return 0


if __name__ == "__main__":
    sys.exit(main())
