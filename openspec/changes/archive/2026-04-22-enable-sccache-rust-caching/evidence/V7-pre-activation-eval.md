Evidence-ID: V7-pre-activation-eval
Task-ID: V7
Artifact-Type: verification-evidence
Covers: rustcache.managed-config.first-activation

## Commands

```bash
nix eval --impure --json --option allow-import-from-derivation true --expr \
  'let flake = builtins.getFlake (toString ./.) ; cfg = flake.nixosConfigurations.britton-desktop.config.home-manager.users.brittonr; in cfg.home.activation.backupCargoConfigBeforeTakeover.before'
```

Output:

```json
["checkLinkTargets"]
```

```bash
nix eval --impure --raw --option allow-import-from-derivation true --expr \
  'let flake = builtins.getFlake (toString ./.) ; cfg = flake.nixosConfigurations.britton-desktop.config.home-manager.users.brittonr; in cfg.home.activation.backupCargoConfigBeforeTakeover.data'
```

Output:

```sh
cargo_dir="$HOME/.cargo"
cargo_config="$cargo_dir/config.toml"
backup_config="$cargo_dir/config.toml.pre-sccache"
cargo_config_is_store_symlink=0

if [ -L "$cargo_config" ]; then
  cargo_target="$(readlink "$cargo_config")"
  case "$cargo_target" in
    /nix/store/*)
      cargo_config_is_store_symlink=1
      ;;
  esac
fi

if [ "$cargo_config_is_store_symlink" -ne 1 ] && [ -e "$cargo_config" ]; then
  if [ -e "$backup_config" ]; then
    echo "Refusing to take over $cargo_config: backup $backup_config already exists." >&2
    exit 1
  fi

  mkdir -p "$cargo_dir"
  cp "$cargo_config" "$backup_config"
  rm -f "$cargo_config"
fi
```

## Result

PASS. Pre-activation evaluation shows the takeover step runs before `checkLinkTargets`, copies an existing manual `~/.cargo/config.toml` to `~/.cargo/config.toml.pre-sccache`, removes the original path before Home Manager links the managed file, and fails closed if the backup already exists.
