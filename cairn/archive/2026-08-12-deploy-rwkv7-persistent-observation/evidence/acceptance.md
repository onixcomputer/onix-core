# Acceptance evidence

## Deployment

The exact `britton-desktop` system build passed and produced:

`/nix/store/9sz5xr2hyp5fsivyi633jd5b15xs37m9-nixos-system-britton-desktop-26.11.20260803.104240a`

The closure contains `rwkv7-p150x2-runtime-0.1.0` and `rwkv7-p150x2-evidence-0.1.0`. Activation used that exact path through its `bin/switch-to-configuration` command.

The active system provides these stable commands:

- `/run/current-system/sw/bin/rwkv7-p150x2-runtime`
- `/run/current-system/sw/bin/rwkv7-p150x2-persistent-decode-monitor`

The installed profile is `rwkv7-p150x2-persistent-decode-v2`. Its BLAKE3 is `e41319204ddf36bda088afb8a4d55a367dc163951ea29c45738e3b11b815819a`. It is physically admitted and lists only windows `2` and `4`.

## Physical observation

Both competing inference services were inactive before the accepted observation. Devices `/dev/tenstorrent/0` and `/dev/tenstorrent/1` had no open owner.

One bounded, synchronized production-selected observation used window `2` on device `0` and window `4` on device `1`. It produced two explicit regular worker receipts. Their ordered BLAKE3 values are:

1. `b6a7cd7194ce837009a33dacca1fd52ae77aa9e6ab1f835bd5b156c2cad32751`
2. `4b34c4d53715a1d7bbb5fc409bd8a7fc1f8e5d29f2753dca5caab84a3ea4f7b3`

The installed monitor classified only those two ordered files. It returned status `0`, verdict `clean`, and recommendation `retain`.

The aggregate receipt reports:

- two accepted persistent events;
- one selected window-`2` event and one selected window-`4` event;
- eight completed requests;
- exact parity for both events;
- complete cleanup for both events;
- no normal dispatch, fallback, timeout, terminal failure, warning, or critical alert.

The retained monitoring receipt BLAKE3 is `cb4a322b41de5dbe0ee11a345c8f49b1e923692f4592ee56528ab707f6817be0`. Its source batch BLAKE3 is `6d4d5e7bf48e9c16898838bfbbdd0c1908c3be5f8b326f1b74f7f2a2296108b6`.

Three bounded launch-preparation attempts produced no worker receipt. They exposed a fresh profiler-cache setup bound, one missing required profiler path, and an incorrect barrier file type. Each attempt closed both devices. The accepted observation used explicit writable profiler paths, warmed immutable kernel caches, and directory barriers.

## Restoration

After classification, both competing services were stopped and reset to `inactive`. Both device nodes had no open owner.

This deployment installs operator tools only. It does not create a daemon, route live traffic, mutate admission, enable window `8`, or authorize a larger-window evaluation.
