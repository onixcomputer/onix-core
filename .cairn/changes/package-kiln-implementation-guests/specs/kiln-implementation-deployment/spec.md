# Kiln implementation deployment

## ADDED Requirements

### Requirement: Separate opt-in authority
r[onix.kiln_implementation.authority]
The composition MUST be disabled by default, admit only explicit repositories/work classes, bound effects and preserve separate Kiln, Lattice, Cairn and publisher state and credentials. Worker execution MUST NOT access trusted verification/policy state or publisher credentials. Restart MUST reconcile durable claims and possible effects before redispatch.

#### Scenario: Ambiguous external effect
- GIVEN a durable claim and a provider operation whose outcome is not acknowledged
- WHEN service loss follows possible dispatch or publication
- THEN retained state remains unknown until provider observation resolves it without duplicate execution or publication.

### Requirement: Exact guest cohort and retention
r[onix.kiln_implementation.guest]
The worker package MUST bind kernel/initrd/root/runtime/tools, actual VMM executable, launch configuration and memory settings. Mutable workspace, Nix state and execution database MUST remain separate. Both placement hosts MUST retain immutable closures while live/checkpoint references remain. Per-execution credentials and identity MUST NOT enter reusable artifacts.

#### Scenario: Wrong destination cohort
- GIVEN an admitted immutable environment and source placement
- WHEN destination VMM bytes, launch profile or staged closure differ
- THEN admission fails before dispatch or restore.

### Requirement: Evidence scopes
r[onix.kiln_implementation.qualification]
Qualification MUST distinguish device-free fixtures, real worker, KVM boot/restore/migration, cross-host serving and advanced policy profiles. Unsupported or absent prerequisites MUST NOT report qualified status.

#### Scenario: Missing KVM
- GIVEN an explicitly selected KVM qualification profile
- WHEN the selected platform cannot access KVM
- THEN qualification reports unsupported, not a successful runtime test.

### Requirement: Scripted end-to-end VM qualification
r[onix.kiln_implementation.scripted_vm]
The scripted qualification MUST boot the actual opt-in NixOS service module in an isolated VM using a strict immutable Kiln/Lattice/Cairn/OMP cohort, typed configuration, canonical CI profile and exact attempt bundle. Before any service stage, the test MUST validate the cohort manifest's actual executable paths and hashes and require the native intake, dispatch, attempt, verification and publication CLI capabilities. Missing or mismatched inputs MUST fail the check; they MUST NOT be replaced with empty directories, no-op tools, old canary pins, moving sibling sources or synthetic source/cohort/accepted-checker identities. Scripted model and GitHub-provider fixtures MAY supply deterministic external responses only inside the VM and MUST remain explicitly labeled; production source identity, claim, candidate acceptance and canonical check evidence MUST come from the actual consumers. The test MUST exercise intake, one durable current claim, isolated candidate mutation, independent capture/checks, canonical CI acceptance, a review artifact, UID/mount/credential separation, duplicate/restart, cancellation/stale fencing, source/target movement and recovery after an external effect before acknowledgement without duplicate dispatch or PR. This evidence MUST remain distinct from live-worker and retained-guest/cross-host qualification.

#### Scenario: Required immutable component is absent
- GIVEN any required cohort executable, profile, canonical CI authority or attempt bundle is absent or fails its exact identity check
- WHEN the scripted VM check is selected
- THEN the check fails explicitly before reporting qualification or substituting a fixture for an owner component.

#### Scenario: Scripted provider response is mistaken for production authority
- GIVEN the VM uses a declared scripted model or local GitHub fixture
- WHEN the actual consumers record candidate, canonical verification or publication state
- THEN evidence is labeled scripted, source/cohort/accepted-checker identity remains bound to the actual pinned consumers, and no live-worker or host/guest qualification is claimed.
