# Cairn quickstart

This repo uses native Cairn lifecycle artifacts under `cairn/`; do not create or update OpenSpec artifacts for normal change work. Validate with the local Cairn source policy bundle from `/home/brittonr/git/cairn`, which should authenticate to the canonical project `https://github.com/OnixResearch/cairn` via SSH remote `git@github.com:OnixResearch/cairn.git`.

```bash
CAIRN_SOURCE=/home/brittonr/git/cairn
CAIRN_POLICY="$CAIRN_SOURCE/cairn-policy/generated/cairn-policy.json"

nix run path:$CAIRN_SOURCE#cairn -- validate --root . --policy "$CAIRN_POLICY"
nix run path:$CAIRN_SOURCE#cairn -- gate proposal run-krea2-on-aspen3 --root . --policy "$CAIRN_POLICY"
nix run path:$CAIRN_SOURCE#cairn -- gate design run-krea2-on-aspen3 --root . --policy "$CAIRN_POLICY"
nix run path:$CAIRN_SOURCE#cairn -- gate tasks run-krea2-on-aspen3 --root . --policy "$CAIRN_POLICY"
```
