#!/usr/bin/env python3
"""Self-test for build_tp3_pack.py: synthetic release+pack -> splice -> verify.

Builds a miniature version of the real pair (2 layers x 1 expert x 3 projections),
runs the builder with --verify, and checks the resulting pack's index, config and
quantization_config against what the runtime needs.
"""
import json
import os
import shutil
import subprocess
import sys

import numpy as np
from safetensors.numpy import save_file

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = "/tmp/st1017"
LAYERS = (0, 1)
PROJS = ("w1", "w2", "w3")


def w(path, tensors):
    save_file({k: np.ascontiguousarray(v) for k, v in tensors.items()}, path)


def main() -> int:
    shutil.rmtree(ROOT, ignore_errors=True)
    rel, pack, out = f"{ROOT}/release", f"{ROOT}/pack", f"{ROOT}/out"
    for d in (rel, pack, out):
        os.makedirs(d)
    rng = np.random.default_rng(7)

    # ---- release: native fp8 dense + MXFP4 experts + vision/head/mtp/engram ----
    rel_files = {
        "model-00001-of-00048.safetensors": {
            "layers.0.attn_norm.weight": rng.standard_normal(8).astype(np.float32),
            "layers.0.attn.wq_a.weight": rng.integers(0, 255, (4, 4), dtype=np.uint8),
            "layers.0.attn.wq_a.weight_scale_inv": rng.integers(0, 255, (1, 1), dtype=np.uint8),
            "layers.0.ffn.shared_experts.w1.weight": rng.standard_normal((4, 4)).astype(np.float32),
            "layers.0.ffn.gate.weight": rng.standard_normal((2, 2)).astype(np.float16),
            "layers.0.hc_attn_fn": rng.standard_normal((2, 2)).astype(np.float32),
        },
        "model-00002-of-00048.safetensors": {
            "layers.1.engram.wkv.weight": rng.standard_normal((2, 2)).astype(np.float32),
        },
        "model-00041-of-00048.safetensors": {
            "embed.weight": rng.standard_normal((4, 4)).astype(np.float32),
            "aligner.w1.weight": rng.standard_normal((2,)).astype(np.float32),
            "image_start": rng.standard_normal((4,)).astype(np.float32),
        },
        "model-00042-of-00048.safetensors": {
            "vision.patch_embed.proj.weight": rng.standard_normal((2, 2)).astype(np.float32),
        },
        "model-00043-of-00048.safetensors": {
            "head.weight": rng.standard_normal((4, 4)).astype(np.float32),
        },
        "model-00044-of-00048.safetensors": {
            "mtp.0.hc_attn_base": rng.standard_normal((4,)).astype(np.float32),
        },
        "model-00047-of-00048.safetensors": {
            "layers.1.engram.embed.weight": rng.integers(0, 255, (64,), dtype=np.uint8),
            "layers.1.engram.embed.scale": rng.integers(0, 255, (8,), dtype=np.uint8),
        },
        "model-00048-of-00048.safetensors": {
            "layers.14.engram.embed.weight": rng.integers(0, 255, (64,), dtype=np.uint8),
            "layers.14.engram.embed.scale": rng.integers(0, 255, (8,), dtype=np.uint8),
        },
    }
    for layer in LAYERS:
        f = f"model-{1 + layer:05d}-of-00048.safetensors"
        d = rel_files.setdefault(f, {})
        for proj in PROJS:
            d[f"layers.{layer}.ffn.experts.0.{proj}.weight"] = rng.integers(0, 255, (16,), dtype=np.uint8)
            d[f"layers.{layer}.ffn.experts.0.{proj}.scale"] = rng.integers(0, 255, (2,), dtype=np.uint8)
    rel_map = {}
    for f, t in rel_files.items():
        w(os.path.join(rel, f), t)
        for k in t:
            rel_map[k] = f
    json.dump({"metadata": {"total_size": 1}, "weight_map": rel_map},
              open(f"{rel}/model.safetensors.index.json", "w"))

    # ---- pack: EXL3 routed experts only (plus things that must be dropped) ----
    pack_files = {}
    for layer in LAYERS:
        d = pack_files.setdefault(f"pack-{layer + 1:05d}.safetensors", {})
        for proj in PROJS:
            base = f"layers.{layer}.ffn.experts.0.{proj}"
            d[f"{base}.trellis"] = rng.integers(-32768, 32767, (2, 2, 48), dtype=np.int16)
            d[f"{base}.suh"] = rng.standard_normal(2).astype(np.float16)
            d[f"{base}.svh"] = rng.standard_normal(2).astype(np.float16)
            d[f"{base}.mul1"] = np.array([-2082680531], dtype=np.int32)
    pack_files["pack-90001.safetensors"] = {
        "layers.0.ffn.shared_experts.w1.trellis": rng.integers(-8, 8, (2, 2, 16), dtype=np.int16),
        "layers.0.ffn.shared_experts.w1.suh": rng.standard_normal(2).astype(np.float16),
        "layers.0.ffn.shared_experts.w1.svh": rng.standard_normal(2).astype(np.float16),
        "layers.0.ffn.shared_experts.w1.mul1": np.array([-2082680531], dtype=np.int32),
        "layers.0.attn.wq_a.trellis": rng.integers(-8, 8, (2, 2, 48), dtype=np.int16),
        "embed.weight": rng.standard_normal((4, 4)).astype(np.float16),
    }
    pack_map = {}
    for f, t in pack_files.items():
        w(os.path.join(pack, f), t)
        for k in t:
            pack_map[k] = f
    json.dump({"metadata": {"total_size": 1}, "weight_map": pack_map},
              open(f"{pack}/model.safetensors.index.json", "w"))

    dtype_of = {"int16": "torch.int16", "float16": "torch.float16", "int32": "torch.int32"}
    storage = {}
    for k, arr in ((k, None) for k in pack_map):
        if ".experts." not in k:
            continue
        mod = k.rsplit(".", 1)[0]
        leaf = k.rsplit(".", 1)[1]
        storage.setdefault(mod, {"stored_tensors": {}, "quant_format": "exl3",
                                 "bits_per_weight": 3, "mul1_multiplier": 2212286765})
        shape = {"trellis": [2, 2, 48], "suh": [2], "svh": [2], "mul1": [1]}[leaf]
        dtype = {"trellis": "torch.int16", "suh": "torch.float16", "svh": "torch.float16",
                 "mul1": "torch.int32"}[leaf]
        nbytes = int(np.prod(shape)) * {"torch.int16": 2, "torch.float16": 2, "torch.int32": 4}[dtype]
        storage[mod]["stored_tensors"][k] = {"shape": shape, "dtype": dtype, "n_bytes": nbytes}
    json.dump({"quant_method": "exl3", "version": "1.6.2", "codebook": "mul1",
               "original_quantization_config": {"quant_method": "fp8", "activation_scheme": "dynamic",
                                                "weight_block_size": [32, 32], "scale_fmt": "ue8m0",
                                                "expert_dtype": "fp4"},
               "tensor_storage": storage},
              open(f"{pack}/quantization_config.json", "w"), indent=1)
    json.dump({"architectures": ["DeepseekV41ForCausalLM"], "model_type": "deepseek_v41",
               "engram_table_dir": None,
               "text_config": {"model_type": "deepseek_v41_text", "num_attention_heads": 64,
                               "o_groups": 8, "engram_layer_ids": [1, 14]},
               "quantization_config": {"quant_method": "exl3"}},
              open(f"{pack}/config.json", "w"), indent=1)

    r = subprocess.run([sys.executable, os.path.join(HERE, "build_tp3_pack.py"),
                        "--release", rel, "--pack", pack, "--out", out, "--verify",
                        "--expect-layers", str(len(LAYERS)), "--expect-experts", "1"],
                       capture_output=True, text=True)
    print(r.stdout)
    print(r.stderr, file=sys.stderr)
    if r.returncode:
        return r.returncode

    idx = json.load(open(f"{out}/model.safetensors.index.json"))["weight_map"]
    cfg = json.load(open(f"{out}/config.json"))
    qc = json.load(open(f"{out}/quantization_config.json"))
    assert "layers.0.ffn.shared_experts.w1.trellis" not in idx, "shared-expert EXL3 leaked"
    assert "layers.0.attn.wq_a.trellis" not in idx, "dense EXL3 leaked"
    assert "layers.0.ffn.experts.0.w1.weight" not in idx, "native expert leaked"
    assert "layers.0.ffn.experts.0.w1.trellis" in idx
    assert "layers.1.ffn.experts.0.w3.mul1" in idx
    assert idx["layers.0.ffn.experts.0.w1.trellis"] == "model-00001-of-00048.safetensors"
    assert idx["layers.1.ffn.experts.0.w3.mul1"] == "model-00002-of-00048.safetensors"
    assert idx["layers.1.engram.embed.weight"] == "model-00047-of-00048.safetensors"
    assert idx["layers.14.engram.embed.weight"] == "model-00048-of-00048.safetensors"
    assert idx["layers.0.ffn.shared_experts.w1.weight"] == "model-00001-of-00048.safetensors"
    assert idx["vision.patch_embed.proj.weight"] == "model-00042-of-00048.safetensors"
    assert idx["mtp.0.hc_attn_base"] == "model-00044-of-00048.safetensors"
    assert cfg["text_config"]["num_attention_heads"] == 72 and cfg["text_config"]["o_groups"] == 9
    assert cfg["text_config"]["virtual_heads_from"] == {"num_attention_heads": 64, "o_groups": 8}
    assert cfg["engram_table_dir"] is None
    assert qc["tensor_storage"] and all(".ffn.experts." in k for k in qc["tensor_storage"])
    assert not any("shared_experts" in k for k in qc["tensor_storage"])
    assert len(qc["tensor_storage"]) == len(LAYERS) * len(PROJS)
    assert os.path.samefile(f"{out}/model-00048-of-00048.safetensors",
                            f"{rel}/model-00048-of-00048.safetensors"), "engram not linked"
    print("SELFTEST OK")
    return 0


if __name__ == "__main__":
    sys.exit(main())
