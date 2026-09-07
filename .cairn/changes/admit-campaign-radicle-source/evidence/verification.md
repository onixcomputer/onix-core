# Campaign admission checkpoint

## Status

The source admission is implemented and passes its focused checks. Deployment is blocked.
No host switch, runtime override, seed-policy mutation, source acquisition, or lifecycle archive occurred.

## Source and authority

- Infrastructure base: `0c9f1eba1693d27c8b967381ba0e237247b4cd38` from fresh `origin/main`.
- Branch: `cairn/admit-campaign-source-20260906`.
- Campaign RID: `rad:z2scC9MCm3pxk9mX4FEidRKabQ5LN`.
- Selected consumer source: `e23e3edf1dc6a8c612a4ea33a3b805bda1173e3b`.
- The user authorized admission and infrastructure deployment. That authority does not permit removal of unrelated live services.

## Checks

| Check | Observation |
| --- | --- |
| Original node-policy check | Failed before implementation: reviewed version `1.9.1` differs from selected package `1.10.1`. |
| Original replica check | Passed against an immutable archive of the infrastructure base. |
| Campaign source-scope check | Passed against actual Nickel inventory and actual node/replica validation functions. |
| Negative source-scope cases | Rejected all 21 seed mutations and seven route/CI mutations. The actual module validators also rejected all 25 seed/HTTPS mutations. |
| Updated replica check | Passed. |
| Updated node-policy check | Still failed at the unchanged reviewed-version gate. Later assertions in that gate are not acceptance evidence. |
| Cairn proposal/design/tasks | Passed with the current explicit Cairn policy. |
| Deployment preflight | Rejected because the candidate disables live unrelated services. |

The source-scope check returns `/nix/store/szdf6n1siq7r04yqhns2qq7xba1v940a-radicle-campaign-source-scope`.
The updated replica check returns `/nix/store/s1rw85p5lngybj2w8dqbcm9aqy5h3fnm-radicle-seed-replica-check`.
These outputs prove bounded declared-policy facts, not deployment or source availability.

## Host-preservation veto

Read-only SSH inspection found Aspen1 at:

```text
/nix/store/86ndjhhb30wk88mlb55dxpaiicv33x9w-nixos-system-aspen1-26.11.20260819.afe3d8a
```

Radicle, HTTPD, the reconciliation timer, Nginx, uWSGI, and SearXNG initialization were active.
The desktop closure remained:

```text
/nix/store/809lx8nxs26rkc53czi4z9cpfn5npc9l-nixos-system-britton-desktop-26.11.20260819.afe3d8a
```

Evaluation of the isolated Aspen1 candidate returned:

```json
{"searxEnabled":false,"uwsgiEnabled":false}
```

The primary checkout contains unrelated staged and unstaged Collie, SearXNG, and Kagi changes.
Its deployment evidence binds the live Aspen1 closure to those uncommitted changes.
A full switch from the clean admission branch therefore fails the preservation requirement.
An independent read-only review reached the same veto. No secrets or credential contents entered that review.

## Commit-hook blocker and recovery

The first hook run used the inherited `.git/config` root marker and formatted the parent workspace.
The hook log identified 39 changed paths. Recovery checked their recorded sizes against the index and current files before any restore.
Recovery retained copies of both versions, restored only those paths, and checked the restored bytes.
Positive and negative tests covered the recovery parser. The unrelated workspace log and untracked files remained untouched.

`TREEFMT_TREE_ROOT` is not a workaround because it conflicts with the wrapper's explicit root-file argument.
The source fix uses `flake.nix` as the root marker instead.
The regression fixture failed with the old marker and passed with the new marker.
It requires child formatting, repeat-run stability, and an unchanged parent file.

The normal commit hook also rejects pre-existing Statix findings in unrelated Celld, RustFS, niks3, Kache, Kiln, and Bookshelf modules.
No hook was disabled or bypassed. This checkpoint remains uncommitted and unpushed.

## Remaining work

1. Integrate the live service sources through their owning work before constructing a new deployment candidate.
2. Review the pinned Radicle package identity and repair the existing version gate through the package-upgrade procedure.
3. Pass the complete node and replica gates. Compare the new candidate closure with each current host.
4. Deploy through Clan with strict host-key checks and retain rollback closures.
5. Reconcile the declared seven public and four private repositories on the three seeds. Keep HTTPS public-only and CI unchanged.
6. Verify native replication, fresh exact-revision HTTPS acquisition, Git objects, the BLAKE3 archive, and rejection probes.
7. Record those observations before sync, archive, or main integration.

The existing historical bootstrap receipts remain unchanged. This checkpoint makes no Campaign correctness, consumer adoption, KVM, release, or indefinite-availability claim.
