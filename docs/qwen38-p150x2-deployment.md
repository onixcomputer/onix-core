# Qwen3.8-27B P150x2 deployment

## Scope

This receipt records the `britton-desktop` NixOS deployment on 2026-08-20.

- System unit: `qwen38-p150x2.service`
- Endpoint: `http://127.0.0.1:8000`
- Model revision: `1d4bf0f2ff6012fd82039f2fa52739d0dd7c60c0`
- `tenstorrent.nix` revision: `19ce6ed7a66100173a438e9d89da266e6ac08421`
- Physical devices: `/dev/tenstorrent/0` and `/dev/tenstorrent/1`
- NixOS closure: resolved from the committed `onix-core` revision during deployment

## Observed results

The focused accelerator inventory check passed. The Mesh-LLM sidecar check passed. The complete `britton-desktop` system closure built successfully.

The NixOS generation activated successfully. The current system and boot profile resolved to the same committed closure.

The system service passed a clean restart. Its health endpoint returned:

```json
{"model": "Qwen3.8-27B", "status": "ok"}
```

Completion and chat requests passed. The negative checks rejected streaming, a wrong model name, and an unsupported route.

One root-owned Python process held both Tenstorrent device nodes. The former VibeThinker and P150 Llama units were absent.

The temporary per-user Qwen unit and its manual package garbage-collection root were removed. Mesh-LLM remained active after the transition.

## Validation limits

No physical reboot occurred during this session. Boot persistence is proven only by the matching boot profile and generated `multi-user.target` dependency.

This receipt does not extend the existing sequence-length, concurrency, streaming, thermal, or performance claims.

`nix flake check --no-build -L` evaluated Qwen and machine outputs. It stopped at an unrelated Devenv current-directory assertion.

The full `nix fmt` command also reached a pre-existing invalid vendored template. The changed Nix files passed focused `nixfmt` formatting.
