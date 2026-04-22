Evidence-ID: V4-cargo-defaults
Task-ID: V4
Artifact-Type: verification-evidence
Covers: rustcache.shared-target-compat.managed-cargo-file,rustcache.managed-config.file-ownership,rustcache.local-only.config-inspection

## Commands

```bash
ls -l ~/.cargo/config.toml ~/.cargo/config.toml.pre-sccache ~/.config/sccache/config ~/.local/bin/sccache
```

Output:

```text
lrwxrwxrwx 1 brittonr brittonr  81 Apr 22 14:21 /home/brittonr/.cargo/config.toml -> /nix/store/v71s6hbw8p3x4w9f3nvrffk6wv1z72k0-home-manager-files/.cargo/config.toml
-rw-r--r-- 1 brittonr brittonr 602 Apr 22 13:16 /home/brittonr/.cargo/config.toml.pre-sccache
lrwxrwxrwx 1 brittonr brittonr  85 Apr 22 14:21 /home/brittonr/.config/sccache/config -> /nix/store/v71s6hbw8p3x4w9f3nvrffk6wv1z72k0-home-manager-files/.config/sccache/config
lrwxrwxrwx 1 brittonr brittonr  81 Apr 22 14:21 /home/brittonr/.local/bin/sccache -> /nix/store/v71s6hbw8p3x4w9f3nvrffk6wv1z72k0-home-manager-files/.local/bin/sccache
```

```bash
cat ~/.cargo/config.toml
cat ~/.config/sccache/config
```

Output:

```toml
[build]
rustc-wrapper = "/nix/store/iiypmm1ak839mj4gjcza0zl4ppims8if-cargo-rustc-sccache-wrapper/bin/cargo-rustc-sccache-wrapper"
target-dir = "/home/brittonr/.cargo-target"

[net]
retry = 3

[term]
quiet = false
```

```toml
basedirs = ["/home/brittonr/git", "/home/brittonr/git/worktrees"]

[cache.disk]
dir = "/home/brittonr/.cache/sccache"
size = 34359738368
```

## Result

PASS. Both activated config paths are Home Manager-managed symlinks into the current generation, the Cargo file preserves `target-dir`, `retry = 3`, and `quiet = false` while pointing at the managed rustc-wrapper, and the activated `sccache` config remains generation-managed with the expected local-only constants (`dir`, `size`, and `basedirs`) and no remote/distributed backend sections. The activated `size = 34359738368` value is the serialized byte representation of the configured 32 GiB cache budget.
