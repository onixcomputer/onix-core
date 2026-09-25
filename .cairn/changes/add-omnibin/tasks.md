## Phase 1: Implementation

- [x] [serial] Add the `omnibin` flake input following the repository `nixpkgs`, adding only its lock node. r[onix.omnibin.source]
- [x] [serial] Add and register the `omnibin` tag, install both packages without the input's NixOS module, and assign the tag to `britton-desktop`. r[onix.omnibin.scope] r[onix.omnibin.namespace]

## Phase 2: Verification

- [x] [serial] Evaluate the package lists of `britton-desktop` and `aspen3`, confirm no `omnibin` service exists, and run the tag registry check. r[onix.omnibin.scope.selected] r[onix.omnibin.scope.unselected] r[onix.omnibin.namespace.no_service]
- [x] [serial] Build both packages, resolve a name from the index, and run a binary absent from the host store through `omnibin-shell`. r[onix.omnibin.verification]

## Phase 3: Deployment

- [ ] [serial] Deploy `britton-desktop` from its deployed lineage after comparing closures with the running system. r[onix.omnibin.deployment]
- [ ] [serial] Resolve both commands on the target, repeat the shell run there, and record the evidence. r[onix.omnibin.deployment.path] r[onix.omnibin.namespace.host_store]
