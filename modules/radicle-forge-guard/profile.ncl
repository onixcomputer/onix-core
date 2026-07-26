# r[impl onix.radicle_ci.canonical_guard.core]
# r[impl onix.radicle_ci.canonical_guard.authority]
let Contracts = import "contracts.ncl" in
Contracts.expected | Contracts.PolicyShape | Contracts.GuardPolicy
