## Why

Aspen1 and `britton-desktop` seed the governed Radicle repository set. `aspen3` is another managed machine with a distinct ZFS pool and an active tailnet connection. A third native seed reduces dependence on either current machine without adding public ingress or repository governance authority.

## What Changes

- Generalize the reviewed replica policy from one fixed desktop host to an exact host matrix for `britton-desktop` and `aspen3`.
- Add `aspen3` as a native-only Radicle replica with its own machine key, exact repository policy, tailnet listener, monitoring, and bounded ZFS state.
- Add positive and negative checks for the selected host facts and distinct replica identities.
- Add the new node DID to the non-secret private pilot privacy set, then converge all three seed stores.
- Deploy the service and record redaction-safe live evidence without changing the public HTTPS origin.

## Impact

- **Files**: replica validation and checks, Nickel service inventory, `aspen3` storage, Cairn specifications, operator documentation, and deployment evidence.
- **Testing**: focused replica checks, `aspen3` system evaluation and build, Cairn gates, live service checks, policy reconciliation, and negative exposure checks.
- **Security**: `aspen3` receives only its machine-scoped Radicle node key and repository storage.
- **Non-goals**: no second HTTPS origin, automatic failover, geographic independence, new repository admission, or repository governance authority.
