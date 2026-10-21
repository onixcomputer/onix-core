# omp coding agent on britton-desktop and aspen3

Date: 2026-09-15

## Change

`inventory/services/services.ncl` gains an `omp-agents` Clan instance that
reuses the `llm-agents` module and targets `britton-desktop` and `aspen3`
only. The shared `llm-client` role is unchanged, so no other host receives
the agent.

`flake-outputs/_llm-agents-checks.nix` reads the evaluated
`environment.systemPackages` of the two selected machines, of one unselected
`llm-client` machine, and builds the agent entry the selected machine
resolves.

Commits:

- `5957e1e9` inventory scope, focused check, change package;
- `7da08740` compiler pin for the agent's build (see "Compiler pin");
- `42bd27d4` on `add-omp-coding-agent-desktop-final`: the same inventory
  scope and check on the state `britton-desktop` actually runs, plus the
  agent-revision pin the machine's lock already selects.

## Compiler pin

The `llm-agents` agent package writes the compiled agent into the bun 1.3.14
runtime template it pins, using the consumer's `bun` and the bun2nix build
hook. nixpkgs moved `bun` to 1.4.2 on 2026-09-13. With that compiler the
template's embedded prelude is written empty and the agent fails its own
smoke test:

```text
Running phase: installCheckPhase
[Uncaught Exception] SyntaxError: Invalid character: '\0'
    at <parse> (/$bunfs/root/prelude-e649jhs8.txt:1)
```

The failure reproduced locally, so it was not a builder fault. A build with
nixpkgs `bun` 1.3.13 passed the same check, and pinning only the package's
`bun` argument was not enough: the failure continued until the bun2nix hook
was rebuilt against the pinned bun as well.

`multiverse.lock` now pins `bun` 1.3.13
(`eaad089433ca2bb662274377d33df3d0e51ef28b`), and `modules/llm-agents`
compiles that one agent with it. Both machines keep their nixpkgs pins.

## Static evidence

- Service contract validation: `cairn validate` returned `valid: true`, and
  the proposal, design, and tasks gates passed.
- Focused package-list check report:

```text
britton-desktop.omp=present
britton-desktop.omp-bogus=absent
aspen3.omp=present
aspen3.omp-bogus=absent
aspen1.omp=absent
```

- The selected package is the pinned input's package: the evaluated
  `omp` entry on both machines was `omp-18.1.19` from
  `inputs.llm-agents.packages.x86_64-linux.omp`.
- The agent builds and passes its own smoke test on both machine pins
  (aspen3 pin `26.11.20260913.02f5696`, desktop pin
  `26.11.20260908.e9b9cbe`); each build reported `smoke-test: ok`.

## Deployment

Both systems were built first and compared against the running system before
activation.

`aspen3`: `/nix/store/ynn8xvpdw17cln9q8413mbgcwb90pnga-nixos-system-aspen3-26.11.20260913.02f5696`
→ `/nix/store/cksnpv3k312llj8k8j6y0ar54mf0462f-nixos-system-aspen3-26.11.20260913.02f5696`.
Closure difference:

```text
bun: ∅ → 1.3.13, 96.3 MiB
omp: ∅ → 18.1.19, 298.2 MiB
```

`britton-desktop`: `/nix/store/jwp2daqfs5rdx46a3k5wb6ka889ihkwc-nixos-system-britton-desktop-26.11.20260908.e9b9cbe`
→ `/nix/store/1gnzz2ki156cmphygjj7pk1mp8p837w2-nixos-system-britton-desktop-26.11.20260908.e9b9cbe`.
Closure difference: the agent package added, and the agent CLI set moved to
the revision the working tree's lock already selects (`claude-code`
2.1.263 → 2.1.270, `openspec` 1.12.0 → 1.13.0, `hermes-agent`
2026.8.31 → 2026.9.11). No package was removed.

The first desktop candidate tree was rejected before activation: it would
have removed `ssh-clipboard`, because that machine runs the ssh-clipboard
lineage rather than the branch point the change was written against.

## Runtime result

Both hosts report the agent on `PATH` and pass its self-check:

- `britton-desktop`: `/nix/store/rzgzl89hy57lzl31l36fjakhcbk43vqr-omp-18.1.19`,
  `omp/18.1.19`, `smoke-test: ok`; generation 855, no failed units.
- `aspen3`: `/nix/store/99bpqw0xvbb32fyh4jrb365snzyji936-omp-18.1.19`,
  `omp/18.1.19`, `smoke-test: ok`; generation 90.

The two machines resolve different builds of the same agent version, because
each build is bound to its own machine pin.

## Unrelated observation: aspen3 storage

`rustfs.service` and `kache-rustfs.service` on `aspen3` are in a restart
loop and `celld-site-storage-provision.service` fails. The cause is the
USB4 NVMe enclosure: the kernel reports `device offline error, dev sda`
with `Synchronize Cache(10) failed: Result: hostbyte=DID_ERROR`, ext4
reports `error -5 reading directory block`, writes to `/mnt/usb4-nvme`
fail, and `/dev/sda` is gone from the block device list. RustFS had already
returned HTTP 500 responses from that storage at 12:20, before this
deployment.

This deployment did not touch those units; its closure added only the agent
and the pinned compiler. Recovering the device needs a physical
intervention.

## Limits

This evidence proves the agent is installed, runs its self-check, and
resolves on `PATH` on the two hosts. It does not prove agent correctness,
model access, credential configuration, or that any other machine is
unaffected beyond the checked package lists. The desktop was deployed from
a tree reconstructed from its lineage, not from the exact dirty state the
machine was last activated with; the closure comparison bounds that
difference to the agent packages.
