#!/usr/bin/env python3
"""Fetch only the non-expert tensors of the 1017 release (HTTP range requests).

The spliced TP3 pack needs the release's native dense/vision/head/MTP tensors
(~26 GB) and the EXL3 pack's routed experts; the release's own MXFP4 expert
tensors (92,160 tensors, ~288 GB) are never used. Instead of downloading the
46 body shards whole, read each shard's safetensors header with a range request
and pull only the byte range of every non-expert tensor straight into its slot
in a new slim shard.

  fetch_release_slim.py --repo deepseek-ai/DeepSeek-V4.1-Flash-1017 --rev <sha> \
      --index-dir  <dir with the release model.safetensors.index.json> \
      --engram-dir <dir with shards 47/48> \
      --out        <slim dir> [--verify-against <full-shard dir>] [--workers 12]
"""
from __future__ import annotations

import argparse
import concurrent.futures as cf
import hashlib
import json
import os
import re
import struct
import sys
import time
import urllib.error
import urllib.request

DTYPE_SIZE = {
    "BOOL": 1, "U8": 1, "I8": 1, "F8_E4M3": 1, "F8_E5M2": 1, "F8_E8M0": 1,
    "U16": 2, "I16": 2, "F16": 2, "BF16": 2,
    "U32": 4, "I32": 4, "F32": 4, "U64": 8, "I64": 8, "F64": 8,
}
EXPERT_RE = re.compile(r"^layers\.(\d+)\.ffn\.experts\.(\d+)\.")
CHUNK = 32 << 20
URL = "https://huggingface.co/{repo}/resolve/{rev}/{file}"


def log(msg: str) -> None:
    print(msg, flush=True)


def fetch(url: str, start: int, end: int, tries: int = 6) -> bytes:
    last = None
    for attempt in range(tries):
        try:
            req = urllib.request.Request(
                url, headers={"Range": f"bytes={start}-{end}", "User-Agent": "dsv41-slim/1.0"})
            with urllib.request.urlopen(req, timeout=120) as r:
                data = r.read()
            if len(data) != end - start + 1:
                raise IOError(f"short read: {len(data)} != {end - start + 1}")
            return data
        except (urllib.error.URLError, IOError, ConnectionError) as e:
            last = e
            time.sleep(1.5 * (attempt + 1))
    raise RuntimeError(f"range {start}-{end} of {url} failed: {last}")


def read_header(url: str) -> tuple[dict, int]:
    n = struct.unpack("<Q", fetch(url, 0, 7))[0]
    if not 0 < n < 200 << 20:
        raise RuntimeError(f"implausible header length {n}")
    hdr = json.loads(fetch(url, 8, 8 + n - 1))
    return {k: v for k, v in hdr.items() if k != "__metadata__"}, 8 + n


def write_slim(url: str, path: str, header: dict, base: int, names: list[str],
               pool: cf.ThreadPoolExecutor) -> tuple[int, int]:
    out_header: dict[str, dict] = {}
    offset = 0
    plan = []
    for name in sorted(names):
        m = header[name]
        s, e = m["data_offsets"]
        nbytes = e - s
        assert nbytes == DTYPE_SIZE[m["dtype"]] * _numel(m["shape"]), name
        out_header[name] = {"dtype": m["dtype"], "shape": m["shape"],
                            "data_offsets": [offset, offset + nbytes]}
        plan.append((name, base + s, offset, nbytes))
        offset += nbytes

    blob = json.dumps(out_header, separators=(",", ":")).encode()
    blob += b" " * ((-len(blob)) % 8)
    tmp = path + ".tmp"
    with open(tmp, "wb") as f:
        f.write(struct.pack("<Q", len(blob)))
        f.write(blob)
        data_start = f.tell()
        f.truncate(data_start + offset)
    fd = os.open(tmp, os.O_WRONLY)

    def grab(item):
        name, src_off, out_off, nbytes = item
        pos = 0
        while pos < nbytes:
            take = min(CHUNK, nbytes - pos)
            data = fetch(url, src_off + pos, src_off + pos + take - 1)
            os.pwrite(fd, data, data_start + out_off + pos)
            pos += take
        return nbytes

    try:
        done = 0
        for got in pool.map(grab, plan):
            done += got
    finally:
        os.close(fd)
    os.replace(tmp, path)
    return offset, len(plan)


def _numel(shape) -> int:
    n = 1
    for d in shape:
        n *= int(d)
    return n


class Reader:
    """Minimal safetensors reader for the verification step."""

    def __init__(self, path: str):
        import mmap
        self.path = path
        self.fd = os.open(path, os.O_RDONLY)
        n = struct.unpack("<Q", os.read(self.fd, 8))[0]
        self.header = json.loads(os.read(self.fd, n))
        self.base = 8 + n
        self.mm = mmap.mmap(self.fd, 0, prot=mmap.PROT_READ)

    def sha256(self, name: str) -> str:
        s, e = self.header[name]["data_offsets"]
        h = hashlib.sha256()
        for pos in range(self.base + s, self.base + e, CHUNK):
            h.update(self.mm[pos:min(pos + CHUNK, self.base + e)])
        return h.hexdigest()

    def close(self):
        self.mm.close()
        os.close(self.fd)


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--repo", default="deepseek-ai/DeepSeek-V4.1-Flash-1017")
    ap.add_argument("--rev", required=True)
    ap.add_argument("--index-dir", required=True)
    ap.add_argument("--engram-dir", required=True)
    ap.add_argument("--out", required=True)
    ap.add_argument("--verify-against", default=None)
    ap.add_argument("--workers", type=int, default=12)
    ap.add_argument("--only", default=None, help="comma list of shard numbers")
    args = ap.parse_args()

    os.makedirs(args.out, exist_ok=True)
    with open(os.path.join(args.index_dir, "model.safetensors.index.json")) as f:
        rel_index = json.load(f)
    weight_map = rel_index["weight_map"]
    files = sorted({v for v in weight_map.values()}, key=lambda s: int(s.split("-")[1]))
    by_file: dict[str, list[str]] = {}
    for name, f_ in weight_map.items():
        by_file.setdefault(f_, []).append(name)

    engram_files = [f_ for f_ in files if f_.split("-")[1] in ("00047", "00048")]
    body_files = [f_ for f_ in files if f_ not in engram_files]
    log(f"release index: {len(weight_map)} tensors in {len(files)} shards "
        f"({len(body_files)} body, {len(engram_files)} engram)")

    only = {int(x) for x in args.only.split(",")} if args.only else None
    slim_map: dict[str, str] = {}
    t0 = time.time()
    totals = [0, 0]
    with cf.ThreadPoolExecutor(max_workers=args.workers) as pool:
        for fname in body_files:
            shard_no = int(fname.split("-")[1])
            if only and shard_no not in only:
                continue
            url = URL.format(repo=args.repo, rev=args.rev, file=fname)
            header, base = read_header(url)
            names = [n for n in by_file[fname] if not EXPERT_RE.match(n)]
            dropped = len(by_file[fname]) - len(names)
            out_path = os.path.join(args.out, fname)
            written, count = write_slim(url, out_path, header, base, names, pool)
            for n in names:
                slim_map[n] = fname
            totals[0] += written
            totals[1] += count
            log(f"  {fname}: {count} tensors {written/1e9:.2f} GB "
                f"(skipped {dropped} expert tensors) [{time.time()-t0:.0f}s]")

    # Engram shards: link the copies already downloaded whole.
    for fname in engram_files:
        src = os.path.join(args.engram_dir, fname)
        dst = os.path.join(args.out, fname)
        if not os.path.exists(src):
            log(f"  engram shard not present yet, skipping: {src}")
            continue
        if not os.path.exists(dst):
            try:
                os.link(src, dst)
            except OSError:
                import shutil
                shutil.copy2(src, dst)
        for n in by_file[fname]:
            slim_map[n] = fname
        log(f"  {fname}: linked from {args.engram_dir}")

    with open(os.path.join(args.out, "model.safetensors.index.json"), "w") as f:
        json.dump({"metadata": {"total_size": sum(
            os.path.getsize(os.path.join(args.out, x)) for x in sorted(set(slim_map.values())))},
            "weight_map": slim_map}, f, indent=1)
    log(f"slim index: {len(slim_map)} tensors, {totals[0]/1e9:.1f} GB fetched")

    if args.verify_against:
        log(f"verify: byte-comparing slim shards against {args.verify_against}")
        checked = 0
        for fname in sorted(set(slim_map.values())):
            full = os.path.join(args.verify_against, fname)
            slim = os.path.join(args.out, fname)
            if not os.path.exists(full):
                log(f"  {fname}: no full copy to compare, skipping")
                continue
            a, b = Reader(slim), Reader(full)
            try:
                names = [n for n, f_ in slim_map.items() if f_ == fname]
                for name in names:
                    assert a.sha256(name) == b.sha256(name), f"{fname}:{name}"
                    checked += 1
            finally:
                a.close()
                b.close()
            log(f"  {fname}: {len(names)} tensors byte-identical")
        log(f"verify OK: {checked} tensors match the full shards")
    return 0


if __name__ == "__main__":
    sys.exit(main())
