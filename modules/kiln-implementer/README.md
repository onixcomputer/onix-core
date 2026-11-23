# Opt-in Kiln implementation deployment and worker guests

**Consumer/maintenance owner:** onix-core module maintainers. Kiln owns work,
claims, admission, canonical CI and publication; Lattice owns one attempt's durable
execution; Cairn owns lifecycle. This package is **not deployed or runtime
qualified**. It changes no existing canary, Radicle CI, static CH guest or hosted
no-network CI profile.

## Actual composition

`nixos.nix` exports `services.kiln-implementer`; `default.nix` and `schema.ncl`
expose the disabled-by-default Clan role. It packages actual bounded owner CLIs,
not an assumed implementation daemon, new scheduler or task database. No stage
has a startup target, automatic successor or restart policy that can create a new
semantic attempt. All stage units have `Restart=no`. Process restart never resets
Kiln budgets or proves physical release.

With the default runtime name `kiln-implementation`, the explicit stages are:

1. `-poll` or `-cairn-intake`: allowlisted source intake only.
2. `-claim` retains stdout from the real current canonical claim, then
   `-bind-dispatch` materializes protected stage inputs and `-reserve` records
   the native plan reservation. `-admission-status` observes the native owner.
   The explicitly synthetic fixture alone uses `-prepare-fixture-intake` before
   claim; it cannot create a claim or assert live provider capacity.
3. `-dispatch`: the real `kiln-lattice-dispatch --worker-request ...
   --worker-transport-profile ... --dispatch-plan ... --admission-observations ...`
   consumer. It binds frozen worker bytes, work/version/attempt/fence/workspace,
   exact source and model policy, and current provider admission before transport.
   It invokes Lattice's production `implementation-attempt run` consumer. There
   is no deployed direct `-worker` bypass or legacy review/exchange route.
4. `-recover-dispatch`: the same actual consumer with `--recover true`, refusing
   absent prior transport intent. It does not create a second worker to resolve
   unknown dispatch. `-cancel-worker` persists cancellation for the exact installed
   native request; the running owner observes it and performs bounded teardown.
5. `-export-candidate`: invokes the actual pinned Lattice `recover` command,
   requires its produced result for the installed envelope/fence, retains the
   native observation and exports a complete group-read-only snapshot/host
   receipt. It does not accept worker success text or mark anything verified.
6. `-capture-candidate`: the separate verifier UID invokes actual
   `kiln-implementer capture-candidate`. It independently hashes the exported
   bytes against the enrolled Git baseline and native host receipt, then
   materializes exact Git objects in the trusted private repository/retention ref.
7. `-verify`: the actual canonical consumer, not the removed implementer verify
   or a caller-supplied passing JSON envelope:

   ```text
   kiln-web-service verify-implementation --profile CI_SERVICE_PROFILE --database DB --enrollment ENROLL --attempt ID --fence N --verification-profile PROFILE --authority AUTHORITY
   ```

   This executes trusted checks and persists/adopts their actual canonical Engine
   observations. Typed `CandidateVerification` stdout is retained in the stage
   log. No shadow journal or accepted-CI mirror is created.
8. `-bind-publication` requires the actual retained handoff and independent
   verification, then exports the protected Git ODB and seals the native remote
   source profile. `-prepare-publication` and `-publish` consume those bound
   files, including mandatory `--remote-profile`; there is no raw profile bypass,
   landing unit or automatic merge. `-status` observes the retained ledger.

The native owner still decides source changes, stale claims, current authority,
failed/unknown/cancelled results and recovery. A successful service exit does not
mean the task landed or its Cairn lifecycle completed.

## Operator-started selected Cairn campaign

The native campaign driver is a separately named opt-in (`selectedCampaignEnable`,
default `false`), independent of the staged units above. It is a single bounded
operator invocation, not a daemon, timer, startup target, or successor scheduler.
The only generated campaign unit is
`kiln-implementation-drive-selected-campaign@.service`; start one version explicitly:

```sh
systemctl start kiln-implementation-drive-selected-campaign@<expected-version>.service
```

The root-owned oneshot runs the actual selected-cohort command:

```text
kiln-web-service drive-implementation-campaign --profile FILE --campaign-id ID --expected-version N
```

The campaign ID is fixed by the typed profile and module setting; `N` is supplied
per invocation. Native `maximum_operations` is required and bounded to 1..128.
The owner stops on wait, blocked/replan/human request, completion, or an unresolved
original effect; restart does not reset its ledger or operation budget. `Restart=no`,
no `WantedBy`, and no activation hook are used.

Build the complete profile through `configuration.nix` with all of:

- `selectedCampaign`: operator-maintained Nickel inputs for the selected campaign ID,
  canonical existing campaign/implementation DB paths, exact frozen
  `verification_routes` keyed by content identity, verifier authority, worker
  dispatch/request templates and fresh provider admission observations, native
  Cairn source plus its actual typed implementation policy, one exact local Git
  workspace source with bounded entry/path/file/total-byte limits, and exactly one
  complete GitHub or native-Git delivery policy.
  The `selectedCampaign` Nickel record's exact fields are `campaign_id`,
  `campaign_database`, `implementation_database`, `verification_routes`,
  `verifier_authority`, `bound_input_directory`, `candidate_export_directory`,
  `worker = { dispatch_plan, request, admission_observations }`,
  `native_cairn = { repository_root, source, implementation_policy }`,
  `claim_lease_ms`, `maximum_operations`, and
  `workspace = { repository, repository_path, work_root, max_entries,
  max_path_bytes, max_file_bytes, max_total_bytes }`. Each verification route maps
  one 64-hex content identity to exact `ci_service_profile` and
  `verification_profile` paths. `admission_observations` is a caller-supplied fresh
  observation path or JSON `null` when no such input is configured.
- `delivery` is exactly one of `{ route = "github_pull_request"; github = ...;
  native_git = null; }` or `{ route = "native_git"; github = null; native_git = ...; }`.
  GitHub inputs bind enrollment, remote profile, publication/landing policy,
  lifecycle action and receipt template, repository and authoritative report root,
  and bounded timeout. Native-Git inputs bind enrollment, service/review profiles,
  exact repository/change, strict remote/provider/expected-old-target/target-ref,
  lifecycle action and receipt template, and authoritative report root. Credential
  bytes and tokens are never fields in either record.
- `selectedCampaignCohort`: a separately built `campaign-cohort.nix` result from
  the actual immutable component inputs and revisions. Its admission checks the
  selected Cairn executable's `implementation-ready` and workflow commands and
  selected Lattice's `implementation-attempt prepare` and `export-candidate` CLI
  capabilities. The old historical cohort and its pins are not changed or reused.
- `campaignDataGid` and the four role UIDs. The constructor takes worker, exporter,
  capture, verifier, delivery and setpriv program paths/hashes from the selected
  cohort/package and the explicit principals; it imports the canonical
  `kiln/share/kiln/implementation-campaign-drive.ncl` `Profile` and `RoleProgram`
  contracts installed by that exact Kiln package. It fails if that source artifact
  is absent. Native worker transport is generated separately as v2, never via the
  historic v1 compatibility profile; the native prepared request-profile identity
  remains separate from stable `WorkNeeds`.

`campaign-profile.ncl` exports the real `Inputs` contract and the typed `generate`
composition function, not an empty profile file. `generate` wires real cohort
entry paths/digests, the exported enrollment, actual
Cairn policy bytes/hash, source identity, and selected delivery roles into the
canonical drive DTO. The same paths/ID/GID must be supplied to the Clan module's
`selectedCampaignId`, DB, bound-input, candidate-export, workspace and data-group
settings. The module creates only its configured owned roots: bound-input and
candidate-export are root-owned setgid `02770`; workspace parent is root-owned
`0750` in the selected data group. It never creates either canonical DB or alters
their owner/authorization.
The Clan role exposes matching `selectedCampaignEnable`,
`selectedCampaignProfilePath`, `selectedCampaignId`, `selectedCampaignDatabase`,
`selectedImplementationDatabase`, `selectedCampaignBoundInputDirectory`,
`selectedCampaignCandidateExportDirectory`, `selectedCampaignWorkspaceRoot`,
`selectedCampaignDataGid`, `selectedCampaignNetworkNamespace`, and
`selectedCampaignCredentialPath` inputs. They lower to the corresponding
`services.kiln-implementer` NixOS options (the profile option is named
`selectedCampaignProfile` there). Campaign delivery networking is private by
default; an externally provisioned namespace is explicit and must differ from the
coding-model namespace. The NixOS assertions require the existing staged module,
the immutable exact cohort and profile, existing canonical DB paths, distinct
private roots below the module's campaign state root, and the explicit group ID.


The root driver delegates only the fixed selected pinned roles via `setpriv`; it
does not load/copy credentials or pass a token in argv/environment. For GitHub,
`selectedCampaignCredentialPath` is a separate pre-existing publisher-owned
runtime file, declared read-only as that one path using systemd `ReadOnlyPaths`
and checked by the native consumer as a singly-linked mode-`0400` file owned by the publisher UID. Do not
use `/run/secrets` or make the file visible to the OMP child; OMP remains in the
existing private-root sandbox without trusted roots or credentials. Canonical
verifier roots are independently configured and authorized as before.
The controller retains only `CHOWN`, `DAC_OVERRIDE`, `KILL`, `SETGID`, `SETPCAP`
and `SETUID`: exact snapshot ownership transfer, private canonical state access,
bounded cross-UID teardown, and `setpriv` delegation with an empty child
capability bounding set. It has no mount/admin capability. SQLite requires its
explicit dedicated canonical state parent directories writable for journals;
selecting a broad parent such as `/var/lib` is refused. These grants apply only
to the opt-in controller, not its editing child or a read-only projection.

Delivery routes are mutually exclusive: GitHub PR publication/integration/lifecycle
uses the publisher-owned path and task-bound receipt template; native Git uses its
typed strict remote/provider/expected-target contract and never gains PR authority.
No raw request/publication/binding files are accepted. A selected campaign remains
unqualified until native runtime, provider, canonical Engine, and external-effect
prerequisites are separately observed.

## Authority, credentials and bounds

| Boundary | Default UID | Authority |
| --- | --- | --- |
| Coordinator | 930 | existing Kiln ledger; scoped intake token only in `-poll` |
| Trusted Lattice host dispatcher | 931 | private Lattice state/workspaces; unit-scoped ledger access for dispatch, cancellation and native result export |
| PR publisher | 932 | existing ledger; separate PR token only in `-publish` |
| Independent verifier/capture | 933 | existing ledger, private trusted Git/scratch, explicitly authorized existing canonical Engine roots |

The executor account is not permanently enrolled in the ledger group. Distinguish
that fixed trusted host process from its editing OMP child: the child runs in the
mandatory bubblewrap private root, clears its environment, drops capabilities,
and mounts only read-only runtime bases plus explicit source-relative read/write
grants. No ledger, publisher credential, verifier root or mutable trusted policy
path is mounted. This is the selected provider boundary, **not a hostile-isolation
qualification**. Actual namespace/UID/effect tests are still required. A cwd or
Nix devshell alone never qualifies isolation.

**Worker sandbox inside the dispatch unit.** Lattice starts the OMP worker as a
child of the dispatch unit (`-dispatch`, and `-recover-dispatch`, which can
relaunch), under bwrap with `--unshare-user --disable-userns --unshare-pid
--unshare-ipc --unshare-uts --unshare-cgroup --unshare-net`, a fresh `--proc
/proc`, a private `--dev /dev`, and a read-only root. The pilot boot test probed
the unit's exact settings with Lattice's exact bwrap argv. Two settings had to
give way: `AF_NETLINK`, which bwrap needs to bring up loopback in the worker's
private network namespace, and `ProtectKernelTunables`, whose read-only
overmounts under `/proc` make the kernel refuse bwrap's fresh procfs mount.
`PrivateDevices` and `ProtectControlGroups` were not needed and stay on, as do
all other settings: `NoNewPrivileges`, an empty `CapabilityBoundingSet`,
`ProtectSystem=strict`, the private or model-only network, the credential
`InaccessiblePaths` and the resource bounds. The relaxation applies only to
those two units; the module's checks require every other stage to keep both
settings.

What is traded away: the trusted dispatcher process itself, Kiln and Lattice
running as the executor, can open netlink sockets and could write
`/proc/sys` and the other kernel-tunable paths if the kernel's own permission
checks allowed it. They do not for a non-root, capability-free process, so
the loss is defence in depth for the dispatcher, not a new authority.
Netlink in the model-only namespace reaches only that namespace's
interfaces, and the account has no `CAP_NET_ADMIN` to change them. The
worker is covered by bwrap's own isolation, not these two settings: it runs
in its own user namespace with all capabilities dropped and nested user
namespaces disabled; its network namespace has only loopback; its `/proc` is a
fresh procfs for its own PID namespace, so it sees none of the host's
processes; and its root is read-only, apart from the explicit workspace
write grants. Scoping the relaxation to the worker alone would need Lattice
to launch the worker in its own systemd unit or scope. Lattice `7fb6dc47`
spawns bwrap directly as a child process, so that change belongs upstream.

All UIDs must be distinct and checked for host conflicts. Intake and publisher
credentials must be different scoped runtime files outside the Nix store and are
loaded with systemd `LoadCredential`, not baked into images or environment files.
Immutable policy/profile/source templates contain no secrets. Actual request and
publication inputs are generated only in protected root-owned runtime bindings.
Verifier repository,
scratch and reports have private UID-owned roots outside worker and group-writable
ledger state. A read-only candidate-export group permits independent capture,
not editing of trusted verification state.

The module enforces CPU quota, memory, task count, start/stop deadlines and
control-group teardown; native consumers bound input/output and attempt budgets.
Source/candidate preparation has named entry/file/byte limits. **Those capture
limits are not a runtime disk quota.** A selected workspace/compute provider must
supply the actual bounded allocation/quota and current grant before a live pilot;
this module does not invent a storage grant or mutate host quota policy.

The worker never has a network device (Lattice request v3 refuses `network:true`
and the removed `network_namespace` field). Its only model route is Lattice's
attempt-local broker, which runs on the host side inside the dispatcher. The
dispatcher's network is private by default; optional
`modelNetworkNamespace = "/run/netns/<name>"` joins an existing endpoint-scoped
namespace for the broker's upstream. Missing namespaces fail startup without host
network fallback. The request's broker endpoint must be HTTPS or the namespace's
literal loopback. This package does not create a network/model lifecycle
controller. Optional `modelCredential` is a runtime key file loaded with
`LoadCredential` into the first-run dispatch unit only and exported there as
`KILN_IMPLEMENTATION_MODEL_KEY`; the request names it as
`{"provider":"env","key":"KILN_IMPLEMENTATION_MODEL_KEY"}`, and Kiln passes only
that variable to Lattice's host broker. The worker, verifier, recovery and
cancellation never receive it. Every stage unit hides each credential file's
directory with `InaccessiblePaths`. Do not put keys in reusable source, `.omp`
files or guest disks.

## Exact source/cohort and policy inputs

`cohort.nix { pkgs; lib; }` accepts explicitly selected `kiln`, `lattice`, `cairn`,
`worker`, `workflow`, `revisions` and optional `sourceCohorts`. It records actual
dereferenced executable paths and BLAKE3, including `entries.verifier` for
`kiln-web-service`, `entries.lattice`, OMP, bubblewrap, Git, Nix and the workflow.
The selected OMP reference is `e325ffc73ab86e03bdd20a91b77d8e2b3964c906`, matching
the real JSONL adapter. Pi is unsupported by this named profile, not a fallback.
The cohort builder refuses missing executables and an old Lattice without the
actual `implementation-attempt` subcommand.

Full component revisions are required. An unpublished candidate may additionally
supply exactly:

```text
{ kind="unpublished_candidate", repository, baseline_revision,
  baseline_archive_blake3, patch_blake3, source_archive_blake3,
  source_nar_hash, source_scope=[owned relative files] }
```

BLAKE3 fields are bare lowercase 64-hex; NAR is `sha256-<base64>`.
`baseline_revision` must match the selected component revision. Partial or
unsupported provenance claims are refused; metadata is not proof that arbitrary
bytes came from that source and never invents a published revision.

The canary inputs (`kiln-canary`, `lattice-canary`, `cairn`) stay unchanged and
do not qualify these consumers. This composition's single pinned version set is
the separately named rev-pinned flake inputs `kiln-implementation`,
`lattice-implementation`, `cairn-implementation` and `omp-implementation`, built
by `pinned-cohort.nix` and recorded in `compatibility-receipt.json` (see
[Pinned version set](#pinned-version-set)). Never use a floating sibling
checkout, assume unpublished functionality in an old pin, edit `flake.lock`
manually, publish or deploy to obtain qualification.

`configuration.nix` exports the owner-typed Nickel `enrollment`, `githubPolicy`,
`cairnPolicy` and `workerTransportProfile`, plus an explicit `workClass` and
`repository`. Enrollment must exactly match configured repositories/actors;
standing policy requires exact base, acceptance, permitted paths, finite
attempt/time budget and `verified_pull_request`. The class binds the actual
exported policy digest. The transport must be
`kiln.lattice-implementation-cli.v2`, bind the actual Lattice executable hash and
use `/var/lib/<name>/lattice/{implementation,observations}`, not Kiln/verifier state.

`attemptBundle` is an immutable template, never a pre-minted live lease. It
contains `runtime-template.json`, source `base/`, the natively prepared
`verification-profile.json`, and immutable Cairn readiness inputs. Template
programs, check definitions, policy, model configuration and source/cohort bytes
stay in `/nix/store`. The controller invokes actual canonical `claim` and retains
its immutable stdout under `controller/claims/<attempt>-<fence>.json`.
`controller/current.json` is only an artifact reference, not a second task store.
Every binding use re-reads `inspect-attempt` through the real owner and requires
the current work/version/fence/lease (or native verified publication authority).

`materialize-binding --stage dispatch` creates the actual claim workspace,
invokes native Lattice `implementation-attempt prepare` for snapshot/profile and
envelope identities, and seals the exact request bytes, dispatch plan, current
admission observations and verifier definitions in
`controller/bindings/<attempt>-<fence>/dispatch/`. The explicitly scoped synthetic
fixture uses the required immutable native helper to apply existing typed
admission/WorkNeeds/AttemptBinding interfaces; no Python-generated live grants
or model-capacity claims are admitted. After its policy association, native
Lattice preparation runs again before the request is sealed. The existing
native reserve-before-effect and request-seal checks remain authoritative.

`--stage publication` is separate: publication files do not exist and are not
required during dispatch/capture/verification. It requires actual retained
handoff/verification identities and native branch derivation, clones real
protected Git objects without hardlinks into
`publication-source/<attempt>-<fence>/candidate`, then seals `publication.json`
and `publication-source-profile.json` under the publication stage directory.
Bindings are root-owned regular/no-follow bounded files, mode 0444 in protected
directories outside the worker/group-writable ledger. A manifest binds actual
template/cohort and request byte digests. No legacy static-attempt preparation
route or blanket admission of mutable paths remains.

The controller units (`claim`, `prepare-fixture-intake`, `bind-dispatch`,
`bind-publication`) keep `NoNewPrivileges` and switch no accounts. Each runs as
the coordinator (`User=`), and only that phase invokes Kiln: `claim`,
`inspect-attempt`, the fixture helper, or the live needs/plan reservation. The
root phases are `!`-prefixed `ExecStart` lines in the same sandbox with only
`CHOWN`, `DAC_OVERRIDE` and `FOWNER`. They never run Kiln. They read the
coordinator's result and check it against the retained claim. They create the
worker-owned workspace, run Lattice preparation, and seal the root-owned
bindings. The phases hand off through `controller-spool/`: root-owned, sticky,
`1770` in the ledger group. Each phase replaces only its own documents, and
every read checks the writer's UID. The order is `claim`: native, then seal.
`bind-dispatch`: observe, stage, execute, seal. `bind-publication`: observe, then
seal.

Preparation creates `/var/lib/<name>/workspaces/<workspace_id>` exclusively and
normalizes immutable-store transport modes before native base capture. Different
attempts get different roots and durable native state. Existing/partially
prepared workspaces are never overwritten; recovery never recopies source.
Preserve workspace/state, native artifacts, candidate exports, canonical evidence
and `/var/log/<name>-*` logs until their owner retires them. No cleanup/refund is
inferred from exit, timeout, cancellation intent or coordinator loss.

Lattice v3 writes the worker's OMP model configuration itself, read-only at
`/tmp/omp-home/.omp/agent/models.yml` inside the sandbox, from the request's
`omp.model_broker`. Do not add a `.omp` model config to the source baseline; host
capture still treats any `.omp` file in the workspace as candidate truth.

### Canonical CI state is not a deployment fixture

Configure `ciServiceProfile` explicitly for the actual repository and canonical
Engine node/all-check/Cairn mapping, plus `canonicalCiStatePaths` for the existing
journal/material the verifier is separately authorized to write. The module
creates no directories or ownership changes for those paths. UID 933 must have
real authorized store/source/profile access. An existing Engine writer conflict
is an explicit blocker; do not stop/restart that service or create a mirror to
force access. Profile validity, real canonical persistence and independent check
acceptance are the native consumer's responsibility and must be exercised.

## Immutable guest and mutable disks

`guest.nix` packages an explicit x86_64-linux NixOS kernel/initrd, immutable
squashfs store/root, runtime/tools/workflow closure and manifest. It requires the
actual x86_64 CH ELF and observed v54.0-family version; a wrapper delegating to
`/run/current-system` is refused even if its declared version matches. The
manifest records actual executable, kernel version/bytes, initrd/root/runtime and
generated launch-profile identities.

- `/dev/vda`: reusable read-only store disk.
- `/dev/vdb`: separate per-execution raw ext4 workspace.
- `/dev/vdc`: separate raw ext4 state, including execution DB, machine identity,
  writable Nix metadata and store overlay. Root is tmpfs; immutable store is the
  overlay lower layer. The guest imports registration, roots the active system
  and disables automatic guest GC for this worker profile only.
- Machine identity is generated in fresh state on first boot. Relocation
  preserves that execution's state/identity; new executions do not clone it.
  No host identity private key or publisher credential is in reusable content.
- Selected host profile: anonymous/private memory, no hugepages/mergeability,
  host CPU, explicit raw disk type, no NIC, precopy, no postcopy/memfds. Shared
  backing and other platforms are unsupported by this baseline, not silently
  enabled in existing CI.

`kiln-implementation-qualify prepare-disks --directory NEW_OWNED_DIRECTORY
--reference EXACT_EXECUTION --generation POSITIVE_GENERATION --workspace-mib SIZE
--state-mib SIZE` creates only new exclusive raw files, formats real ext4 with
independent observed UUIDs, and retains `disks.json`. It refuses reuse and retains
partial failures. Limits are 128..65536 MiB per disk. No credentials are
provisioned and guest identity remains explicitly unobserved until actual boot.
The manifest is not a placement/disk fence or activation grant.

This is a new **unqualified environment package**, not a claim that the old
per-job `kiln-microvm-guest` is a retained Lattice reconnect gateway. The existing
retained host backend currently admits its own single-workspace profile; this new
multi-disk environment must not be fed to it under a fabricated compatibility
label. A real selected gateway/host-channel and Aspen current-placement,
writable-disk and external-effect fencing are prerequisites. No VM is started by
this module. Actual generated CH CLI/API, cold boot, memory backing, migration,
restore, filesystem/credential boundary and multi-step guest executor evidence
remain independently required; matching a launch-profile digest does not prove
any of those runs.

## Both-host staging and GC retention

The Linux package/app is `kiln-implementation-qualify`; its implementation is
`qualification.py` and its runtime dependencies are pinned by
`qualification-package.nix`. After explicitly approved copying to each placement
host, use actual owned references/paths:

```text
retain --guest GUEST_STORE_PATH --kind live --reference EXACT_ATTEMPT --roots OWNED_ROOT_DIRECTORY
retain --guest GUEST_STORE_PATH --kind checkpoint --reference EXACT_CHECKPOINT --roots OWNED_ROOT_DIRECTORY
observe --manifest GUEST_STORE_PATH/manifest.json --host ADMITTED_HOST_ID --retention-root EXACT_OWNED_ROOT --output NEW_RECEIPT.json
compare-placements --source SOURCE_RECEIPT.json --destination DESTINATION_RECEIPT.json
```

Retention establishes an actual indirect Nix GC root and refuses rebinding.
Observe verifies transitive registered store contents, actual VMM bytes/version,
workflow/runtime/tools/launch and the exact root in Nix's root query. KVM absence
is explicit unsupported evidence. Receipts are never overwritten. Comparison
requires distinct hosts and matching immutable paths/cohorts plus observed
retention; it always says `dispatch_allowed=false`, `qualification=unqualified`.
It does not replace fresh authoritative placement/effect/provider revalidation.
Host labels here are not cryptographic host identity proof.

Keep roots on **both** hosts for every live/committed-checkpoint reference. Process
exit does not retire a reference. Only after the session/storage owner
establishes retirement may an operator explicitly remove its owned root. This
package performs no remote copy, activation, shared GC, root removal or host-key
transfer. The static guest bootstrap and its GC behavior are unchanged.

## Checks and remaining qualification

Proposal/design/tasks prerequisite gates passed before product edits in native
change `package-kiln-implementation-guests`. No build, test, formatter, runtime
campaign, activation or remote mutation was run by this slice.

After all owners finish and exact source adoption lands locally, main should run
from onix-core with an owned `/run/user/<uid>/kiln-issues-deployment` scratch/build
directory and per-command `min-free=0`:

```sh
NIX_CONFIG='min-free = 0' nix build --no-link --option build-dir /run/user/1555/kiln-issues-deployment path:.#checks.x86_64-linux.kiln-implementation-module path:.#checks.x86_64-linux.kiln-implementation-device-free
TMPDIR=/run/user/1555/kiln-issues-deployment python3 -m unittest discover -s tests -p test_kiln_implementation_deployment.py -v
```

Evaluation covers opt-in defaults, actual strong route, unit-only ledger access,
separate verifier/publisher, no direct-worker/landing route, explicit recovery,
canonical-state adoption, namespace and invalid guest/module cases. Device-free
fixtures test positive/refused policy, executable/state/path bindings, workspace
separation/no-overwrite, export receipt/fence checks and disk provisioning
boundaries. Substituted external tools in fixtures never count as real worker,
ext4 formatting or KVM qualification. Build the selected actual cohort,
configuration and guest separately only once sufficient owned storage and the
exact source set exist; no large guest closure was built mid-flight.

`qualification-profiles.json` keeps independent unqualified scopes. The Roadmap
qualification owner supplies the actual scripted fault/recovery and live-pilot
driver. Baseline needs one real bug and bounded feature, independent exact-source
checks and authorized PR effects; duplicates, stale claims, cancellation,
source/target movement and crash-after-effect-before-acknowledgement must be
reconciled without duplicate workers/PRs or false completion.

Live prerequisites include exact reviewed source/tool/model provenance, actual
bounded workspace/compute grants, namespace/UID isolation evidence, canonical
Engine writer/source authority and explicit repository/token/branch/PR approval.
The cross-host two-CPU-worker pilot additionally needs real Lattice #24 / Molten
#42 / Animus #17 observations, distinct writing repositories, independent
execution versus shared-serving allocations, exact engine/model/device, usage,
queue/loading/saturation/loss/restart accounting and actual host/driver evidence.
Configured inventory and cached models do not grant requests or release resources.

Residency/soft affinity, campaign budgets, dormancy/continuation, separate
worker/model recovery and revision promotion/rollback each require their selected
Inference Lab #11/#5, Kiln #61, Lattice #12/#25, Molten #19, Animus #9/#18 consumer
and exact-profile evidence. Missing gateway, Iroh/Aspen-Molten cross-host
compatibility/fences, credential delivery, KVM/GPU/backend or canonical writer
handoff remains unsupported/unqualified. Packaging/device-free success cannot
close #49/#51's live acceptance criteria or promote every advanced profile.

### Runnable scripted VM contract and evidence scope

The strict constructor is:

```nix
import ../../tests/kiln-implementation-scripted-bundle.nix {
  inherit pkgs lib cohort fixtureHelper cairnSource cairnPolicy;
}
```

All four external inputs are required immutable store paths: the exact actual
`cohort.nix` output; `fixtureHelper` containing real
`bin/kiln-implementation-fixture` built with
`kiln-web-service/implementation-fixtures`; the matching adopted `cairnSource`
containing `fixtures/basic/.cairn`; and its exact generated `cairnPolicy` JSON.
The cohort's publisher must be the actual explicit `protocol-fixtures` build for
the closed loopback endpoint. Default/live packages never enable a fixture
transport by environmental accident. No canary, empty directory, fake executable
or no-op fallback is accepted for an executed component.

The constructor creates a genuine deterministic Git baseline, native Cairn ready
and changed-source projections, an actual independent exact-byte reproducer and
verification profile, typed Nickel policy/model/remote/runtime templates, and
the real canonical CI service profile via native preparation/validation. Native
YAML is generated from `models.ncl`. It mints no claim, lease, result, CI receipt,
provider effect or PR. Its passthru exposes `configuration`, `attemptBundle`,
`ciServiceProfile`, `canonicalCiStatePaths`, `repositories`, `workClasses` and the
disposable canonical state ownership module.

`flake-outputs/_kiln-implementation-scripted-vm-checks.nix` takes the same six
arguments and exports `packages.kiln-implementation-scripted-inputs` and
`checks.kiln-implementation-scripted-vm`. The VM constructor itself accepts
`{ pkgs; lib; fixture; }`. The parent integrating the actual frozen source cohort
must import this factory; there is deliberately no implicit default cohort.

The executable VM campaign uses the real module's systemd stages and separate
UIDs/mounts. Its positive path is native ready intake/deduplication, one real
claim, isolated pinned OMP write through the bounded authless loopback model,
actual worker-effect/dispatcher-acknowledgement loss and native recovery,
independent protected checks in the canonical Engine, genuine candidate Git
objects and guarded bare-ref push, then one stateful loopback PR with lost-response
reconciliation and fixture restart. Separate disposable nodes exercise native
timeout, observed cancellation/quiescence, elapsed real lease expiry/stale
claims and actual changed Cairn-source supersession. Actual target-ref movement
is refused before PR creation. Live child mount inspection requires read-only
policy/config mounts and absent publisher credentials/trusted state.

Per-node evidence archives retain runtime claim references/bindings, native
Lattice artifacts, real candidate exports and protected verification/Engine
state, stage logs, model/forge events and exact input manifest references. The
GitHub fixture reads real pushed commits/refs and refuses API-only invented SHAs.
All deployment/profile statuses remain `unqualified`. This source integration
was not executed by its editor; only the parent may record coordinated check
results. Scripted local results never qualify live OMP/model capacity, retained
guest boot/restore/migration, production credentials, remote GitHub publication
or cross-host serving.

## Pinned version set

`pinned-cohort.nix` builds the one composition from the rev-pinned inputs Kiln
`09326e92` (`kiln-implementation`, with the read-only `--sent-request` mode), Lattice `7fb6dc47`
(`lattice-implementation`), Cairn `47ea1b86` (`cairn-implementation`, the
revision Lattice locks; its gate contract is byte-identical to Kiln's vendored
verifier import `15f00875`) and OMP `e325ffc7` (`omp-implementation`, the same
derivation Lattice's source qualification built). `compatibility-receipt.json`
records their revisions, `narHash`es, every cohort executable's resolved path and
BLAKE3, and the workflow identity; this command fails on any drift:

```sh
nix build --option builders '' --no-link .#legacyPackages.x86_64-linux.kiln-implementation.receipt
```

**Known blocker:** Cairn `47ea1b86` has no `cairn implementation-ready`, which the
scripted fixture and Cairn intake require. That command first appears on Cairn
main at `ba68144`, which does not descend from `47ea1b86` and whose gate contract
differs from Kiln's vendored `15f00875`. The scripted VM inputs therefore do not
build until Lattice and Kiln agree on a Cairn revision that has it.

Opt-in outputs, never swept by CI (`legacyPackages.x86_64-linux.kiln-implementation`):
`cohort`, `campaignCohort`, `fixtureCohort`, `fixtureHelper`, `scripted-inputs`,
`scripted-vm`, `receipt`, `pilot-inputs.{bug,feature}`, `pilot-vm.{bug,feature}`
and `pilot-boot`.

## Live pilot runbook (local VM only)

The live verified-PR pilot runs only inside a local NixOS VM on the operator's
workstation, never as a host deployment. The allowlist is exactly
`OnixResearch/implementer-sandbox` (Kiln's durable key
`onixresearch/implementer-sandbox`) at base
`f1adb86f6320f2bbb6c02ae077905a6bb8c22955`. Each issue has its own guest, and
each guest's intake policy carries Kiln's `selection = { issues = [N] }`, so
polling admits only that issue and observes the other as `unselected`:
`pilot-vm.bug` (issue #1, reproducer `cargo test --features acceptance --test
word_count_whitespace`) and `pilot-vm.feature` (issue #2, `--test
char_frequency`). Verification runs that acceptance test and `cargo test` (kind
`test`), and `cargo fmt --check` and `cargo clippy --all-targets -- -D warnings`
(kind `review`) offline on the captured candidate; `tests/*.rs`, `Cargo.toml`
and `Cargo.lock` are protected paths pinned from the base. Publication is
verified PR only: no landing, no merge.

Admission uses Kiln's registered host-local owner. `configuration/host-owner.json`
is the export of Kiln's `config/fair-admission-host-owner.ncl` for this guest:
provider `onix-local-pilot-host`, one `worker_slots` of capacity, a four-attempt
campaign quota, and exactly `onixresearch/implementer-sandbox` with this guest's
work class bound to its frozen verification profile. The claim, dispatch and
`host-owner-*` stages run with `--local-operator brittonr`.

### 1. Credentials

Create a host directory outside the Nix store, readable only by you:

```sh
install -d -m 0700 ~/.local/state/kiln-pilot-credentials
cd ~/.local/state/kiln-pilot-credentials
install -m 0600 /dev/null intake     # read-only GitHub token (issues + contents read)
install -m 0600 /dev/null publisher  # PR publisher GitHub token (contents + pull requests write)
install -m 0600 /dev/null model      # underclass gateway proxy key
$EDITOR intake publisher model       # one value per file, no trailing newline needed
```

Create the operator SSH key in a **separate** directory, never in the share (the
guest refuses SSH if the share holds a private key), and copy only the public
half into the share:

```sh
install -d -m 0700 ~/.local/state/kiln-pilot-ssh
ssh-keygen -t ed25519 -N '' -f ~/.local/state/kiln-pilot-ssh/pilot-ssh
install -m 0600 ~/.local/state/kiln-pilot-ssh/pilot-ssh.pub \
  ~/.local/state/kiln-pilot-credentials/ssh.pub
```

The directory is shared read-only at `/run/kiln-pilot-credentials`. Every stage
unit hides it; systemd `LoadCredential` copies `intake` only into `-poll` and
`kiln-pilot-acquire-verifier-source`, `publisher` only into `-publish`, and
`model` only into the first-run `-dispatch` (as `KILN_IMPLEMENTATION_MODEL_KEY`
for Lattice's host-side broker). The worker and verifier receive none. At boot,
`kiln-pilot-ssh-authorized-key` installs `ssh.pub` as root's only authorized
key; sshd accepts root with that key only (no password or keyboard-interactive
login, no forwarding, no other account).

### 2. Start the guest

The model route is the host underclass gateway on `127.0.0.1:8080`, which the
guest reaches as `10.0.2.2:8080`. Only the `kiln-pilot-relay` account (UID 936)
may connect there (nftables); the dispatcher's model namespace holds only
loopback plus the relay's bridge on `127.0.0.1:18080`; the worker has no network
device. Kiln accounts 930/932 get outbound HTTPS only; 931/933 get nothing.

```sh
nix build --option builders '' --out-link .qual/pilot-vm-bug \
  .#legacyPackages.x86_64-linux.kiln-implementation.pilot-vm.bug
KILN_PILOT_CREDENTIALS=$HOME/.local/state/kiln-pilot-credentials \
  NIX_DISK_IMAGE=$PWD/.qual/kiln-pilot-bug.qcow2 .qual/pilot-vm-bug/bin/run-kiln-pilot-bug-vm
```

QEMU forwards only host `127.0.0.1:2222` to the guest's port 22. Nothing runs
until you start it. Drive the guest from the host with the helper apps; each
pins the guest host key on first use in `$NIX_DISK_IMAGE.known_hosts`, so a new
disk image gets a new pin and a changed key is refused:

```sh
export NIX_DISK_IMAGE=$PWD/.qual/kiln-pilot-bug.qcow2
export KILN_PILOT_SSH_KEY=$HOME/.local/state/kiln-pilot-ssh/pilot-ssh   # the default
nix run --option builders '' .#kiln-pilot-ssh -- systemctl is-system-running
nix run --option builders '' .#kiln-pilot-stage -- policy-check
nix run --option builders '' .#kiln-pilot-collect -- ./pilot-evidence/bug
```

`kiln-pilot-stage UNIT` starts `kiln-implementation-UNIT.service` (or a full
`kiln-…`/`….service` name), prints its exit code, `Result`, `ActiveState` and
main exit status, and the tail of its stage log and journal; it exits with the
start's status.

### 3. Stages, in order

Run each with `kiln-pilot-stage NAME` from the host (equivalently
`systemctl start kiln-implementation-NAME` as root in the guest); `S=kiln-implementation`.

1. `systemctl start $S-policy-check` — admit the immutable configuration; the
   intake policy goes through Kiln's own `kiln-implementer policy-check`.
   The build already ran the same check plus Kiln's `poll` parser
   (`pilot-parse`) and the GitHub DNS helper entry (`pilot-resolver`); each
   guest depends on both.
2. `systemctl start kiln-pilot-acquire-verifier-source` — clone the enrolled
   repository into the protected verifier store (GitHub read, intake token) and
   confirm the base commit.
3. `systemctl start $S-poll` — authenticated intake of the repository's issues.
   Then `systemctl start $S-status` and inspect
   `/var/log/$S-coordinator/status.jsonl`; confirm with
   `kiln-implementer inspect-work` which work is issue #1 (bug guest) or #2
   (feature guest).
4. `systemctl start $S-host-owner-admit` — configure the owner's policy and
   campaign account and queue the selected work.
5. `systemctl start $S-host-owner-observe` — fresh usage and eligibility
   observations (valid for 10 minutes).
6. `systemctl start $S-claim` — retains the canonical claim under
   `/var/lib/$S/controller/claims/`.
7. `systemctl start $S-host-owner-reserve` — the owner commits its one-slot
   reservation for the exact claim in `controller/current.json`.
8. `systemctl start $S-host-owner-observe` — again, so the observations sealed
   at binding are fresh at dispatch.
9. `systemctl start $S-bind-dispatch` — stages the workspace, natively prepares
   the request, attaches needs, reserves the plan and seals the dispatch binding
   (including `admission-observations.json`) in
   `/var/lib/$S/controller/bindings/ATTEMPT-FENCE/dispatch/`.
10. `systemctl start $S-reserve` (idempotent), then `systemctl start $S-dispatch`
    — the live OMP worker. If the dispatcher is lost, `systemctl start
    $S-recover-dispatch`; to stop the worker, `systemctl start $S-cancel-worker`.
11. `systemctl start $S-export-candidate`, `$S-capture-candidate`, `$S-verify`.
12. `systemctl start $S-bind-publication`, `$S-prepare-publication`, then
    `$S-publish` — the one GitHub write: a branch and one pull request.
13. `systemctl start $S-host-owner-release` — after the attempt is terminal,
    settles the slot. Kiln releases only from the attempt ledger: if the worker
    may have run (a recorded transport start), it also needs an observed stop —
    the retained native worker result from a completed `-dispatch` or
    `-recover-dispatch`, a retained candidate, or a reconciled termination. If
    the dispatcher was lost and the lease expired, run `kiln-implementer
    recover` and then `kiln-implementer reconcile-termination --attempt A
    --fence F --termination-file FILE` (as `kiln-implementation-coordinator`,
    with the usual `--database`/`--enrollment`) with your observed termination
    record before releasing. An acknowledged run with no result, candidate or
    termination record stays held. A dispatched slot is consumed, never
    refunded. Host-owner attempts start only through `-dispatch`:
    `kiln-lattice-dispatch` records the transport start before any spawn.
    For host-owner attempts Kiln refuses `kiln-implementer start` and
    `kiln-implementer reconcile` with `implementation_transport_start_required`
    unless a transport start is recorded, and `-recover-dispatch`
    (`kiln-lattice-dispatch --recover true`) refuses without one ("recovery
    requires prior persisted transport intent"). Under the host-owner policy
    a claim around admission (`claim_next`) refuses with
    `host_owner_admission_required`; claim only through `$S-claim` after
    `$S-host-owner-observe`. No unit here calls `start` or `reconcile`.
14. `systemctl start $S-status` (and `$S-admission-status`) at any point.

### 4. Receipts and evidence

- Stage stdout/stderr: `/var/log/kiln-implementation-{coordinator,executor,verifier,publisher}/*.jsonl|*.stderr`.
- Canonical claim and sealed bindings: `/var/lib/kiln-implementation/controller/`.
- Lattice attempt state and native observations (raw OMP JSONL, normalized
  observation, candidate receipt): `/var/lib/kiln-implementation/lattice/`.
- Candidate export and host receipt: `/var/lib/kiln-implementation/candidate-export/ATTEMPT-FENCE/`.
- Verification handoff and canonical Engine state:
  `/var/lib/kiln-implementation/verifier/reports/`, `/var/lib/kiln-implementation/canonical-ci/`.
- Kiln ledger (work, attempts, verification, publication):
  `/var/lib/kiln-implementation/kiln/work.sqlite`.
- Deployment and pilot identities: `/etc/kiln-implementation/deployment.json`,
  `/etc/kiln-implementation/pilot-manifest.json`.

Copy them out before deleting the disk image with
`nix run .#kiln-pilot-collect -- DIR`: it writes
`DIR/kiln-pilot-evidence-TIMESTAMP.tar.gz` of every path above (the `/etc`
manifests dereferenced), `….files.b3` with each file's BLAKE3 computed in the
guest, and `….tar.gz.b3` for the tarball. That is the live-worker pilot
receipt, recorded separately from the scripted VM evidence.

`pilot-boot` boots the bug guest without credentials and checks that every stage
unit exists and stays inactive, the configuration is admitted, the host owner
admits and observes, credential-bearing stages refuse, bound stages refuse
without a claim, root SSH accepts only the share's key (password login and other
accounts are refused, and a private key in the share disables SSH), and the
egress rules hold.
