## Context

`britton-desktop` installs Herdr `0.7.5` from `llm-agents`. Home Manager renders the Herdr configuration from typed Nickel data.

The current profile provides `sync-herdr-plugins`. That command downloads five plugins and runs their build commands against mutable user state.

The jj workspace and Pueue plugins need separate manual registration. The Pueue source has no remote repository, so Onix must vendor a fixed source snapshot.

## Completion Contract

The change is complete when one wrapped `herdr` package exposes seven enabled plugins from immutable Nix store paths:

- File Viewer
- reviewr
- Vim Herdr Navigation
- ghzinga
- Mirror
- jj workspace
- Pueue dashboard

The wrapper must preserve the mutable Herdr configuration, state, sessions, and unrelated user plugins. Activation and wrapper startup must not build or register plugins.

The following results are not complete:

- Plugin binaries on `PATH` without registered Herdr actions.
- A wrapper that replaces `XDG_CONFIG_HOME` with a read-only store path.
- A startup hook that runs `herdr plugin link` or `herdr plugin install`.
- A bundle that omits the unpublished Pueue plugin.
- A package that removes unrelated entries from the user plugin registry.

## Decisions

### Decision: Load a separate immutable registry

**Choice:** Patch Herdr to read `HERDR_STATIC_PLUGIN_REGISTRY`. Merge this registry with the normal mutable registry whenever Herdr refreshes plugins.

**Rationale:** Herdr keeps its current writable directories. Nix supplies plugin manifests and binaries without runtime registry changes.

The merge core is a pure function over two plugin lists. Static entries replace mutable entries with the same plugin id.

The file-loading shell treats a missing variable as an empty static registry. It reports an unreadable or malformed static registry and keeps valid mutable entries.

Registry updates write only the mutable registry. Their returned runtime view includes the static entries again.

### Decision: Generate registry data with Herdr

**Choice:** Run the patched Herdr binary offline during the Nix bundle build. Link each immutable plugin root into a temporary registry.

**Rationale:** Herdr remains the parser for its manifest format. The generated registry contains canonical action, pane, event, and link-handler data.

The temporary registry never enters the user home. Wrapper startup only reads the generated store file.

### Decision: Build all plugin runtime artifacts with Nix

**Choice:** Build each Rust plugin from a fixed source revision. Copy each binary to the location that its reviewed manifest declares.

**Rationale:** The manifests keep their upstream commands. Plugin actions need no network access or Cargo toolchain at runtime.

The wrapper adds required runtime commands to `PATH`. These commands include Bash, Git, jq, jj, OpenSSH, Pueue, and socat.

### Decision: Vendor the unpublished Pueue source

**Choice:** Copy commit `ed19ba8bc32665ffaca81c8564921e178d755fc9` from `../herdr-plugin-pueue` into the package source.

**Rationale:** The plugin has no remote source. A vendored snapshot gives Nix a portable and fixed build input.

`README.md` will record the local reference and commit. A future remote can replace the snapshot with a fixed fetch.

### Decision: Keep the llm-agents provider

**Choice:** Override and wrap `inputs.llm-agents.packages.${system}.herdr`. Do not add another Herdr flake input.

**Rationale:** The base package source and version remain under the accepted provider. The local patch adds only static registry support.

## Approach Registry

| Family | Mechanism | State | Evidence or blocker |
| --- | --- | --- | --- |
| Startup registration | Run Herdr plugin commands from the wrapper | Rejected | This changes user state and runs plugin lifecycle code at startup. |
| XDG overlay | Replace the Herdr configuration directory with a generated overlay | Rejected | Herdr stores sockets, sessions, logs, and the mutable registry in this directory. |
| Static registry | Merge one read-only registry with the mutable registry | Selected | Herdr already loads canonical registry entries and plugin roots can use store paths. |
| Built-in source changes | Compile every plugin into Herdr core | Rejected | This couples independent plugin releases to Herdr and removes normal plugin boundaries. |

The local VibeThinker review ranked the static registry approach first for purity and upgrade safety. Repository tests remain authoritative.

## Risks / Trade-offs

- A running old Herdr server keeps its old registry until the operator restarts that server.
- Bundled plugins cannot be disabled or removed through the mutable plugin commands.
- A static plugin id replaces a mutable entry with the same id.
- Upstream manifest changes can require new runtime commands or output paths.
- The vendored Pueue snapshot needs a manual update until the repository has a remote.
