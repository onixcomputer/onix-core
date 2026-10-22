#!/usr/bin/env python3
"""Full byte-level verification of the spliced pack against its sources.

Walks every tensor of the pack index, recomputes sha256 over the output bytes and
over the source shard's bytes, and compares. Streaming: memory stays flat, so it
can run next to the rsync without perturbing the serving nodes' page cache.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import os
import re
import struct
import sys
import time

CHUNK = 8 << 20
EXPERT_RE = re.compile(r"^layers\.(\d+)\.ffn\.experts\.(\d+)\.")


def log(msg: str) -> None:
    print(msg, flush=True)


class Reader:
    def __init__(self, path: str):
        import mmap
        self.path = path
        self.fd = os.open(path, os.O_RDONLY)
        n = struct.unpack("<Q", os.read(self.fd, 8))[0]
        self.header = json.loads(os.read(self.fd, n))
        self.base = 8 + n
        self.mm = mmap.mmap(self.fd, 0, prot=mmap.PROT_READ)

    def sha256(self, name: str) -> tuple[str, int]:
        s, e = self.header[name]["data_offsets"]
        h = hashlib.sha256()
        for pos in range(self.base + s, self.base + e, CHUNK):
            h.update(self.mm[pos:min(pos + CHUNK, self.base + e)])
        return h.hexdigest(), e - s

    def close(self) -> None:
        self.mm.close()
        os.close(self.fd)


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--pack", required=True, help="finished pack dir")
    ap.add_argument("--slim", required=True, help="slim native release dir")
    ap.add_argument("--experts", required=True, help="EXL3 pack dir (body)")
    ap.add_argument("--engram", required=True)
    args = ap.parse_args()

    with open(os.path.join(args.pack, "model.safetensors.index.json")) as f:
        pack_map = json.load(f)["weight_map"]
    with open(os.path.join(args.slim, "model.safetensors.index.json")) as f:
        slim_map = json.load(f)["weight_map"]
    with open(os.path.join(args.experts, "model.safetensors.index.json")) as f:
        exp_map = json.load(f)["weight_map"]
    with open(os.path.join(args.engram, "model.safetensors.index.json")) as f:
        eng_map = json.load(f)["weight_map"]

    out_handles: dict[str, Reader] = {}
    src_handles: dict[str, Reader] = {}
    n = bad = 0
    total = 0
    t0 = time.time()
    try:
        for name in sorted(pack_map):
            out_path = os.path.join(args.pack, pack_map[name])
            r = out_handles.get(out_path)
            if r is None:
                r = out_handles[out_path] = Reader(out_path)
            if name in eng_map:
                src_dir, src_map = args.engram, eng_map
            elif EXPERT_RE.match(name):
                src_dir, src_map = args.experts, exp_map
            else:
                src_dir, src_map = args.slim, slim_map
            s_path = os.path.join(src_dir, src_map[name])
            src = src_handles.get(s_path)
            if src is None:
                src = src_handles[s_path] = Reader(s_path)
            h_out, nb = r.sha256(name)
            h_src, nb_src = src.sha256(name)
            total += nb
            n += 1
            if h_out != h_src or nb != nb_src:
                bad += 1
                log(f"MISMATCH {name} ({pack_map[name]} vs {src_map[name]})")
            if n % 20000 == 0:
                log(f"  {n} tensors, {total/1e9:.1f} GB, {bad} bad [{time.time()-t0:.0f}s]")
    finally:
        for r in list(out_handles.values()) + list(src_handles.values()):
            r.close()
    log(f"FULL-VERIFY: {n} tensors, {total/1e9:.1f} GB compared, {bad} mismatches, "
        f"{time.time()-t0:.0f}s")
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main())
