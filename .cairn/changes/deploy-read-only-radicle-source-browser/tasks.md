## Phase 1: Dependencies and component selection

- [ ] [serial] Record the accepted OnixOS browser contract revision, policy identity, route set, limit profile, and non-claims. r[onix.radicle_source_browser.contract]
- [ ] [serial] Compare licensed published components by source revision, license, views, Git formats, limits, output shape, and authority needs. r[onix.radicle_source_browser.component_selection]
- [ ] [serial] Select one compliant component or record an exact blocker. Reject all Radiant Forge source, template, asset, or test reuse. r[onix.radicle_source_browser.component_selection]
- [ ] [parallel] Add source, license, package, executable, and closure identity checks for the selected renderer. r[onix.radicle_source_browser.component_selection]

## Phase 2: Pure planning and bounded generation

- [ ] [serial] Add pure admission for the OnixOS contract, RID, tagged Git object, source snapshot, renderer, limits, and output profile. r[onix.radicle_source_browser.contract]
- [ ] [serial] Add a pure immutable snapshot and current-pointer publication planner with stale-plan rejection. r[onix.radicle_source_browser.publication]
- [ ] [serial] Add a read-only local Radicle source adapter for one explicit admitted RID and exact object. r[onix.radicle_source_browser.source_boundary]
- [ ] [serial] Run the selected renderer through Bounded Exec with explicit argv, environment, working directory, deadline, capture, and teardown. r[onix.radicle_source_browser.generation]
- [ ] [serial] Admit generated output through Bounded Tree with path, type, member, depth, file-size, and total-size limits. r[onix.radicle_source_browser.generation]
- [ ] [serial] Emit one deterministic generation receipt and immutable snapshot manifest. r[onix.radicle_source_browser.evidence]

## Phase 3: Publication and serving

- [ ] [serial] Publish the immutable admitted snapshot before publishing its current pointer. r[onix.radicle_source_browser.publication]
- [ ] [serial] Add exact default-deny Nginx browser routes without changing upload-pack or receive-pack behavior. r[onix.radicle_source_browser.exposure]
- [ ] [serial] Add public probes for summary, refs, tree, blob, raw, commit, diff, line anchors, exact-object links, and security headers. r[onix.radicle_source_browser.exposure]
- [ ] [serial] Add monitoring, retention, rollback, cleanup, and pointer-recovery operations. r[onix.radicle_source_browser.operations]
- [ ] [serial] Emit one redaction-safe deployment receipt linked to the OnixOS contract and generation receipt. r[onix.radicle_source_browser.evidence]

## Phase 4: Positive and negative verification

- [ ] [parallel] Add positive tests for exact source selection, bounded generation, tree admission, publication, serving, and rollback. r[onix.radicle_source_browser.generation]
- [ ] [parallel] Add negative tests for unknown or private RIDs, missing objects, source or renderer drift, unsafe paths, and copied reference material. r[onix.radicle_source_browser.source_boundary]
- [ ] [parallel] Add timeout, signal, truncation, oversized tree, excessive history, stale plan, incomplete publication, and pointer-drift tests. r[onix.radicle_source_browser.publication]
- [ ] [parallel] Probe root enumeration, receive-pack, mutation methods, undeclared routes, local path leakage, and client-script absence. r[onix.radicle_source_browser.exposure]

## Phase 5: Live pilot and closeout

- [ ] [serial] Deploy the browser disabled, validate the closure, then enable one exact admitted public RID. r[onix.radicle_source_browser.operations]
- [ ] [serial] Capture exact positive and negative HTTPS observations, monitoring state, rollback, and cleanup evidence. r[onix.radicle_source_browser.evidence]
- [ ] [serial] Document component provenance, publication, operations, incidents, rollback, retention, license boundary, and non-claims. r[onix.radicle_source_browser.operations]
- [ ] [serial] Run focused package, Nickel, Nix, renderer, publication, route, Cairn, selected-machine, and flake validation. r[onix.radicle_source_browser.evidence]
- [ ] [serial] Run all Cairn gates. Sync and archive only after the OnixOS contract and live negative probes are accepted. r[onix.radicle_source_browser.contract]
