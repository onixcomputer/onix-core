# Migration Plan: Upstream clan.lol + Roster Removal

## Status: DRAFT

## Problem

The project uses a forked `adeci/clan-core` (ref `adeci-unstable`, pinned Nov 2025) which is ~5 months behind upstream `clan/clan-core` (main). The fork adds a custom `roster` module that bundles user management, position-based access control, home-manager profile wiring, and password generation into one monolithic service instance. This creates:

- **Fork maintenance burden** — upstream improvements, bugfixes, and new module features (e.g. the March 2026 `openssh.authorizedKeys.keys` addition to `users`) require cherry-picking or rebasing.
- **Tight coupling** — roster welds user creation, SSH keys, shells, groups, passwords, and home-manager profiles into a single opaque abstraction. Changes to any one concern require understanding the whole.
- **darwin incompatibility** — roster requires the `all` tag which imports NixOS-specific modules (boot, systemd, nftables), blocking `britton-air` from roster-managed home-manager.

## Goal

Switch to upstream `clan/clan-core` (main) and decompose roster's responsibilities into standard upstream modules + thin local modules.

---

## Inventory of Roster Responsibilities

What roster currently does, and where each concern goes after migration:

| Concern | Roster handles | Replacement |
|---|---|---|
| User creation (isNormalUser, UID, groups) | `users` attrset + `machines` per-machine overrides | **Local NixOS module** via importer tag |
| SSH authorized keys (user + root) | `sshAuthorizedKeys` in user defs | **Upstream `users` module** (authorizedKeys, March 2026) OR local module |
| Shell configuration | `defaultShell` + per-machine override | **Local NixOS module** |
| Password generation (xkcdpass + mkpasswd) | `positionDefinitions.*.generatePassword` via clan vars | **Upstream `users` module** (built-in) |
| Position-based permissions (owner/admin/basic/service) | `positionDefinitions` | **Flatten to NixOS groups** (wheel for sudo) |
| `users.mutableUsers = false` | `perMachine.nixosModule` | **Upstream `users` module** (built-in) |
| Home-manager import + profile selection | `homeManager.enable/profiles` + `homeProfilesPath` | **Local home-manager module** via importer tag |
| Root SSH keys from owner-position users | Automatic in `getRootAuthorizedKeys` | **Upstream `admin` module** OR local module |
| Per-machine HM sharedModules (e.g. bonsai monitors) | `homeManagerOptions.sharedModules` | **Per-machine extraModules** or machine config |

---

## Architecture After Migration

```
inventory/
├── core/
│   ├── machines.nix          # unchanged
│   ├── users.nix             # NEW — upstream users instances (password gen)
│   └── default.nix           # updated — drops roster, adds users
├── services/                  # unchanged
├── tags/
│   ├── all.nix               # unchanged (NixOS base config)
│   └── ...                   # unchanged
├── home-profiles/             # unchanged (136 nix files stay as-is)
└── home-manager.nix          # NEW — wires home-manager via importer
```

```
modules/
├── user-config/              # NEW — local NixOS module (users, shells, SSH keys)
│   └── default.nix
└── ...                       # existing modules unchanged
```

---

## Phases

### Phase 0: Preparation (non-breaking)

**Goal:** Set up the replacement pieces alongside roster before cutting over.

- [ ] **0a.** Create `modules/user-config/default.nix` — a local clan service or plain NixOS module that declares `users.users.brittonr` with UID, groups, shell, SSH keys, and `root.openssh.authorizedKeys.keys`. This replaces roster's user-module.nix + position system.
- [ ] **0b.** Create `inventory/home-manager.nix` — wires `home-manager.nixosModules.home-manager` + profile imports. Replaces roster's home-manager.nix. Produces an importer instance tagged per-machine with the right profiles.
- [ ] **0c.** Test both modules can evaluate alongside roster (no conflicts).

### Phase 1: Switch clan-core input

**Goal:** Move from fork to upstream.

- [ ] **1a.** Change `flake.nix` input:
  ```nix
  # Before
  clan-core.url = "git+https://git.clan.lol/adeci/clan-core?ref=adeci-unstable";
  # After
  clan-core.url = "git+https://git.clan.lol/clan/clan-core?ref=main";
  ```
- [ ] **1b.** Run `nix flake update clan-core` to pull latest.
- [ ] **1c.** Verify `sshd`, `importer`, `users`, `admin` modules exist in the new input. The fork's `roster` module will no longer be available.
- [ ] **1d.** Check for any breaking API changes in upstream modules we already use (`sshd`, `garage`, `importer`). Review upstream changelog.
- [ ] **1e.** Audit `module.input` references — services using `module.input = "self"` are fine (local modules). `garage` uses `module.input = "clan-core"` and needs upstream compat check.

### Phase 2: Replace roster with upstream `users` module

**Goal:** Password generation via upstream `users`, user config via local module.

- [ ] **2a.** Create `inventory/core/users.nix`:
  ```nix
  _: {
    instances = {
      user-brittonr = {
        module.name = "users";
        module.input = "clan-core";
        roles.default.tags.all = { };
        roles.default.settings = {
          user = "brittonr";
          prompt = true;
          groups = [
            "wheel"
            "networkmanager"
            "video"
            "audio"
            "input"
            "kvm"
            "docker"
            "dialout"
            "disk"
          ];
        };
      };
    };
  }
  ```
- [ ] **2b.** Create or register `modules/user-config/default.nix` as a clan service (or use importer + extraModules). Defines:
  - `users.users.brittonr.uid = 1555`
  - `users.users.brittonr.shell = pkgs.fish`
  - `users.users.brittonr.openssh.authorizedKeys.keys = [ ... ]`
  - `users.users.root.openssh.authorizedKeys.keys = [ ... ]`
  - `programs.fish.enable = true`
- [ ] **2c.** Wire user-config via inventory (importer tag or register as clan module).
- [ ] **2d.** Delete `inventory/core/roster.nix`.
- [ ] **2e.** Update `inventory/core/default.nix` to import `users.nix` instead of `roster.nix`.

### Phase 3: Migrate password vars

**Goal:** Reuse existing passwords without prompting again.

- [ ] **3a.** Check var naming differences:
  - **Roster format:** `user-password-brittonr/brittonr-password-hash`, `user-password-brittonr/brittonr-password`
  - **Upstream format:** `user-password-brittonr/user-password-hash`, `user-password-brittonr/user-password`
- [ ] **3b.** For each machine with existing password vars, rename files:
  ```bash
  for machine in vars/per-machine/*/user-password-brittonr; do
    cd "$machine"
    mv brittonr-password-hash user-password-hash 2>/dev/null
    mv brittonr-password user-password 2>/dev/null
    cd -
  done
  ```
- [ ] **3c.** Remove any `brittonr-password` prompt files if the upstream module doesn't use that naming.
- [ ] **3d.** Verify `clan vars list <machine>` shows the renamed vars correctly.

### Phase 4: Wire home-manager

**Goal:** Replicate roster's profile-based home-manager setup without roster.

Two approaches evaluated:

**Option A: NixOS-module approach (recommended)** — keeps deploy-time profile application, consistent with current workflow.

- [ ] **4a.** Create a local clan service module `modules/home-manager-profiles/default.nix` (or a plain NixOS module imported via importer) that:
  1. Imports `home-manager.nixosModules.home-manager`
  2. Sets `home-manager.useGlobalPkgs = true`, `useUserPackages = true`, `backupFileExtension = "bak"`
  3. Passes `inputs` via `extraSpecialArgs`
  4. For each user, imports their profile .nix files based on a configured list
- [ ] **4b.** Create per-machine profile assignments. Two sub-options:
  - **(i) Importer instances per machine** — one importer instance per machine that sets the profile list via extraModules. Verbose but explicit.
  - **(ii) Machine-specific config** — each `machines/<name>/configuration.nix` imports its own home-manager profiles. Simplest, no abstraction.
  - **(iii) Tag-based grouping** — create tags like `hm-desktop` that include noctalia+social profiles, `hm-server` for base+dev. Reduces duplication.
- [ ] **4c.** Handle bonsai's per-machine `sharedModules` (monitor config). Move to `machines/bonsai/configuration.nix` or a bonsai-specific importer instance.
- [ ] **4d.** Handle `desktop.nix` dbus-broker preStart that iterates `config.home-manager.users` — this needs home-manager to still be a NixOS module (Option A satisfies this).

**Option B: Standalone home-manager (Mic92-style)** — decouples HM from NixOS deploys. Not recommended because: breaks the desktop.nix dbus-broker integration, requires separate `hm switch` step, loses deploy-time consistency.

### Phase 5: darwin support (britton-air)

**Goal:** Now that roster's `all` tag requirement is gone, wire home-manager for darwin.

- [ ] **5a.** The upstream `users` module's `perMachine.nixosModule` sets `users.mutableUsers = false` — this is NixOS-only. Verify upstream handles darwin machines correctly (skips NixOS-only options).
- [ ] **5b.** Create a darwin-compatible home-manager wiring (nix-darwin's home-manager module or standalone).
- [ ] **5c.** Add `britton-air` to the profile assignment system.

### Phase 6: Cleanup

- [ ] **6a.** Remove `roster` from the fork's clanServices (if maintaining fork) or confirm it's gone with upstream.
- [ ] **6b.** Update `flake.nix` lib exports — `lib.roster.users` references `roster.nix` which no longer exists.
- [ ] **6c.** Update `parts/sops-viz.nix` and analysis tools (`acl`, `vars`, `roster` commands) that reference roster.
- [ ] **6d.** Update `CLAUDE.md` to reflect new user management pattern.
- [ ] **6e.** Update `.agent/napkin.md` with darwin/roster notes.
- [ ] **6f.** Run `validate` and `nix flake check`.
- [ ] **6g.** Build all machines locally: `for m in $(clan machines list); do build $m; done`
- [ ] **6h.** Deploy to a test machine first (utm-vm), verify login, SSH, home-manager activation.

---

## Risk Assessment

| Risk | Impact | Mitigation |
|---|---|---|
| Upstream API breaking changes since Nov 2025 | High — could break existing services | Phase 1d audit; build all machines before deploying |
| Password vars rename breaks authentication | High — locked out of machines | Phase 3 careful rename; test on utm-vm first; keep SOPS-encrypted originals |
| Home-manager profile import paths change | Medium — broken HM activation | Phase 4 reuses existing `home-profiles/` directory structure unchanged |
| desktop.nix dbus-broker hack breaks | Medium — dconf service not found after deploy | Phase 4d ensures HM stays as NixOS module |
| Upstream `users` module missing features roster had | Low — upstream covers core needs | UID, shell, SSH keys go in local module; positions flatten to groups |

## Decision Record

- **Why not keep the fork?** The fork is 5 months stale with no active maintenance upstream. Every upstream bugfix or feature requires manual cherry-picking. The `roster` module is the only reason for the fork.
- **Why not standalone home-manager?** The `desktop.nix` dbus-broker preStart integration iterates `config.home-manager.users`, requiring HM as a NixOS module. Splitting HM into a separate step would break this and lose deploy-time consistency.
- **Why flatten positions to groups?** The position system (owner/admin/basic/service) is only used for one user (brittonr) who is always "owner". The abstraction isn't earning its keep. `wheel` group = sudo access. Service users are defined per-service in their respective modules.
