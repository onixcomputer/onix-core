# onix-core Cairn lifecycle

This directory contains native Cairn lifecycle artifacts for planned `onix-core` changes.

- `specs/`: accepted specifications
- `changes/`: active change packages
- `archive/`: completed change archives

Use the local Cairn source checkout for validation:

```sh
nix run path:/home/brittonr/git/cairn#cairn -- validate \
  --root /home/brittonr/git/onix-core \
  --policy /home/brittonr/git/cairn/cairn-policy/generated/cairn-policy.json
```
