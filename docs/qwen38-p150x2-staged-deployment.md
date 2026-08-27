# Qwen3.8-27B P150x2 staged-prefill deployment

## Scope

This receipt records the `britton-desktop` NixOS activation on 2026-08-26.

- System unit: `qwen38-p150x2.service`
- `tenstorrent.nix` revision: `4a308e2af71a1c9ef8ac7f4a933a2c740ed26ca7`
- `onix-core` revision: `bb53fb608e77002e3e0f2f6f5a1dd9e7f31c9cfd8` (input pin)
- Admitted package: `/nix/store/nzk9jkkgd0182d2qx9a34bs6fbhh9dsn-qwen36-0.1.0`
- Measured execution identity: `/nix/store/ixb9s8mbka76xvmh2r0k0r700dcix5xb-qwen36-execution-identity-0.1.0`
- Batch admission receipt BLAKE3: `489f2fbcb414ae04e536fc055857864c3255d727e4c12b79dc701a86ded3d028`
- NixOS closure: `fxh8jb3phcxyhpf9vjakpx7cdar8x0pz-nixos-system-britton-desktop-26.11.20260819.afe3d8a`

## Deployment

`nixos-rebuild --flake .#britton-desktop switch --target-host root@britton-desktop.clan --build-host localhost`.

The activation restarted `qwen38-p150x2.service`, `nix-daemon`, Prometheus units, and started the new `niks3-auto-upload.socket`. No unit failed.

## Observed results

Health passed after `136.26` seconds of startup warm-up (widths `1,4`). The service process runs the admitted package binary. Response evidence reports the measured execution identity `ixb9s8mb…` and stays admission-ineligible for normal traffic.

Single-stream smoke: TTFT `1.471` seconds (first request after warm-up, includes the per-request trace recapture), decode `16.7` tokens/second.

Four concurrent requests formed one B=4 batch with slices `0..3`: TTFT `3.089` seconds per row, aggregate `57.34` tokens/second, clean reset, per-request trace recapture (reuse stays disabled per its rejected receipt).

## Admission chain

The device-staged prefill path was measured on this exact artifact (`gfh4pd83`, identity `ixb9s8mb`) in matched `single,batch,batch,single` order on devices `0` and `1`:

- aggregate speedup `3.5194` (bound `3.0`)
- per-user retention `0.8799` (bound `0.75`)
- TTFT ratio `3.6365` (bound `4.5`)
- tail ratio `1.2166` (bound `1.5`)
- exact token parity: pass

Phase medians against the prior admitted artifact: B=1 TTFT `0.782` versus `0.888` seconds; B=4 state install `0.294` versus `0.494` seconds.

## Validation limits

No reboot occurred; boot persistence is proven by the matching boot profile only.

The single-2 root of the matched control was re-run after a stale device lock let systemd resurrect the production unit mid-control; the retained root carries the correct identity.

This receipt does not extend concurrency, sequence-length, thermal, or streaming claims beyond the recorded admission.
