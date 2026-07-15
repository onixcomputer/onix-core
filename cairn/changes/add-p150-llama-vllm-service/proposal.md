## Why

`britton-desktop` has two P150 cards already occupied by VibeThinker and the 51M Supra router, so adding Llama-3.1-8B-Instruct as a third always-on service cannot safely share a card with either Metalium process. Tenstorrent recommends Llama-3.1-8B-Instruct for P150 add-in cards through its vLLM TT-Metal image, while its support matrix does not define this host's two independent cards as a `p150x2` target.

A fixed-input trial demonstrated that Supra does not need an accelerator: the CPU path produced the same BLAKE3 output at 1,031 isolated and 778 concurrent decode tokens/s, versus about 130 isolated and 97 concurrent tokens/s on the tuned Metalium path. Moving only Supra to CPU frees physical card 1 for the new model while preserving VibeThinker on physical card 0.

## What Changes

- Move Supra-Router-51M to the CPU backend while preserving its port, alias, deterministic output, and service availability.
- Add a typed `tt-inference-server` service module for the digest-pinned Tenstorrent vLLM image.
- Deploy `meta-llama/Llama-3.1-8B-Instruct` on physical P150 card 1 without stopping, replacing, or reconfiguring VibeThinker on card 0.
- Store the gated Hugging Face token in a deployed clan secret rather than the Nix store or service command line.
- Add focused positive/negative checks for model identity, image digest, device isolation, endpoint placement, and the preserved VibeThinker service.

## Impact

- **Files**: new `modules/tt-inference-server/`, service inventory and contracts, `machines/britton-desktop/configuration.nix`, focused checks, operator documentation, root `README.md` reference, and this Cairn change package
- **Runtime**: Supra remains on port 13306 through CPU llama.cpp; Llama-3.1-8B-Instruct uses the official P150 vLLM container on port 8000 and physical card 1; VibeThinker remains always-on on port 13305 and physical card 0
- **Testing**: CPU Supra parity/throughput evidence, Nickel positive/negative settings checks, complete host build, image contract inspection, concurrent three-service health/output tests, journal/device-lock audit, and Cairn gates
