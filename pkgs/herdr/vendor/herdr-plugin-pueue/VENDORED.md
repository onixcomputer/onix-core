# Vendored source

Source: `../herdr-plugin-pueue`

Commit: `29b2ba060297ec15909e06ef1311200c17965cbe`

Reason: The source repository has no remote. The Herdr wrapper needs a portable and fixed Nix build input.

Update procedure:

1. Make sure that the source checkout is clean.
2. Record the new commit in this file and `inventory/home-profiles/brittonr/herdr/lib/config.ncl`.
3. Replace `Cargo.lock`, `Cargo.toml`, `herdr-plugin.toml`, `crates/`, and `fixtures/`.
4. Run the Pueue plugin tests and the Herdr wrapper checks.
