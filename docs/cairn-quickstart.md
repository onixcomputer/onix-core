# Cairn quickstart

This repo uses native Cairn lifecycle artifacts under `cairn/` and validates with the local Cairn source policy bundle.

```bash
CAIRN_SOURCE=/home/brittonr/git/cairn
CAIRN_POLICY="$CAIRN_SOURCE/cairn-policy/generated/cairn-policy.json"

nix run path:$CAIRN_SOURCE#cairn -- validate --root . --policy "$CAIRN_POLICY"
nix run path:$CAIRN_SOURCE#cairn -- gate proposal run-krea2-on-aspen3 --root . --policy "$CAIRN_POLICY"
nix run path:$CAIRN_SOURCE#cairn -- gate design run-krea2-on-aspen3 --root . --policy "$CAIRN_POLICY"
nix run path:$CAIRN_SOURCE#cairn -- gate tasks run-krea2-on-aspen3 --root . --policy "$CAIRN_POLICY"
```
