## Policy

- [x] [serial] r[onix.campaign_source.policy] Record the node and replica policy baselines.
- [x] [serial] r[onix.campaign_source.policy] Add Campaign to the shared public source list without changing other scope.
- [x] [parallel] r[onix.campaign_source.policy] Add positive and negative checks over the actual inventory.

## Deployment

- [x] [serial] r[onix.campaign_source.deployment] Prevent the formatter from escaping a linked worktree and test parent preservation.

- [x] [serial] r[onix.campaign_source.deployment] Inspect current host state and record blocking differences.
- [x] [serial] r[onix.campaign_source.deployment] Repair the existing Statix attribute-grouping errors without changing service values or disabling hooks.
- [x] [parallel] r[onix.campaign_source.policy] Review the selected Radicle package identity before changing the version gate.
- [ ] [depends:onix.campaign_source.policy] r[onix.campaign_source.deployment] Pass the existing policy gates and deploy through the reviewed host path.
- [ ] [depends:onix.campaign_source.deployment] r[onix.campaign_source.deployment] Verify service reconciliation and unchanged node identities.

## Acquisition and closure

- [ ] [depends:onix.campaign_source.deployment] r[onix.campaign_source.acquisition] Verify native replication and fresh exact-revision HTTPS acquisition.
- [ ] [parallel] r[onix.campaign_source.acquisition] Verify unknown-repository and write-route rejection.
- [ ] [serial] r[onix.campaign_source.acquisition] Record bounded evidence, sync accepted requirements, and archive only after acceptance.
