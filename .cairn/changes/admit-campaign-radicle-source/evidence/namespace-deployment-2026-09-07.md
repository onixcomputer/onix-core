# Publisher namespace checkpoint

## Verified source and deployment

Code commit: `004d29ac92db349e96b7688072a840f89acfee1f`.

The route constructor adds exactly two publisher-bound read endpoints. Ten invalid bindings fail policy admission. Four malformed bindings fail route construction. Existing ordinary routes remain equal to their baseline values.

The first checks found two stale fixture expectations. The invalid Nickel fixture lacked the new field. The production route census lacked the two new exact routes. Both fixtures now cover the added behavior without removing the old controls.

Node policy, Campaign source scope, module registry, replica policy, SearXNG module, Kagi session, and Collie integration checks pass from the frozen archive. Deadnix, Statix, treefmt, explicit-policy Cairn validation, and the Aspen1 system build also pass.

The system-unit comparison changes only nginx. The nginx configuration adds only the two exact namespace locations. The preflight reports valid Clan variables. Clan deployed the metadata-free archive through the strict-key Aspen1 path.

Deployed system:

```text
/nix/store/g3mmfgsvq6vl3m554m7i6g576nxzirsy-nixos-system-aspen1-26.11.20260819.afe3d8a
```

Radicle node, HTTP gateway, nginx, and uWSGI were active after deployment. The node identity remained `z6MkfpHAyrqSqhpiSGayy6AjB6L5UWkKLvsZvLh5hYD7XSu8`.

## Live controls at that system

| Request | Result |
| --- | --- |
| Publisher discovery | 200 |
| Unknown publisher | 404 |
| Receive-pack discovery | 404 |
| Receive-pack POST | 404 |
| Extra discovery query field | 404 |
| Upload-pack with GET | 403 |
| Undeclared RID with the publisher | 404 |

## Cargo control remains red

Nix fetched the pinned Campaign source through the namespace route. Cargo then attempted resolution from an empty Git cache. The registry cache was shared, but no Git cache or checkout was copied.

Cargo reported:

```text
fatal: couldn't find remote ref HEAD
```

Its Git command requests ordinary branches, tags, and `+HEAD:refs/remotes/origin/HEAD`. The namespace route did not satisfy that request. Namespace discovery success is therefore not fresh Cargo acceptance.

The attempted consumer URL changes were reverted. Nix regenerated the original consumer lockfile. The ChaosControl worktree remains clean at `6cb124c`. No cache bootstrap, source-ref mutation, signed-reference downgrade, or runtime override was added.

## A newer deployment blocks further live verification

A later observation found a different active Aspen1 system:

```text
/nix/store/2zxpsbc6m6xagfjwd6sz93ji1zifqahj-nixos-system-aspen1-26.11.20260819.afe3d8a
```

The publisher discovery endpoint then returned 404. A subsequent fresh Git probe also failed. This session did not deploy that newer system and did not replace it.

The earlier live controls are historical observations, not a claim about the current system. Further deployment requires a source comparison with the newer host state. The HEAD compatibility problem also needs a controlled backend test before another Cargo acceptance attempt.

Fleet deployment, main integration, accepted-spec synchronization, lifecycle archive, and ChaosControl cutover remain open.

## Retained operator logs

```text
namespace-checks-accepted.log
namespace-frozen-checks.log
namespace-commit.log
namespace-unit-diff.log
namespace-vars.log
namespace-deploy.log
namespace-runtime.log
namespace-http-controls.log
namespace-cargo-resolve.log
namespace-consumer-restore.log
```
