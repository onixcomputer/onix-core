## Context

`aspen3` is an ASUS Flow/Strix Halo laptop using the generic repository `audio` tag. That tag disables PulseAudio, enables PipeWire ALSA/Pulse compatibility, and enables RealtimeKit. The machine-specific hardware module currently has no audio quirk handling, while checked-in hardware facts show AMD/ATI HDA devices and AMD ACP audio.

The safest improvement path is to tune session policy and user tooling rather than replacing kernels, enabling a realtime kernel, or deploying fragile live host state. Bluetooth quality can be improved through WirePlumber BlueZ policy, speaker/headphone correction can be made available through DSP tooling, and clipping-prone media-player overdrive can be constrained through an `aspen3` Home Manager override.

## Goals / Non-Goals

**Goals:**

- Prefer high-quality Bluetooth codecs on `aspen3` while keeping compatible fallbacks.
- Force LDAC-capable Bluetooth devices to use the high-quality LDAC mode when negotiated.
- Provide audio correction and graph/diagnostic tools on `aspen3`.
- Reduce avoidable software clipping from MPV on `aspen3`.
- Keep changes declarative and scoped to `aspen3` unless an existing shared source of truth is only read-only data.

**Non-Goals:**

- Do not enable a realtime kernel or add the full `pro-audio` tag in this change.
- Do not ship device-specific EQ presets without live measurement or user confirmation.
- Do not change audio behavior for non-`aspen3` machines.
- Do not mutate live host state outside normal deploy/switch workflows.

## Decisions

### Use WirePlumber policy for Bluetooth codec preference

Set `services.pipewire.wireplumber.extraConfig` on `aspen3` so BlueZ roles/codecs prefer LDAC first, then AAC, SBC-XQ, and SBC. Add a broad Bluetooth card rule that requests `bluez5.a2dp.ldac.quality = "hq"` when LDAC is used.

Alternative considered: only expose the existing Home Manager `audio.bluetooth.codec` value and rely on manual user selection. That preserves state but does not improve the runtime policy.

### Provide DSP and diagnostics tools without enabling permanent DSP state

Install EasyEffects plus PipeWire graph/control diagnostics. EasyEffects gives the user a safe path for speaker/headphone EQ, compressor, and limiter presets, while graph tools help inspect routing issues. Avoid autoloading a preset until the built-in speakers/headphones have been checked live.

Alternative considered: declaratively autostart EasyEffects and ship a fixed preset. That risks making audio worse on unknown output devices.

### Scope MPV overdrive reduction to `aspen3`

Use an `aspen3` Home Manager override to lower MPV's `volume-max` from the shared desktop default. This avoids clipping on laptop speakers without changing desktop media behavior.

Alternative considered: lower the shared default in `media-viewers.nix`. That would affect every machine importing the Noctalia desktop profile.

## Risks / Trade-offs

- Bluetooth codec order may expose codec support issues on unusual headphones → fallbacks remain available and validation is evaluation-focused; runtime pairing can still select another codec.
- LDAC high-quality mode can be less robust on noisy links → users can lower quality interactively if a specific device stutters.
- EasyEffects availability does not itself improve sound until a preset is selected → safer than applying unmeasured EQ globally.
- MPV overdrive reduction lowers maximum software amplification → cleaner output is preferred over loud clipped output; system volume remains available.

## Migration Plan

1. Add OpenSpec requirements and tasks.
2. Run a focused baseline `aspen3` Nix evaluation before configuration edits.
3. Apply the machine-scoped PipeWire/WirePlumber, packages, and MPV override.
4. Format changed Nix files.
5. Re-run focused `aspen3` evaluation and OpenSpec status checks.
6. Deploy normally when ready; rollback is the previous NixOS generation or reverting the machine configuration change.

## Open Questions

- Which physical headphones/speakers should receive a measured EasyEffects preset later?
- Should `aspen3` eventually opt into the existing `pro-audio` tag after runtime `rtcqs` evidence?
