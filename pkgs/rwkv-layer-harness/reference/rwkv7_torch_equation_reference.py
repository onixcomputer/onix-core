#!/usr/bin/env python3
"""Pinned CPU PyTorch equation comparison for the RWKV-7 reference harness."""

# Validation diagnostics stay local to each fail-closed branch for auditability.
# ruff: noqa: EM101, EM102, TRY003, TRY004

from __future__ import annotations

import argparse
import json
import math
import sys
from dataclasses import dataclass
from pathlib import Path
from typing import Any

import blake3
import torch
import torch.nn.functional as functional
from safetensors.torch import load_file

SCHEMA_VERSION = 1
MODEL_ID = "RWKV/RWKV7-Goose-World2.8-0.1B-HF"
MODEL_REVISION = "d81965cb4e1a9f96696b4f70b84212b8f2e43216"
MODEL_SHA256_SRI = "sha256-uWqL3CHhX3HgyVZT3MO+ieVkthmtUHPJ7b+9B/eElFM="
MODEL_BLAKE3 = "905f82048a64b881f9267117a398feb8a8a92bcc5233666bf67904e0d899d0e5"
MODEL_BYTE_COUNT = 382_111_072
HF_SOURCE_REVISION = MODEL_REVISION
HF_SOURCE_SHA256_SRI = "sha256-CwBZk2Oziq7f+c1xUZ1aDqfHSOHXcaTXQkNp+S6FChc="
HF_SOURCE_BLAKE3 = "4c2c9b2527655e17ca74780f8e85597c39cd94497bc862850798478c0d53e5cd"
HF_SOURCE_BYTE_COUNT = 157
FLA_SOURCE_REVISION = "17dd5662554d46b6bcb1d1ff728cebb461c9aef9"
FLA_SOURCE_SHA256_SRI = "sha256-h6+adGlQ+98G4s/NnRDZwM1arEm1JUurWhrGhC9J/YM="
FLA_SOURCE_BLAKE3 = "0545577a163e4d6d641ccfb630166ac8c5ee2f82178162b6bea5c2b953d623f9"
FLA_SOURCE_BYTE_COUNT = 14_696
OFFICIAL_SOURCE_REVISION = "e6f74b63a06e08606d130043599d218209628bad"
OFFICIAL_SOURCE_SHA256_SRI = "sha256-PYNJReeIL19qtCM5WLE20KSbwmMx7ASOtkXUjKhxbN4="
OFFICIAL_SOURCE_BLAKE3 = (
    "b55f5c0076b0bd8bab0aeba33bef2db9d77c4e47bf5412ac45c7ab406de9ffab"
)
OFFICIAL_SOURCE_BYTE_COUNT = 15_698
HIDDEN_SIZE = 768
HEAD_SIZE = 64
HEAD_COUNT = 12
INTERMEDIATE_SIZE = 3_072
MODEL_LAYER_COUNT = 12
VOCABULARY_SIZE = 65_536
PREFIX_TOKEN_IDS = [1, 2]
LAYER_NORM_EPSILON = 1.0e-5
GROUP_NORM_EPSILON = HEAD_SIZE * LAYER_NORM_EPSILON
NEGATIVE_INVERSE_SQRT_E = -0.606_530_67
NORMALIZATION_FLOOR = 1.0e-12
FRAMEWORK_THREAD_COUNT = 1
COMPLETE_VECTOR_TOLERANCE = 1.0e-4
FIXTURE_SCALAR_LOGIT_TOLERANCE = 1.0e-6
FINAL_HIDDEN_TOLERANCE = COMPLETE_VECTOR_TOLERANCE
LOGITS_TOLERANCE = COMPLETE_VECTOR_TOLERANCE
RECURRENT_STATE_TOLERANCE = COMPLETE_VECTOR_TOLERANCE
EXPECTED_FINAL_HIDDEN_COUNT = HIDDEN_SIZE
EXPECTED_LOGIT_COUNT = VOCABULARY_SIZE
EXPECTED_RECURRENT_STATE_COUNT = MODEL_LAYER_COUNT * HEAD_COUNT * HEAD_SIZE * HEAD_SIZE
NON_CLAIMS = [
    "No FLA kernel/runtime parity is established.",
    "No Transformers generation parity is established.",
    "No official checkpoint-runtime numerical parity is established.",
    "No general RWKV correctness is established.",
    "No GPU, P150, Metalium, or ttWKV7 parity is established.",
    "No repaired-reader completion is established.",
    "No throughput or latency claim is established.",
]


@dataclass(frozen=True)
class LayerState:
    attention_previous: torch.Tensor
    ffn_previous: torch.Tensor
    matrix: torch.Tensor


@dataclass(frozen=True)
class Comparison:
    element_count: int
    maximum_absolute_deviation: float
    tolerance: float
    valid: bool


def parse_arguments() -> argparse.Namespace:
    parser = argparse.ArgumentParser(allow_abbrev=False)
    parser.add_argument("--model", type=Path)
    parser.add_argument("--rust-fixture", type=Path)
    parser.add_argument("--hf-source", type=Path)
    parser.add_argument("--fla-source", type=Path)
    parser.add_argument("--official-source", type=Path)
    parser.add_argument("--self-test", action="store_true")
    arguments = parser.parse_args()
    if arguments.self_test:
        supplied_paths = [
            arguments.model,
            arguments.rust_fixture,
            arguments.hf_source,
            arguments.fla_source,
            arguments.official_source,
        ]
        if any(path is not None for path in supplied_paths):
            parser.error("--self-test does not accept authority paths")
        return arguments
    required = {
        "--model": arguments.model,
        "--rust-fixture": arguments.rust_fixture,
        "--hf-source": arguments.hf_source,
        "--fla-source": arguments.fla_source,
        "--official-source": arguments.official_source,
    }
    missing = [name for name, value in required.items() if value is None]
    if missing:
        parser.error(f"missing required arguments: {', '.join(missing)}")
    return arguments


def require_regular_file(path: Path, name: str, require_store: bool) -> bytes:
    resolved = path.resolve(strict=True)
    if require_store and not resolved.is_relative_to("/nix/store"):
        raise ValueError(f"{name} must resolve under /nix/store: {resolved}")
    if not resolved.is_file():
        raise ValueError(f"{name} must be a regular file: {resolved}")
    return resolved.read_bytes()


def source_receipt(
    name: str,
    path: Path,
    revision: str,
    sha256_sri: str,
    expected_blake3: str,
    expected_byte_count: int,
) -> dict[str, Any]:
    content = require_regular_file(path, name, require_store=True)
    actual_blake3 = blake3.blake3(content).hexdigest()
    if actual_blake3 != expected_blake3:
        raise ValueError(
            f"{name} BLAKE3 mismatch: expected {expected_blake3}, found {actual_blake3}"
        )
    if len(content) != expected_byte_count:
        raise ValueError(
            f"{name} byte count mismatch: expected {expected_byte_count}, found {len(content)}"
        )
    return {
        "name": name,
        "revision": revision,
        "sha256_sri": sha256_sri,
        "blake3": actual_blake3,
        "byte_count": len(content),
    }


def validate_rust_fixture(fixture: dict[str, Any]) -> None:
    required_fields = {
        "schema_version",
        "model",
        "dimensions",
        "layer_count",
        "prefix_token_ids",
        "arithmetic_precision",
        "final_hidden",
        "logits",
        "recurrent_states",
        "generated_token_id",
        "generated_logit",
        "runner_up_token_id",
        "runner_up_logit",
    }
    missing = sorted(required_fields.difference(fixture))
    if missing:
        raise ValueError(f"Rust fixture is missing fields: {missing}")
    if fixture["schema_version"] != SCHEMA_VERSION:
        raise ValueError("Rust fixture schema version changed")
    if fixture["model"]["model_id"] != MODEL_ID:
        raise ValueError("Rust fixture model ID changed")
    if fixture["model"]["revision"] != MODEL_REVISION:
        raise ValueError("Rust fixture model revision changed")
    if fixture["model"]["sha256_sri"] != MODEL_SHA256_SRI:
        raise ValueError("Rust fixture model SHA-256 changed")
    if fixture["model"]["blake3"] != MODEL_BLAKE3:
        raise ValueError("Rust fixture model BLAKE3 changed")
    if fixture["model"]["byte_count"] != MODEL_BYTE_COUNT:
        raise ValueError("Rust fixture model byte count changed")
    if fixture["prefix_token_ids"] != PREFIX_TOKEN_IDS:
        raise ValueError("Rust fixture prefix changed")
    dimensions = fixture["dimensions"]
    expected_dimensions = {
        "hidden_size": HIDDEN_SIZE,
        "head_size": HEAD_SIZE,
        "head_count": HEAD_COUNT,
        "intermediate_size": INTERMEDIATE_SIZE,
    }
    if dimensions != expected_dimensions or fixture["layer_count"] != MODEL_LAYER_COUNT:
        raise ValueError("Rust fixture dimensions changed")
    if fixture["arithmetic_precision"] != "cpu_fp32_from_bf16":
        raise ValueError("Rust fixture arithmetic precision changed")
    expected_lengths = {
        "final_hidden": EXPECTED_FINAL_HIDDEN_COUNT,
        "logits": EXPECTED_LOGIT_COUNT,
        "recurrent_states": EXPECTED_RECURRENT_STATE_COUNT,
    }
    for name, expected_length in expected_lengths.items():
        values = fixture[name]
        if not isinstance(values, list) or len(values) != expected_length:
            raise ValueError(f"Rust fixture {name} requires {expected_length} elements")
        if not all(
            isinstance(value, (int, float)) and math.isfinite(value) for value in values
        ):
            raise ValueError(f"Rust fixture {name} contains a non-finite value")
    fixture_top = top_two(torch.tensor(fixture["logits"], dtype=torch.float32))
    stated_top = (
        (fixture["generated_token_id"], fixture["generated_logit"]),
        (fixture["runner_up_token_id"], fixture["runner_up_logit"]),
    )
    for rank, (computed, stated) in enumerate(
        zip(fixture_top, stated_top, strict=True)
    ):
        if not isinstance(stated[0], int) or not isinstance(stated[1], (int, float)):
            raise ValueError(f"Rust fixture top-two rank {rank} has invalid types")
        if computed[0] != stated[0] or not math.isfinite(stated[1]):
            raise ValueError(f"Rust fixture top-two rank {rank} is inconsistent")
        if abs(computed[1] - stated[1]) > FIXTURE_SCALAR_LOGIT_TOLERANCE:
            raise ValueError(f"Rust fixture top-two logit {rank} is inconsistent")


def tensor(weights: dict[str, torch.Tensor], name: str) -> torch.Tensor:
    try:
        value = weights[name]
    except KeyError as error:
        raise ValueError(f"checkpoint is missing {name}") from error
    if value.dtype != torch.float32 or not torch.isfinite(value).all().item():
        raise ValueError(f"checkpoint tensor {name} is not finite FP32")
    return value


def layer_norm(
    value: torch.Tensor, weight: torch.Tensor, bias: torch.Tensor
) -> torch.Tensor:
    return functional.layer_norm(
        value,
        (HIDDEN_SIZE,),
        weight=weight,
        bias=bias,
        eps=LAYER_NORM_EPSILON,
    )


def mixed(
    current: torch.Tensor, previous: torch.Tensor, factor: torch.Tensor
) -> torch.Tensor:
    return current + (previous - current) * factor.reshape(HIDDEN_SIZE)


def linear(value: torch.Tensor, weight: torch.Tensor) -> torch.Tensor:
    return functional.linear(value, weight)


def run_layer_token(
    weights: dict[str, torch.Tensor],
    layer_index: int,
    hidden: torch.Tensor,
    state: LayerState,
    value_anchor: torch.Tensor | None,
) -> tuple[torch.Tensor, LayerState, torch.Tensor]:
    prefix = f"model.layers.{layer_index}"
    residual = hidden
    if layer_index == 0:
        residual = layer_norm(
            hidden,
            tensor(weights, f"{prefix}.pre_norm.weight"),
            tensor(weights, f"{prefix}.pre_norm.bias"),
        )
    attention_input = layer_norm(
        residual,
        tensor(weights, f"{prefix}.attn_norm.weight"),
        tensor(weights, f"{prefix}.attn_norm.bias"),
    )
    delta_previous = state.attention_previous
    x_r = mixed(attention_input, delta_previous, tensor(weights, f"{prefix}.attn.x_r"))
    x_w = mixed(attention_input, delta_previous, tensor(weights, f"{prefix}.attn.x_w"))
    x_k = mixed(attention_input, delta_previous, tensor(weights, f"{prefix}.attn.x_k"))
    x_v = mixed(attention_input, delta_previous, tensor(weights, f"{prefix}.attn.x_v"))
    x_a = mixed(attention_input, delta_previous, tensor(weights, f"{prefix}.attn.x_a"))
    x_g = mixed(attention_input, delta_previous, tensor(weights, f"{prefix}.attn.x_g"))

    receptance = linear(x_r, tensor(weights, f"{prefix}.attn.r_proj.weight"))
    raw_key = linear(x_k, tensor(weights, f"{prefix}.attn.k_proj.weight"))
    projected_value = linear(x_v, tensor(weights, f"{prefix}.attn.v_proj.weight"))
    if layer_index == 0:
        value = projected_value
        value_anchor = projected_value
    else:
        if value_anchor is None:
            raise ValueError(
                "layer zero did not establish the token-local value anchor"
            )
        value_hidden = linear(
            x_v, tensor(weights, f"{prefix}.attn.v_lora.lora.0.weight")
        )
        value_gate = torch.sigmoid(
            linear(
                value_hidden,
                tensor(weights, f"{prefix}.attn.v_lora.lora.2.weight"),
            )
            + tensor(weights, f"{prefix}.attn.v_lora.lora.2.bias")
        )
        value = torch.lerp(projected_value, value_anchor, value_gate)

    decay_hidden = torch.tanh(
        linear(x_w, tensor(weights, f"{prefix}.attn.w_lora.lora.0.weight"))
    )
    decay = torch.exp(
        NEGATIVE_INVERSE_SQRT_E
        * torch.sigmoid(
            linear(
                decay_hidden,
                tensor(weights, f"{prefix}.attn.w_lora.lora.2.weight"),
            )
            + tensor(weights, f"{prefix}.attn.w_lora.lora.2.bias")
        )
    )
    adaptation_hidden = linear(
        x_a, tensor(weights, f"{prefix}.attn.a_lora.lora.0.weight")
    )
    adaptation = torch.sigmoid(
        linear(
            adaptation_hidden,
            tensor(weights, f"{prefix}.attn.a_lora.lora.2.weight"),
        )
        + tensor(weights, f"{prefix}.attn.a_lora.lora.2.bias")
    )
    gate_hidden = torch.sigmoid(
        linear(x_g, tensor(weights, f"{prefix}.attn.g_lora.lora.0.weight"))
    )
    gate = linear(gate_hidden, tensor(weights, f"{prefix}.attn.g_lora.lora.2.weight"))

    key_key = raw_key * tensor(weights, f"{prefix}.attn.k_k")
    key_key = functional.normalize(
        key_key.reshape(HEAD_COUNT, HEAD_SIZE),
        p=2.0,
        dim=-1,
        eps=NORMALIZATION_FLOOR,
    )
    key = raw_key * (1.0 + (adaptation - 1.0) * tensor(weights, f"{prefix}.attn.k_a"))
    receptance_heads = receptance.reshape(HEAD_COUNT, HEAD_SIZE)
    key_heads = key.reshape(HEAD_COUNT, HEAD_SIZE)
    value_heads = value.reshape(HEAD_COUNT, HEAD_SIZE)
    adaptation_heads = adaptation.reshape(HEAD_COUNT, HEAD_SIZE)
    decay_heads = decay.reshape(HEAD_COUNT, HEAD_SIZE)
    state_dot_a = torch.matmul(state.matrix, -key_key.unsqueeze(-1)).squeeze(-1)
    next_matrix = (
        state.matrix * decay_heads.unsqueeze(-2)
        + state_dot_a.unsqueeze(-1) * (key_key * adaptation_heads).unsqueeze(-2)
        + value_heads.unsqueeze(-1) * key_heads.unsqueeze(-2)
    )
    recurrent_output = torch.matmul(
        next_matrix, receptance_heads.unsqueeze(-1)
    ).squeeze(-1)
    normalized = functional.group_norm(
        recurrent_output.reshape(1, HIDDEN_SIZE, 1),
        num_groups=HEAD_COUNT,
        weight=tensor(weights, f"{prefix}.attn.g_norm.weight"),
        bias=tensor(weights, f"{prefix}.attn.g_norm.bias"),
        eps=GROUP_NORM_EPSILON,
    ).reshape(HIDDEN_SIZE)
    correction_scale = torch.sum(
        receptance_heads
        * key_heads
        * tensor(weights, f"{prefix}.attn.r_k").reshape(HEAD_COUNT, HEAD_SIZE),
        dim=-1,
    )
    corrected = (
        normalized.reshape(HEAD_COUNT, HEAD_SIZE)
        + correction_scale.unsqueeze(-1) * value_heads
    ).reshape(HIDDEN_SIZE) * gate
    attention_output = linear(
        corrected, tensor(weights, f"{prefix}.attn.o_proj.weight")
    )
    after_attention = residual + attention_output

    ffn_input = layer_norm(
        after_attention,
        tensor(weights, f"{prefix}.ffn_norm.weight"),
        tensor(weights, f"{prefix}.ffn_norm.bias"),
    )
    ffn_mixed = mixed(
        ffn_input, state.ffn_previous, tensor(weights, f"{prefix}.ffn.x_k")
    )
    ffn_key = torch.relu(
        linear(ffn_mixed, tensor(weights, f"{prefix}.ffn.key.weight"))
    ).square()
    ffn_output = linear(ffn_key, tensor(weights, f"{prefix}.ffn.value.weight"))
    next_hidden = after_attention + ffn_output
    next_state = LayerState(
        attention_previous=attention_input,
        ffn_previous=ffn_input,
        matrix=next_matrix,
    )
    return next_hidden, next_state, value_anchor


def run_reference(model_path: Path) -> tuple[torch.Tensor, torch.Tensor, torch.Tensor]:
    model_bytes = require_regular_file(model_path, "checkpoint", require_store=True)
    if len(model_bytes) != MODEL_BYTE_COUNT:
        raise ValueError("checkpoint byte count changed")
    if blake3.blake3(model_bytes).hexdigest() != MODEL_BLAKE3:
        raise ValueError("checkpoint BLAKE3 changed")

    raw_weights = load_file(str(model_path), device="cpu")
    if any(value.dtype != torch.bfloat16 for value in raw_weights.values()):
        raise ValueError("checkpoint contains a non-BF16 tensor")
    weights = {
        name: value.to(dtype=torch.float32) for name, value in raw_weights.items()
    }
    del raw_weights
    states = [
        LayerState(
            attention_previous=torch.zeros(HIDDEN_SIZE, dtype=torch.float32),
            ffn_previous=torch.zeros(HIDDEN_SIZE, dtype=torch.float32),
            matrix=torch.zeros((HEAD_COUNT, HEAD_SIZE, HEAD_SIZE), dtype=torch.float32),
        )
        for _ in range(MODEL_LAYER_COUNT)
    ]
    hidden = torch.zeros(HIDDEN_SIZE, dtype=torch.float32)
    with torch.no_grad():
        for token_id in PREFIX_TOKEN_IDS:
            hidden = tensor(weights, "model.embeddings.weight")[token_id]
            value_anchor = None
            next_states: list[LayerState] = []
            for layer_index, state in enumerate(states):
                hidden, next_state, value_anchor = run_layer_token(
                    weights, layer_index, hidden, state, value_anchor
                )
                next_states.append(next_state)
            states = next_states
        final_hidden = layer_norm(
            hidden,
            tensor(weights, "model.norm.weight"),
            tensor(weights, "model.norm.bias"),
        )
        logits = linear(final_hidden, tensor(weights, "lm_head.weight"))
        recurrent_states = torch.cat([state.matrix.reshape(-1) for state in states])
    for name, value in [
        ("final_hidden", final_hidden),
        ("logits", logits),
        ("recurrent_states", recurrent_states),
    ]:
        if not torch.isfinite(value).all().item():
            raise ValueError(f"PyTorch {name} contains non-finite values")
    return final_hidden, logits, recurrent_states


def compare_vectors(
    rust_values: list[float],
    torch_values: torch.Tensor,
    expected_count: int,
    tolerance: float,
    name: str,
) -> Comparison:
    if len(rust_values) != expected_count or torch_values.numel() != expected_count:
        raise ValueError(f"{name} vector length changed")
    rust_tensor = torch.tensor(rust_values, dtype=torch.float32)
    candidate = torch_values.reshape(-1).to(dtype=torch.float32)
    if (
        not torch.isfinite(rust_tensor).all().item()
        or not torch.isfinite(candidate).all().item()
    ):
        raise ValueError(f"{name} comparison contains non-finite values")
    deviation = torch.max(torch.abs(rust_tensor - candidate)).item()
    return Comparison(
        element_count=expected_count,
        maximum_absolute_deviation=deviation,
        tolerance=tolerance,
        valid=deviation <= tolerance,
    )


def top_two(values: torch.Tensor) -> tuple[tuple[int, float], tuple[int, float]]:
    flattened = values.reshape(-1)
    first_id = min(
        range(flattened.numel()),
        key=lambda token_id: (-float(flattened[token_id]), token_id),
    )
    second_id = min(
        (token_id for token_id in range(flattened.numel()) if token_id != first_id),
        key=lambda token_id: (-float(flattened[token_id]), token_id),
    )
    return (
        (first_id, float(flattened[first_id])),
        (second_id, float(flattened[second_id])),
    )


def comparison_receipt(
    fixture: dict[str, Any],
    final_hidden: torch.Tensor,
    logits: torch.Tensor,
    recurrent_states: torch.Tensor,
    authorities: list[dict[str, Any]],
) -> dict[str, Any]:
    hidden_comparison = compare_vectors(
        fixture["final_hidden"],
        final_hidden,
        EXPECTED_FINAL_HIDDEN_COUNT,
        FINAL_HIDDEN_TOLERANCE,
        "final hidden",
    )
    logits_comparison = compare_vectors(
        fixture["logits"], logits, EXPECTED_LOGIT_COUNT, LOGITS_TOLERANCE, "logits"
    )
    state_comparison = compare_vectors(
        fixture["recurrent_states"],
        recurrent_states,
        EXPECTED_RECURRENT_STATE_COUNT,
        RECURRENT_STATE_TOLERANCE,
        "recurrent state",
    )
    torch_top = top_two(logits)
    rust_top = (
        (fixture["generated_token_id"], fixture["generated_logit"]),
        (fixture["runner_up_token_id"], fixture["runner_up_logit"]),
    )
    top_ids_match = [row[0] for row in torch_top] == [row[0] for row in rust_top]
    valid = (
        hidden_comparison.valid
        and logits_comparison.valid
        and state_comparison.valid
        and top_ids_match
    )
    receipt: dict[str, Any] = {
        "schema_version": SCHEMA_VERSION,
        "valid": valid,
        "model": {
            "model_id": MODEL_ID,
            "revision": MODEL_REVISION,
            "sha256_sri": MODEL_SHA256_SRI,
            "blake3": MODEL_BLAKE3,
            "byte_count": MODEL_BYTE_COUNT,
        },
        "sources": authorities,
        "framework": {
            "name": "PyTorch",
            "version": torch.__version__,
            "device": "cpu",
            "thread_count": FRAMEWORK_THREAD_COUNT,
            "arithmetic_precision": "cpu_fp32_from_bf16",
        },
        "prefix_token_ids": PREFIX_TOKEN_IDS,
        "comparisons": {
            "final_hidden": hidden_comparison.__dict__,
            "logits": logits_comparison.__dict__,
            "recurrent_states": state_comparison.__dict__,
        },
        "rust_top_two": [
            {"token_id": rust_top[0][0], "logit": rust_top[0][1]},
            {"token_id": rust_top[1][0], "logit": rust_top[1][1]},
        ],
        "torch_top_two": [
            {"token_id": torch_top[0][0], "logit": torch_top[0][1]},
            {"token_id": torch_top[1][0], "logit": torch_top[1][1]},
        ],
        "top_two_token_ids_match": top_ids_match,
        "non_claims": NON_CLAIMS,
    }
    canonical = json.dumps(receipt, sort_keys=True, separators=(",", ":")).encode()
    receipt["receipt_blake3"] = blake3.blake3(canonical).hexdigest()
    return receipt


def run_self_test() -> dict[str, Any]:
    fixture = [1.0, -2.0]
    exact = compare_vectors(
        fixture,
        torch.tensor(fixture),
        len(fixture),
        FINAL_HIDDEN_TOLERANCE,
        "self-test",
    )
    if not exact.valid or exact.maximum_absolute_deviation != 0.0:
        raise AssertionError("exact comparison self-test failed")
    changed_value = FINAL_HIDDEN_TOLERANCE + FINAL_HIDDEN_TOLERANCE
    changed = compare_vectors(
        fixture,
        torch.tensor([fixture[0] + changed_value, fixture[1]]),
        len(fixture),
        FINAL_HIDDEN_TOLERANCE,
        "self-test",
    )
    if changed.valid:
        raise AssertionError("changed-vector self-test did not fail")
    try:
        compare_vectors(
            fixture,
            torch.tensor([fixture[0]]),
            len(fixture),
            FINAL_HIDDEN_TOLERANCE,
            "self-test",
        )
    except ValueError as error:
        if "length" not in str(error):
            raise
    else:
        raise AssertionError("malformed-vector self-test did not fail")
    return {
        "schema_version": SCHEMA_VERSION,
        "valid": True,
        "exact_comparison_valid": exact.valid,
        "changed_vector_rejected": not changed.valid,
        "malformed_vector_rejected": True,
    }


def main() -> int:
    arguments = parse_arguments()
    torch.set_num_threads(FRAMEWORK_THREAD_COUNT)
    torch.set_num_interop_threads(FRAMEWORK_THREAD_COUNT)
    if arguments.self_test:
        print(json.dumps(run_self_test(), sort_keys=True, separators=(",", ":")))
        return 0

    fixture_bytes = require_regular_file(
        arguments.rust_fixture, "Rust vector fixture", require_store=False
    )
    try:
        fixture = json.loads(fixture_bytes)
    except json.JSONDecodeError as error:
        raise ValueError(f"Rust fixture is malformed JSON: {error}") from error
    if not isinstance(fixture, dict):
        raise ValueError("Rust fixture must be a JSON object")
    validate_rust_fixture(fixture)
    authorities = [
        source_receipt(
            "modeling_rwkv7.py",
            arguments.hf_source,
            HF_SOURCE_REVISION,
            HF_SOURCE_SHA256_SRI,
            HF_SOURCE_BLAKE3,
            HF_SOURCE_BYTE_COUNT,
        ),
        source_receipt(
            "fla/layers/rwkv7.py",
            arguments.fla_source,
            FLA_SOURCE_REVISION,
            FLA_SOURCE_SHA256_SRI,
            FLA_SOURCE_BLAKE3,
            FLA_SOURCE_BYTE_COUNT,
        ),
        source_receipt(
            "RWKV-v7/rwkv_v7_demo.py",
            arguments.official_source,
            OFFICIAL_SOURCE_REVISION,
            OFFICIAL_SOURCE_SHA256_SRI,
            OFFICIAL_SOURCE_BLAKE3,
            OFFICIAL_SOURCE_BYTE_COUNT,
        ),
    ]
    final_hidden, logits, recurrent_states = run_reference(arguments.model)
    receipt = comparison_receipt(
        fixture, final_hidden, logits, recurrent_states, authorities
    )
    print(json.dumps(receipt, sort_keys=True, separators=(",", ":")))
    return 0 if receipt["valid"] else 1


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (OSError, ValueError, RuntimeError) as error:
        print(f"rwkv7_torch_equation_reference: {error}", file=sys.stderr)
        raise SystemExit(1) from error
