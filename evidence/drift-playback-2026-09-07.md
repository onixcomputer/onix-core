# Drift playback verification — 2026-09-07

## Initial result, before repairs

The first tested Drift playback path failed. The earlier RustFS storage checks did not prove music playback.

## Deployed application

The probe drove the installed Drift TUI through a pseudo-terminal. It searched for `Miles Davis So What` and selected a YouTube result.

- Search returned real YouTube results.
- MPD rejected the selected Google Video audio URL with HTTP 403.
- No successful playback followed that selection.
- The application reported that it found no Tidal credentials and entered demo mode.

The signed audio URL is omitted from this receipt. The terminal transcript remains private under `/tmp/`.

## Independent positive control

MPD streamed the public SoundHelix music file at `https://www.soundhelix.com/examples/mp3/SoundHelix-Song-1.mp3`.

- Playback advanced from 00:02 to 00:09.
- A six-second capture from `auto_null.monitor` contained non-silent audio.
- FFmpeg reported mean volume of -17.3 dB and peak volume of -0.6 dB.

This control proves network retrieval, MPD decoding, and digital output for that MP3 stream. It bypasses Drift and does not prove RustFS-backed playback or the YouTube resolver.

## Physical output blocker

PipeWire exposes only `Dummy Output`. The saved default references a USB Focusrite interface that is absent from the current device list. Both onboard audio cards have inactive profiles and unavailable output ports.

No physical speaker or headphone output was verified. The probe did not change device profiles.

## Cleanup

MPD is stopped with an empty queue. The volume is back at its original 100 percent. Repeat, random, single, and consume settings remain unchanged. Drift's persisted queue contains no tracks. No probe TUI process remains.

## Verified repairs and final deployment

The final build is active and is the boot default:

`/nix/store/ww6xrbvk54nxxm7ngy454rkg7wl2nkcy-nixos-system-britton-desktop-26.11.20260819.afe3d8a`

Published Drift revision: `bb8c23f97c37bb48775d96699a2a1b8dbe26f8be`.

Three software corrections passed verification:

- `f7a5c45` loads legacy `tidal-tui` credentials. Token refresh succeeded. New token files use private, atomic replacement.
- The Drift wrappers pin yt-dlp `2026.08.19`, revision `3a08beaf031ab68f966401ead017ac81fe8486cf`. The July extractor failed the same track with HTTP 403.
- `bb8c23f` makes single-track actions use the displayed provider-filtered index. Previously, the display and playback could select different tracks.

Both Cargo feature matrices and Nix checks passed. New tests cover credential discovery, account precedence, malformed files, private replacement, and valid and invalid filtered selections.

Final probes drove the installed Drift TUI without a PATH override. They selected explicit provider filters and rejected a media origin from the wrong provider.

| Provider | Media origin | Playback progress | Mean signal | Peak signal |
| --- | --- | --- | --- | --- |
| YouTube | `rr5---sn-8xgp1vo-ab5l.googlevideo.com` | 00:08 to 00:13 | -66.0 dB | -48.1 dB |
| Tidal | `lgf.audio.tidal.com` | 00:10 to 00:16 | -55.3 dB | -43.3 dB |

Both probes produced non-silent PCM at MPD volume 20 percent. The queue and volume were restored afterward. The eight RustFS checks also passed after the final switch. RustFS, MPD, the model service, and Drift storage provisioning remained active.

**Remaining limitation:** only Dummy Output is available. These results prove software playback, not audible output from physical speakers or headphones. No audio-device profile changed.
