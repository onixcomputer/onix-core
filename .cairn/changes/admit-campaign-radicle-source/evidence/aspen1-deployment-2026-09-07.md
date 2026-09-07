# Aspen1 deployment and source privacy blocker

## Deployment

Aspen1 now runs `/nix/store/0dq373wying446jahqg1l2l90fpyd159-nixos-system-aspen1-26.11.20260819.afe3d8a` from frozen tree `9b347b47fc96c3b457cfa80a68448d02500f0e88`.

The operator used the pinned Clan CLI, strict host-key checks, and the verified archive. No switch-inhibitor bypass applied. All Clan variables were present and valid before deployment. No credential generation or rotation occurred.

The first worktree deployment stopped before activation. Clan copied the linked `.git` pointer and the remote evaluator could not resolve its workstation path. The archive retry contained no Git metadata and completed activation.

The service-owned reconciler returned `Result=success` and `ExecMainStatus=0`. The node, HTTP service, policy timer, nginx, and uWSGI remain active.

The Aspen1 node identity remains `z6MkfpHAyrqSqhpiSGayy6AjB6L5UWkKLvsZvLh5hYD7XSu8`, as before deployment. The live comparison preserved Qwen units and included the latest Kagi locked-engine display. Desktop and Aspen3 were not deployed.

## Acquisition blocker

Campaign remains **private** in Radicle. `rad inspect --identity` reports `visibility.type = private`.

A native fetch from the local publishing node failed. Its current journal states that Aspen1 is not authorized to fetch Campaign. Both nodes use Radicle 1.10.1, and their connection is active. No signed-reference downgrade applied.

The operator did not publish Campaign or change its privacy allowlist. Public access requires an explicit owner decision. The forge admission did not itself change the source identity.

The native clone attempt used the `parent` signed-reference level. The service-owned reconciler ran again afterward and passed.

## HTTPS observations

| Probe | Status |
|---|---|
| Synthetic undeclared RID, upload-pack discovery | 404 |
| Campaign receive-pack discovery | 404 |
| Campaign receive-pack POST with no update command | 404 |
| Campaign upload-pack discovery | 500 |

The denial probes pass. The upload-pack response is a failed acquisition, not a public-source success.

A separate unauthenticated request to the live SearXNG Preferences page returned 429. That request does not prove live browser access. The limiter remains unchanged.

The local reference archive for `e23e3edf1dc6a8c612a4ea33a3b805bda1173e3b` has BLAKE3 `78136b386be193f30ee75150eaf56f2576413cb70c4fc0b304983187008480f1`. No matching fresh HTTPS archive exists yet.

## Evidence and limits

Retained operator logs:

```text
forge-archive-deploy.log
forge-runtime-after.log
forge-policy-after-clone.log
campaign-forge-native-clone.log
campaign-local-fetch-log.txt
forge-http-probes.log
campaign-e23-reference.b3
```

The diagnostic passes were correlated. They examined transport, version compatibility, and source authorization. The identity document and node denial identify the current native-fetch blocker. They do not establish that public access alone will resolve every HTTPS error.

No main integration, lifecycle archive, consumer pin, or ChaosControl adoption claim follows from this checkpoint.
