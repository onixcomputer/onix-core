## Context

`hx-oil` v1 intentionally kept the model simple: one rooted directory per buffer, ordered entries as rename identity, and explicit apply for create/rename/delete. That simplicity let us ship quickly, but it means several Dired-class workflows still fall back to shell commands:

- collect a transient selection set
- mark deletes without deleting lines yet
- copy or move selected entries into another nearby directory
- run a predictable rename transform over many files
- peek into a child directory without losing parent context

We want those gains without abandoning the safety properties from v1: explicit preview/apply, stale-snapshot detection, and deterministic refusal of ambiguous edits.

## Goals / Non-Goals

**Goals**
- Add a visible mark/flag model that works with editable directory manifests.
- Add explicit bulk operations over marked entries with dry-run-style previews.
- Support target-aware copy/move/link operations without forcing users to type full paths every time.
- Add inline child-directory insertion/collapse and subtree refresh.
- Keep all destructive mutations explicit rather than triggering on arbitrary buffer writes.

**Non-Goals**
- Full recursive tree editor across arbitrary depth by default.
- Remote/TRAMP-style adapters.
- Implicit background mutation on save.
- Full parity with every Dired command (permissions, printing, compression, crypto, etc.).
- Arbitrary structural tree reordering inside one manifest.

## Decisions

### 1. Extend the manifest with a visible in-band action prefix column

**Choice:** Marks, delete flags, and inserted-subdir delimiters are stored in-band in the manifest text. Each editable entry line will gain a helper-managed visible prefix:

```text
# hx-oil root: /abs/path
# marks and flags are explicit; blank/comment lines ignored
  notes.md
* draft.md
D old.txt
  subdir/
```

Prefix meanings:
- `␠` (space) -> unmarked entry
- `*` -> marked entry for bulk operations
- `D` -> flagged delete

The prefix is part of the manifest grammar, not hidden metadata. Comments still begin with `#`, and directory entries still use trailing `/`. The helper parser strips exactly one valid prefix plus one following space before interpreting the entry name, so users may edit the prefix intentionally but cannot accidentally turn it into a literal filename fragment without failing manifest validation.

**Rationale:** Dired's mark-vs-flag distinction is one of its biggest ergonomic wins. A visible prefix keeps the model Helix-friendly and avoids hidden IDs or side channels.

**Alternative:** Keep marks only in sidecar state and leave the text untouched. Rejected because state would feel invisible and fragile in an editor-centered workflow.

### 2. Keep inline text edits and flags as staged state, but move bulk ops to explicit commands

**Choice:** Inline line edits still stage rename/create/delete work rooted in the visible manifest. Marks and flags extend the staged state, but bulk copy/move/link/transform commands remain explicit helper subcommands that update the manifest and/or filesystem only after preview/confirmation points defined by the wrapper.

Examples:
- `hx-oil apply` -> apply staged inline edits + flagged deletes
- `hx-oil mark-toggle ...` / `hx-oil flag-delete ...` -> mutate manifest prefixes only
- `hx-oil op copy --manifest ... --target ...`
- `hx-oil op move --manifest ... --target ...`
- `hx-oil transform regex --manifest ... --pattern ... --replace ...`

**Rationale:** v1 safety came from explicit transitions. Dired-inspired power should not turn the buffer into a live filesystem mutation surface.

**Alternative:** Treat marks/flags as immediate actions. Rejected because it would blur the preview/apply boundary and make failures harder to recover from.

### 3. Use marked-entry lists from the sidecar plus current manifest text, not positional hacks alone

**Choice:** The sidecar will grow explicit per-entry stable IDs for v2 operations, while keeping v1 ordered identity rules for raw text-edit hunks. Marks, flags, inserted subdir blocks, and transform previews will reference these stable IDs.

**Rationale:** Once we add inline subdirs and bulk transforms, order alone stops being a strong enough identity signal. Stable sidecar IDs let us preserve v1 behavior for plain rename hunks while giving richer commands a safer anchor.

**Alternative:** Continue using only ordered-entry identity. Rejected because inline subdir insertion and batch transforms make ambiguity much more common.

### 4. Infer bulk-operation targets from explicit arg first, then another open directory buffer

**Choice:** Target resolution order for copy/move/link commands:
1. explicit target path argument
2. explicit target manifest path argument
3. a wrapper-provided `--alternate-manifest <path>` hint
4. current manifest root as the fallback target

Wrapper integration will surface DWIM target selection using another open `hx-oil` manifest when Helix state can provide one. The concrete wrapper/helper contract is an explicit `--alternate-manifest <path>` CLI argument populated from wrapper-managed session state that records the most recently focused other manifest. Helper commands still accept explicit targets so the feature remains testable outside Helix.

When multiple alternate manifests are available, the wrapper will pass the most recently focused alternate manifest as the DWIM target. If no alternate manifest exists, the helper falls back to the current root and the preview must say so explicitly.

**Rationale:** Dired's `dired-dwim-target` behavior is useful, but the helper should not depend entirely on Helix window inspection magic.

**Alternative:** Hardcode current root only. Rejected because it kills the value of batch move/copy.

### 5. Represent inline subdirectory insertion as helper-owned block headers

**Choice:** Inserted child directories will appear in the same manifest as helper-managed blocks:

```text
# hx-oil root: /abs/path
  top.txt
  drafts/
# hx-oil subdir: drafts
    a.md
    b.md
# hx-oil end-subdir: drafts
```

- only helper commands may create/remove these block headers
- nested insertion depth is capped at one inserted child level for this change
- inline entries are indented for display, but operations still target a concrete subdir root tracked in sidecar metadata
- apply/transform/mark operations may target entries inside inserted child blocks, but they may not move entries across subtree boundaries in one step

**Rationale:** This preserves the "single text buffer" UX while making subtree boundaries explicit and machine-parseable.

**Alternative:** Full recursive tree by default. Rejected because it complicates apply semantics too early.

### 6. Bulk transforms must preview before rewriting names

**Choice:** Regex/prefix/suffix/case transforms produce a preview buffer/state first. The helper must reject collisions, no-op ambiguities, or cross-directory escapes before touching disk or mutating canonical manifest state.

**Rationale:** Batch rename power is exactly where accidental damage grows. Preview-first matches the explicit-apply philosophy.

Transform parameters will be provided through explicit helper commands invoked by wrapper-managed shell actions, not an in-editor prompt widget. The wrapper can expose a few common transforms directly (prefix, suffix, lower, upper), and regex replacement will pass explicit CLI args entered through the Helix command line.

**Alternative:** Apply the transform directly to all marked lines. Rejected because it is too easy to create collisions silently.

### 7. Bulk operations halt on first execution error and rely on prevalidation, not rollback

**Choice:** Bulk ops will prevalidate as much as possible up front (stale snapshot, duplicate outputs, missing targets, unsupported subtree mixes). If execution still fails mid-run because of an external condition like permissions, the helper halts immediately, reports what completed and what did not, and refuses automatic rollback.

**Rationale:** Full rollback across copy/move/link mixes is complex and outside scope. Halt-on-error plus strong prevalidation keeps the behavior understandable.

**Alternative:** Best-effort skip-and-continue or transactional rollback. Rejected for v1 of this change because both complicate reasoning and recovery.

## Risks / Trade-offs

- **Visible prefixes add syntax noise** -> acceptable because Dired-like power depends on explicit marks/flags.
- **Stable IDs are a format evolution** -> migration logic must refresh or reopen old v1 manifests cleanly.
- **Inline subdirs increase parsing complexity** -> block headers and depth limits keep the grammar deterministic.
- **DWIM target inference can surprise users** -> always show resolved target in preview output.
- **Transform preview adds another step** -> better than silent multi-file damage.

## Migration Plan

1. Extend sidecar/session format with entry IDs and subdir metadata while preserving reopen/refresh for old manifests. Old v1 manifests without prefix columns must be auto-refreshed into the v2 in-band format when reopened.
2. Add manifest prefix parsing/rendering plus mark/flag commands.
3. Add bulk operation planning/execution for copy/move/link with explicit target resolution and previews.
4. Add transform preview/apply commands for marked entries.
5. Add inline subdir insert/refresh/collapse behavior.
6. Wire commands and keybindings into `hx` and `zen`.
7. Add helper tests, flake integration checks, and docs.
