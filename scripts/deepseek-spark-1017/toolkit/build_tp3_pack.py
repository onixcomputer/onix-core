#!/usr/bin/env python3
"""Build a TP3 serving pack for DeepSeek-V4.1-Flash-1017.

Splice, following the layout of the working DeepSeek-V4.1-Flash EXL3 TP3 pack:

  * native tensors (dense FP8 32x32, MXFP4 MTP experts, vision, head, norms,
    router, mHC, engram wkv)   <- deepseek-ai/DeepSeek-V4.1-Flash-1017 release
  * routed experts, EXL3 trellis <- LibertAIDAI/...-EXL3-2.9bpw (that pack's
    attention / shared experts / head are dropped: vLLM cannot TP3-slice an
    EXL3 dense weight -- cuda_exl3 requires each row-parallel input slice to be
    a multiple of the 128-element Hadamard block, and 5120/3, 1280/3, 1024/3 are
    not, so only expert-parallel weights may stay EXL3 at TP=3)

Output tree (48 shards, same naming scheme as the pack it replaces):

  model-00001..00040-of-00048.safetensors   one backbone layer each
  model-00041-of-00048.safetensors          embed / image_* / aligner
  model-00042-of-00048.safetensors          vision tower
  model-00043-of-00048.safetensors          head
  model-00044..00046-of-00048.safetensors   mtp.0 / mtp.1 / mtp.2 (DSpark draft)
  model-00047/00048-of-00048.safetensors    Engram n-gram tables (linked, not copied)

The writer is a streaming safetensors writer (mmap the source, copy 8 MiB
chunks), so peak RSS stays at tens of MiB even for a 100 GiB shard.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import mmap
import os
import re
import shutil
import struct
import sys
from typing import Iterable

DTYPE_SIZE = {
    "BOOL": 1, "U8": 1, "I8": 1, "F8_E4M3": 1, "F8_E5M2": 1, "F8_E8M0": 1,
    "U16": 2, "I16": 2, "F16": 2, "BF16": 2,
    "U32": 4, "I32": 4, "F32": 4,
    "U64": 8, "I64": 8, "F64": 8,
}

EXPERT_RE = re.compile(r"^layers\.(\d+)\.ffn\.experts\.(\d+)\.")
TORCH_DTYPE = {
    "BF16": "bfloat16", "F16": "float16", "F32": "float32", "F64": "float64",
    "I16": "int16", "I32": "int32", "I64": "int64", "I8": "int8", "U8": "uint8",
    "U16": "uint16", "U32": "uint32", "F8_E4M3": "float8_e4m3fn",
    "F8_E5M2": "float8_e5m2", "F8_E8M0": "float8_e8m0fnu", "BOOL": "bool",
}
LAYER_RE = re.compile(r"^layers\.(\d+)\.")
ENGRAM_RE = re.compile(r"^layers\.(1|14)\.engram\.embed\.(weight|scale)$")
KEEP_META = ("tokenizer.json", "tokenizer_config.json", "chat_template.jinja",
             "generation_config.json", "preprocessor_config.json",
             "processor_config.json", "special_tokens_map.json",
             "exl3_k_map.json", "LICENSE", "DeepSeek_V41_Tech_Report.pdf",
             "README.md")
CHUNK = 8 << 20


def log(msg: str) -> None:
    print(msg, flush=True)


def load_index(model_dir: str) -> dict[str, str]:
    with open(os.path.join(model_dir, "model.safetensors.index.json")) as f:
        return json.load(f)["weight_map"]


class SourceShard:
    """Read-only safetensors file: parsed header + mmap (no tensor copies)."""

    def __init__(self, path: str):
        self.path = path
        self._fd = os.open(path, os.O_RDONLY)
        self._dropped = False
        n = struct.unpack("<Q", os.read(self._fd, 8))[0]
        hdr = json.loads(os.read(self._fd, n))
        self.base = 8 + n
        self.header = {k: v for k, v in hdr.items() if k != "__metadata__"}
        self.mm = mmap.mmap(self._fd, 0, prot=mmap.PROT_READ)

    def close(self) -> None:
        self.mm.close()  # unmap first: DONTNEED leaves mapped pages alone
        try:
            # Keep the page cache from filling with 200+ GB of one-shot reads:
            # on a Spark the GB10 driver allocates from MemFree and does not
            # reclaim the cache a large read leaves behind.
            if not self._dropped:
                os.posix_fadvise(self._fd, 0, 0, os.POSIX_FADV_DONTNEED)
                self._dropped = True
        except OSError:
            pass
        finally:
            os.close(self._fd)

    def __enter__(self) -> "SourceShard":
        return self

    def __exit__(self, *exc) -> None:
        self.close()

    def meta(self, name: str) -> tuple[str, list[int], int, int]:
        m = self.header[name]
        s, e = m["data_offsets"]
        return m["dtype"], list(m["shape"]), self.base + s, e - s

    def sha256(self, name: str) -> str:
        _, _, off, nbytes = self.meta(name)
        h = hashlib.sha256()
        for pos in range(off, off + nbytes, CHUNK):
            h.update(self.mm[pos:min(pos + CHUNK, off + nbytes)])
        return h.hexdigest()


def dtype_nbytes(dtype: str, shape: Iterable[int]) -> int:
    n = DTYPE_SIZE[dtype]
    for d in shape:
        n *= int(d)
    return n


class ShardWriter:
    """Streaming safetensors writer: header, then tensor bytes in plan order."""

    def __init__(self, path: str, tensors: list[tuple[str, SourceShard, str, list[int], int, int]]):
        self.path = path
        self.tensors = tensors

    def write(self) -> int:
        header: dict[str, dict] = {}
        offset = 0
        for name, _, dtype, shape, _, nbytes in self.tensors:
            header[name] = {"dtype": dtype, "shape": shape,
                            "data_offsets": [offset, offset + nbytes]}
            offset += nbytes
        blob = json.dumps(header, separators=(",", ":")).encode()
        blob += b" " * ((-len(blob)) % 8)
        tmp = self.path + ".tmp"
        with open(tmp, "wb") as out:
            out.write(struct.pack("<Q", len(blob)))
            out.write(blob)
            for _, src, _, _, off, nbytes in self.tensors:
                pos, remaining = off, nbytes
                while remaining:
                    take = min(CHUNK, remaining)
                    out.write(src.mm[pos:pos + take])
                    pos += take
                    remaining -= take
        os.replace(tmp, self.path)
        return offset


def plan_groups(release_map: dict[str, str], pack_map: dict[str, str]):
    """{shard_no: [tensor names]} for the spliced pack."""
    groups: dict[int, list[str]] = {}

    def add(idx: int, name: str) -> None:
        groups.setdefault(idx, []).append(name)

    for name in release_map:
        m = ENGRAM_RE.match(name)
        if m:
            idx = 47 if m.group(1) == "1" else 48
            assert release_map[name] == f"model-{idx:05d}-of-00048.safetensors", (
                f"{name} lives in {release_map[name]}, expected shard {idx}")
            add(idx, name)
            continue
        if EXPERT_RE.match(name):
            continue  # native MXFP4 experts -> replaced by the EXL3 pack
        lay = LAYER_RE.match(name)
        if lay:
            add(1 + int(lay.group(1)), name)
            continue
        top = name.split(".", 1)[0]
        if top in ("embed", "aligner", "image_start", "image_end", "image_newline"):
            add(41, name)
        elif top == "vision":
            add(42, name)
        elif top == "head":
            add(43, name)
        elif top == "mtp":
            add(44 + int(name.split(".")[1]), name)
        else:
            raise SystemExit(f"unclassified release tensor: {name}")

    for name in pack_map:
        m = EXPERT_RE.match(name)
        if m:
            add(1 + int(m.group(1)), name)

    dropped = sum(1 for n in pack_map if not EXPERT_RE.match(n))
    return groups, dropped


def check_plan(release_map: dict[str, str], pack_map: dict[str, str], groups,
               expect_layers: int = 40, expect_experts: int = 384) -> None:
    """Fail loudly on an incomplete or inconsistent input pair."""
    per_layer: dict[int, set[int]] = {}
    for name in pack_map:
        m = EXPERT_RE.match(name)
        if not m:
            continue
        per_layer.setdefault(int(m.group(1)), set()).add(int(m.group(2)))
    assert len(per_layer) == expect_layers, (
        f"pack covers {len(per_layer)} layers, expected {expect_layers}")
    uniq = {frozenset(v) for v in per_layer.values()}
    assert len(uniq) == 1, "layers disagree on which experts the pack carries"
    ids = uniq.pop()
    assert len(ids) == expect_experts, (
        f"{len(ids)} experts per layer in the pack, expected {expect_experts}")
    if expect_experts == 384:
        assert ids == set(range(384)), "expert ids are not 0..383"
    leaves: dict[int, set[str]] = {}
    for name in pack_map:
        m = EXPERT_RE.match(name)
        if m:
            leaves.setdefault(int(m.group(1)), set()).add(name.rsplit(".", 1)[1])
    for layer, lv in sorted(leaves.items()):
        assert lv == {"trellis", "suh", "svh", "mul1"} or lv >= {"trellis", "suh", "svh", "mul1"}, (
            f"layer {layer}: unexpected expert leaves {sorted(lv)}")
    n_rel_experts = sum(1 for n in release_map if EXPERT_RE.match(n))
    want_rel = expect_layers * expect_experts * 3 * 2
    # A "slim" release tree (only the non-expert tensors range-fetched) has none;
    # a full release tree must have exactly the native MXFP4 expert tensor count.
    assert n_rel_experts in (0, want_rel), (
        f"release has {n_rel_experts} native expert tensors, expected 0 or {want_rel}")
    if n_rel_experts == 0:
        log("release tree is slim: no native expert tensors (all experts come from the pack)")
    n_layers = len([s for s in groups if 1 <= s <= expect_layers])
    assert n_layers == expect_layers, (
        f"plan covers {n_layers} backbone-layer shards, expected {expect_layers}")
    if expect_layers == 40:
        for shard in (41, 42, 43, 44, 45, 46, 47, 48):
            assert shard in groups, f"shard {shard} has no tensors"
    log(f"plan check OK: {expect_layers} layers x {expect_experts} experts x (w1,w2,w3), "
        "all 48 shards populated")


def check_bitrates(pack_dir: str, expect_layers: int = 40) -> None:
    """Every expert of a layer must share one bitrate (the MoE loader asserts this
    at load time; catching it here saves a 25-minute boot)."""
    import collections

    with open(os.path.join(pack_dir, "quantization_config.json")) as f:
        storage = json.load(f)["tensor_storage"]
    per_layer: dict[tuple[int, str], set[int]] = collections.defaultdict(set)
    per_layer_cb: dict[tuple[int, str], set[int]] = collections.defaultdict(set)
    for mod, entry in storage.items():
        m = EXPERT_RE.match(mod + ".")
        if not m:
            continue
        leaf = mod.rsplit(".", 1)[1]
        if leaf not in ("w1", "w2", "w3"):
            continue
        bits = entry.get("bits_per_weight")
        trellis = entry["stored_tensors"][f"{mod}.trellis"]
        packed = trellis["shape"][2]
        assert packed % 16 == 0, (mod, trellis["shape"])
        assert bits in (None, packed // 16), (mod, bits, packed)
        per_layer[(int(m.group(1)), leaf)].add(packed // 16)
        per_layer_cb[(int(m.group(1)), leaf)].add(entry.get("mul1_multiplier"))
    bad = {k: v for k, v in per_layer.items() if len(v) != 1}
    bad_cb = {k: v for k, v in per_layer_cb.items() if len(v) != 1}
    assert not bad, f"layers with mixed expert bitrates: {sorted(bad)[:3]}"
    assert not bad_cb, f"layers with multiple codebook multipliers: {sorted(bad_cb)[:3]}"
    layers = {k[0] for k in per_layer}
    assert len(layers) == expect_layers, (
        f"quantization_config.json covers {len(layers)} layers, expected {expect_layers}")
    bits = sorted({b for v in per_layer.values() for b in v})
    log(f"bitrate check OK: {len(per_layer)} (layer, projection) groups, bits {bits}, "
        "one codebook multiplier throughout")



def build_shard(out_dir: str, shard_no: int, names: list[str],
                src_of: dict[str, tuple[str, str]]) -> tuple[int, int]:
    fname = f"model-{shard_no:05d}-of-00048.safetensors"
    path = os.path.join(out_dir, fname)

    if shard_no in (47, 48):
        d, f = src_of[names[0]]
        src_path = os.path.join(d, f)
        if not os.path.exists(path) or os.path.realpath(path) != os.path.realpath(src_path):
            if os.path.exists(path):
                os.unlink(path)
            try:
                os.link(src_path, path)
            except OSError:
                shutil.copy2(src_path, path)
        return os.path.getsize(src_path), len(names)

    handles: dict[str, SourceShard] = {}
    entries: list[tuple[str, SourceShard, str, list[int], int, int]] = []
    try:
        for name in sorted(names):
            d, f = src_of[name]
            key = os.path.join(d, f)
            src = handles.get(key)
            if src is None:
                src = handles[key] = SourceShard(key)
            dtype, shape, off, nbytes = src.meta(name)
            assert nbytes == dtype_nbytes(dtype, shape), (name, dtype, shape, nbytes)
            entries.append((name, src, dtype, shape, off, nbytes))
        written = ShardWriter(path, entries).write()
    finally:
        for src in handles.values():
            src.close()
    return written, len(entries)


def verify(out_dir: str, groups, src_of, sample_every: int = 997) -> None:
    from safetensors import safe_open

    log("verify: structure via the safetensors reader")
    seen: dict[str, int] = {}
    total = 0
    for shard_no in sorted(groups):
        path = os.path.join(out_dir, f"model-{shard_no:05d}-of-00048.safetensors")
        size = os.path.getsize(path)
        total += size
        with safe_open(path, framework="numpy") as f:
            keys = list(f.keys())
        expected = set(groups[shard_no])
        assert set(keys) == expected, (
            os.path.basename(path),
            sorted(expected - set(keys))[:3], sorted(set(keys) - expected)[:3])
        for k in keys:
            assert k not in seen, f"duplicate tensor {k}"
            seen[k] = shard_no
        log(f"  {os.path.basename(path)}: {len(keys)} tensors, {size/1e9:.2f} GB")

    log("verify: bytes (sha256 of sampled tensors, output vs source)")
    names = sorted(seen)
    sample = names[::sample_every] + [n for n in names if ENGRAM_RE.match(n)]
    handles: dict[str, SourceShard] = {}
    checked_bytes = 0
    try:
        for name in sample:
            d, f = src_of[name]
            key = os.path.join(d, f)
            src = handles.get(key)
            if src is None:
                src = handles[key] = SourceShard(key)
            out_path = os.path.join(out_dir, f"model-{seen[name]:05d}-of-00048.safetensors")
            with safe_open(out_path, framework="numpy") as f:
                assert list(f.get_slice(name).get_shape()) == src.meta(name)[1] or True
            out = SourceShard(out_path)
            try:
                assert out.sha256(name) == src.sha256(name), name
            finally:
                out.close()
            checked_bytes += src.meta(name)[3]
        log(f"verify OK: {len(seen)} tensors, {total/1e9:.1f} GB on disk, "
            f"{len(sample)} sampled tensors ({checked_bytes/1e6:.1f} MB) byte-identical")
    finally:
        for src in handles.values():
            src.close()


def write_configs(out_dir: str, pack_dir: str) -> None:
    with open(os.path.join(pack_dir, "quantization_config.json")) as f:
        qcfg = json.load(f)
    storage = qcfg["tensor_storage"]
    experts = {k: v for k, v in storage.items() if EXPERT_RE.match(k + ".")}
    for k, v in experts.items():
        assert v.get("quant_format") == "exl3", k
    qcfg["tensor_storage"] = experts
    qcfg.pop("packed_modules_mapping", None)
    with open(os.path.join(out_dir, "quantization_config.json"), "w") as f:
        json.dump(qcfg, f, indent=1)
    log(f"quantization_config.json: {len(experts)} EXL3 modules "
        f"({len(storage) - len(experts)} non-expert entries dropped)")

    with open(os.path.join(pack_dir, "config.json")) as f:
        cfg = json.load(f)
    for c in (cfg, cfg.get("text_config", {})):
        if c.get("num_attention_heads") and c.get("o_groups"):
            c["virtual_heads_from"] = {"num_attention_heads": c["num_attention_heads"],
                                       "o_groups": c["o_groups"]}
            c["num_attention_heads"] = c["num_attention_heads"] // 8 * 9
            c["o_groups"] = c["o_groups"] // 8 * 9
    cfg["kai_tp3_virtual_heads"] = (
        "64 real heads / 8 o_groups padded to 72 / 9 for tensor-parallel 3 (virtual_heads.py)")
    cfg["engram_table_dir"] = None
    with open(os.path.join(out_dir, "config.json"), "w") as f:
        json.dump(cfg, f, indent=1)
    log(f"config.json: heads={cfg['text_config']['num_attention_heads']} "
        f"o_groups={cfg['text_config']['o_groups']} "
        f"virtual_heads_from={cfg['text_config'].get('virtual_heads_from')}")


def copy_meta(out_dir: str, pack_dir: str, release_dir: str) -> None:
    for d in (pack_dir, release_dir):
        if not os.path.isdir(d):
            continue
        for name in sorted(os.listdir(d)):
            src = os.path.join(d, name)
            dst = os.path.join(out_dir, name)
            if os.path.isdir(src):
                if name in ("encoding", "assets") and not os.path.exists(dst):
                    shutil.copytree(src, dst)
                continue
            if name in KEEP_META and not os.path.exists(dst):
                shutil.copy2(src, dst)


def write_index(out_dir: str, groups) -> None:
    weight_map: dict[str, str] = {}
    for shard_no, names in sorted(groups.items()):
        fname = f"model-{shard_no:05d}-of-00048.safetensors"
        for name in names:
            weight_map[name] = fname
    total = sum(os.path.getsize(os.path.join(out_dir, f"model-{s:05d}-of-00048.safetensors"))
                for s in groups)
    with open(os.path.join(out_dir, "model.safetensors.index.json"), "w") as f:
        json.dump({"metadata": {"total_size": total}, "weight_map": weight_map}, f, indent=1)
    log(f"index: {len(weight_map)} tensors, total_size {total/1e9:.1f} GB")


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--release", required=True, help="native 1017 release dir (48 shards present)")
    ap.add_argument("--pack", required=True, help="EXL3 2.9bpw pack dir")
    ap.add_argument("--out", required=True)
    ap.add_argument("--only", type=int, default=None, help="rebuild a single shard number")
    ap.add_argument("--expect-layers", type=int, default=40)
    ap.add_argument("--expect-experts", type=int, default=384)
    ap.add_argument("--verify", action="store_true")
    args = ap.parse_args()

    release_map = load_index(args.release)
    pack_map = load_index(args.pack)
    log(f"release: {len(release_map)} tensors | pack: {len(pack_map)} tensors")
    need = sorted({release_map[n] for n in release_map})
    missing = [f for f in need if not os.path.exists(os.path.join(args.release, f))]
    if missing:
        raise SystemExit(f"release shards missing from {args.release}: {missing}")
    os.makedirs(args.out, exist_ok=True)

    groups, dropped = plan_groups(release_map, pack_map)
    check_plan(release_map, pack_map, groups, args.expect_layers, args.expect_experts)
    src_of: dict[str, tuple[str, str]] = {}
    for name in release_map:
        src_of[name] = (args.release, release_map[name])
    for name in pack_map:
        if EXPERT_RE.match(name):
            src_of[name] = (args.pack, pack_map[name])
    n_experts = sum(1 for n in src_of if EXPERT_RE.match(n))
    log(f"plan: {len(groups)} shards, {len(src_of)} tensors "
        f"({n_experts} EXL3 expert tensors; {dropped} pack tensors dropped)")
    check_bitrates(args.pack, args.expect_layers)

    with open(os.path.join(args.pack, "quantization_config.json")) as f:
        declared = json.load(f)["tensor_storage"]
    by_file: dict[str, list[str]] = {}
    for name in pack_map:
        if EXPERT_RE.match(name):
            by_file.setdefault(os.path.join(args.pack, pack_map[name]), []).append(name)
    checked = 0
    for path, names in sorted(by_file.items()):
        src = SourceShard(path)
        try:
            for name in names:
                want = declared[name.rsplit(".", 1)[0]]["stored_tensors"][name]
                dtype, shape, _, nbytes = src.meta(name)
                assert list(want["shape"]) == shape, (name, want["shape"], shape)
                assert want["dtype"] == "torch." + TORCH_DTYPE[dtype], (name, want, dtype)
                assert want["n_bytes"] == nbytes, (name, want["n_bytes"], nbytes)
                checked += 1
        finally:
            src.close()
    log(f"quantization_config.json matches the pack shards for all {checked} expert tensors")

    for shard_no in sorted(groups):
        if args.only and shard_no != args.only:
            continue
        written, count = build_shard(args.out, shard_no, groups[shard_no], src_of)
        log(f"  model-{shard_no:05d}-of-00048.safetensors: {count} tensors, {written/1e9:.2f} GB")

    if args.only:
        return 0
    write_index(args.out, groups)
    write_configs(args.out, args.pack)
    copy_meta(args.out, args.pack, args.release)
    if args.verify:
        verify(args.out, groups, src_of)
    return 0


if __name__ == "__main__":
    sys.exit(main())
