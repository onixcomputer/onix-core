# Wrapped Helix directory buffer

Wrapped Helix ships an oil-style directory buffer backed by `hx-oil`.

## Default actions

Shared keymap defaults keep picker workflow intact while adding Dired-style helpers:

- `space space` -> Helix file picker
- `space o` -> open directory buffer for current file's parent directory
- `space a` -> save manifest, apply staged edits, reload buffer
- `space r` -> refresh whole manifest from live filesystem state
- `space e` -> open entry under cursor
- `space u` -> open parent directory buffer
- `space m` -> toggle mark on current entry
- `space x` -> toggle delete flag on current entry
- `space c` -> clear marks and keep delete flags / text edits
- `space y` / `space Y` -> preview / execute bulk copy for marked entries
- `space v` / `space V` -> preview / execute bulk move for marked entries
- `space s` / `space S` -> preview / execute bulk symlink for marked entries
- `space n` / `space N` -> preview / execute bulk relative-symlink for marked entries
- `space l` / `space L` -> preview / execute lowercase transform for marked entries
- `space h` / `space H` -> preview / execute uppercase transform for marked entries
- `space i` -> insert child directory inline
- `space j` -> refresh inserted child subtree under cursor
- `space k` -> collapse inserted child subtree under cursor

`zen` uses same helper and bindings.

## Manifest workflow

Opening a directory buffer creates a helper-owned session under:

- `$XDG_STATE_HOME/hx-oil/sessions/<session-id>/manifest.hxoil`
- sidecar JSON next to it at `manifest.hxoil.json`
- remembered DWIM target at `$XDG_STATE_HOME/hx-oil/alternate-manifest`

Visible manifest stays plain text:

```text
# hx-oil root: /abs/path/to/dir
# blank lines and comment lines are ignored
  drafts/
* notes.md
D old.txt
```

Rules:

- every entry line uses visible prefix column
  - `"  "` -> normal entry
  - `"* "` -> marked entry for bulk ops / transforms
  - `"D "` -> delete-flagged entry
- blank lines and `# ...` comments ignored
- directories keep trailing `/`
- nested path text like `drafts/note.md` is rejected
- pre-v2 manifests reopen/refresh into prefixed v2 form automatically

## Apply semantics

Editing manifest stages filesystem changes. Nothing touches disk until `space a` or `hx-oil apply` runs.

Supported staged edits:

- rename one existing entry inside unchanged local hunk
- create new files or directories
- stage deletes either by removing lines or by `D ` delete flags
- edit inserted child subtrees in place, scoped to that child root

Safety rails:

- reordered existing entries rejected
- ambiguous multi-entry hunks rejected
- duplicate targets rejected
- stale snapshots rejected before mutation
- missing sidecars fail with reopen instruction
- non-empty directory deletes rejected
- inserted subdir roots must stay anchored; unsafe subtree mutations rejected

Dry-run stays available from shell:

```bash
hx-oil apply --dry-run ~/.local/state/hx-oil/sessions/<id>/manifest.hxoil
```

## Bulk ops and transforms

Marks are transient selection state. Bulk copy/move/link actions read only marked entries.

Target resolution order:

1. explicit helper `--target`
2. explicit helper `--target-manifest`
3. wrapper-managed remembered alternate directory buffer
4. current manifest root

Preview commands print resolved target before execution. Example shell usage:

```bash
hx-oil op copy ~/.local/state/hx-oil/sessions/<id>/manifest.hxoil
hx-oil op move ~/.local/state/hx-oil/sessions/<id>/manifest.hxoil --execute
hx-oil transform regex ~/.local/state/hx-oil/sessions/<id>/manifest.hxoil \
  --pattern '^draft-' --replace 'final-' 
```

Current wrapped Helix bindings expose common preview/apply loops for copy, move, symlink, relative symlink, lower-case, and upper-case transforms. Prefix / suffix / regex transforms remain available through direct helper commands.

## Inline subdirectories

`space i` on a root-level directory inserts helper-owned block markers inline:

```text
# hx-oil subdir: drafts
      a.md
      b.md
# hx-oil end-subdir: drafts
```

Behavior:

- one inserted child-directory level only
- `space j` refreshes only subtree under cursor
- `space k` collapses subtree under cursor
- marks, flags, renames, creates, and deletes inside subtree stay scoped to child root
- deeper nested insertion is refused

## Navigation and refresh behavior

- `space e` on file entry opens file
- `space e` on directory entry opens standalone directory buffer rooted there
- `space e` on comment / blank / block marker line is no-op
- `space u` opens parent directory buffer
- `space r` throws away staged edits and regenerates full manifest from live state
- successful apply / bulk execute / transform execute rewrites manifest to canonical state

## Rollout / fallback

Additive feature. Existing picker and explorer commands still work.

If `hx-oil` refuses an edit pattern:

- apply one rename/create/delete hunk at a time
- refresh manifest and retry
- use direct helper preview commands from shell for explicit target / regex cases
- fall back to picker, explorer, or shell for workflows outside bounded scope
