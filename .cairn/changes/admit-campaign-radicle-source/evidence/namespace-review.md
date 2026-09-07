# Publisher-bound acquisition review

## Goal and acceptance

Expose the existing Campaign publisher namespace through exact read-only routes. ChaosControl must fetch the pinned commit from an empty Git cache. Cached Cargo success is not acceptance.

Onix Core owns route admission and deployment. Campaign retains source identity and publication authority. ChaosControl owns dependency adoption. No source commit, signed-reference floor, private scope, CI scope, or existing endpoint changes.

The existing Radicle HTTP backend supplies namespace selection. The route builder remains pure. Nginx and Radicle execute the admitted requests.

## Bounded mechanism review

| Family | Evidence | State |
| --- | --- | --- |
| Ordinary root refs | Fresh locked Cargo fetch fails because the checkpoint is namespaced. | Rejected for this checkpoint |
| Cache bootstrap | Local tests pass, but the empty-cache control fails. | Rejected as durable adoption |
| Publisher-bound route | The deployed backend supports `RID.git/NID` and sets `GIT_NAMESPACE`. Exact route admission remains necessary. | Selected for checks |

The review uses correlated serial passes, not independent reviewer approval. The budget is one route implementation and one negative-control pass before host evaluation. A failed control blocks deployment.

## Contract

`httpsGitPublishers` maps an admitted public RID to an explicitly reviewed publisher NID. The current policy admits only Campaign and its existing publishing delegate. Empty bindings preserve the old routes.

Only exact discovery GET and upload-pack POST routes enter the namespace. Unknown RIDs, unknown publishers, extra query fields, malformed path text, and write routes remain denied. Ordinary routes remain unchanged.

## Completion boundary

Static route checks do not prove deployment. Host evaluation does not prove live behavior. Fresh Git and Cargo acquisition must use the public endpoint after the reviewed deployment.
