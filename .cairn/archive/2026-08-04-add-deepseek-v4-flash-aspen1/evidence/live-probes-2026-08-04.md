# Live validation evidence — 2026-08-04

Host: aspen1 (Ryzen AI Max+ 395, Radeon 8060S gfx1151, 128 GiB UMA), NixOS generation deployed from branch `deepseek-v4-flash-aspen1`.

## Positive probes

r[verify onix.aspen1.deepseek.validation.positive]

1. Health: `curl http://127.0.0.1:13305/health` → `{"status":"ok"}`.
2. Chat: `What is 2+2?` → content `4`, reasoning `We need answer simple. 2+2=4.`
3. Long generation: 700 tokens at **26.10 tok/s** decode, prefill 42.5 tok/s. Draft telemetry in the response: `draft_n=640, draft_n_accepted=485` (75.8% acceptance). Reference guide result on identical hardware: 21.31 tok/s at 67.46% acceptance.
4. Server log confirms DSpark: `adding speculative implementation 'draft-dspark'`, `mask_token_id=128799`, `block_size=5, n_extract=3`.
5. mesh-llm seed: `GET http://127.0.0.1:9337/v1/models` lists `DeepSeek-V4-Flash-0731`; a chat through the mesh returned a valid completion with draft telemetry (`draft_n=12, draft_n_accepted=10`), 27.9 tok/s.
6. Clocks: `/sys/firmware/acpi/platform_profile` = `performance`, Radeon performance level = `high` (locked by the service pre-start).

## Negative probes

r[verify onix.aspen1.deepseek.validation.negative]

1. `systemctl is-active lemonade.service` → `inactive`; the unit is absent from the generation (`hasAttr "lemonade"` on the evaluated services set is `false`).
2. During rollout, three failure modes were observed and each failed loudly in the unit journal instead of serving degraded output: unknown draft architecture, GTT out-of-memory at draft load, and `invalid token[1] = -1` draft decode aborts from `no_vocab` draft metadata.
3. The ExecCondition model-file guard (`llamacpp-server-deepseek-v4-flash-aspen1-check-models`) blocks startup when any shard or the draft is missing.

## Operational notes

- aspen1 rebooted during rollout (43-day uptime) to apply `amdgpu.gttsize=126976` and `ttm.pages_limit=32505856`; before the reboot the live TTM limit was 100 GiB and the draft could not fit.
- The initrd-ssh host key rotated when vars were regenerated during deploy repair; expect a one-time SSH host-key warning on initrd access.
- Mesh joiners (aspen2, aspen3, britton-desktop) are unchanged and keep serving their local models.
