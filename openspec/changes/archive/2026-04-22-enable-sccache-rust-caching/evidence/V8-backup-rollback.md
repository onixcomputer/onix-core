Evidence-ID: V8-backup-rollback
Task-ID: V8
Artifact-Type: verification-evidence
Covers: rustcache.managed-config.first-activation

## Verified Sequence

1. Activated a rollback variant of the Home Manager config with the `sccache` profile removed from `hm-desktop`.
2. Confirmed the managed `~/.cargo/config.toml` disappeared while `~/.cargo/config.toml.pre-sccache` remained.
3. Restored the saved manual Cargo config by copying `~/.cargo/config.toml.pre-sccache` back to `~/.cargo/config.toml` and verified the restored file matched the backup byte-for-byte.
4. Rebuilt the normal `sccache` profile and attempted to activate it again while both the restored manual `~/.cargo/config.toml` and `~/.cargo/config.toml.pre-sccache` existed.
5. Confirmed activation failed closed with the expected backup-collision message.
6. Removed the restored manual `~/.cargo/config.toml` and re-activated the normal `sccache` profile to return the workstation to the managed state.

## Key Output

Rollback activation removed the managed Cargo config while preserving the backup:

```text
CONFIG_EXISTS=0
-rw-r--r-- 1 brittonr brittonr 602 Apr 22 13:16 /home/brittonr/.cargo/config.toml.pre-sccache
RESTORED_BACKUP_MATCH=1
-rw-r--r-- 1 brittonr brittonr 602 Apr 22 14:20 /home/brittonr/.cargo/config.toml
-rw-r--r-- 1 brittonr brittonr 602 Apr 22 13:16 /home/brittonr/.cargo/config.toml.pre-sccache
```

Re-enabling `sccache` while both files existed failed closed:

```text
Starting Home Manager activation
Activating backupCargoConfigBeforeTakeover
Refusing to take over /home/brittonr/.cargo/config.toml: backup /home/brittonr/.cargo/config.toml.pre-sccache already exists.
FAIL_CLOSED_STATUS=1
```

Final re-activation returned the workstation to the managed state:

```text
lrwxrwxrwx 1 brittonr brittonr  81 Apr 22 14:21 /home/brittonr/.cargo/config.toml -> /nix/store/v71s6hbw8p3x4w9f3nvrffk6wv1z72k0-home-manager-files/.cargo/config.toml
-rw-r--r-- 1 brittonr brittonr 602 Apr 22 13:16 /home/brittonr/.cargo/config.toml.pre-sccache
lrwxrwxrwx 1 brittonr brittonr  85 Apr 22 14:21 /home/brittonr/.config/sccache/config -> /nix/store/v71s6hbw8p3x4w9f3nvrffk6wv1z72k0-home-manager-files/.config/sccache/config
lrwxrwxrwx 1 brittonr brittonr  81 Apr 22 14:21 /home/brittonr/.local/bin/sccache -> /nix/store/v71s6hbw8p3x4w9f3nvrffk6wv1z72k0-home-manager-files/.local/bin/sccache
```

## Result

PASS. The first-activation backup artifact remained available, manual rollback restored the saved Cargo file successfully, backup-collision handling failed closed exactly as designed, and the workstation was returned to the managed `sccache` profile after the check.
