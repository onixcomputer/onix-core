# Wrapped Helix directory buffer

Wrapped Helix now ships an oil-style directory buffer backed by `hx-oil`.

## Default actions

Shared keymap defaults keep the existing picker workflow intact:

- `space space` -> Helix file picker (unchanged)
- `space o` -> open a directory buffer for current file's parent directory
- `space a` -> save manifest, apply staged filesystem edits, reload manifest
- `space r` -> refresh manifest from current filesystem state, reload buffer
- `space e` -> open entry under cursor
- `space u` -> open parent directory buffer

`zen` uses the same helper and actions.

## Manifest workflow

Opening a directory buffer creates a helper-owned session file under:

- `$XDG_STATE_HOME/hx-oil/sessions/<session-id>/manifest.hxoil`
- sidecar JSON next to it at `manifest.hxoil.json`

The visible manifest stays plain text:

```text
# hx-oil root: /abs/path/to/dir
# blank lines and comment lines are ignored
subdir/
notes.md
```

Rules:

- one editable entry per non-comment line
- blank lines ignored
- `# ...` lines ignored
- directories use trailing `/`
- entries represent one rooted local directory only
- nested paths like `drafts/note.md` are rejected in v1

## Apply semantics

Editing the manifest stages operations. Nothing touches disk until `space a` (or `hx-oil apply`) runs.

Supported staged edits:

- rename one existing entry inside an unchanged local hunk
- create one or more new files/directories
- delete one or more existing entries

Safety rails:

- reordered existing entries are rejected
- ambiguous multi-entry hunks are rejected; apply one local change at a time
- duplicate target names are rejected
- non-empty directory deletes are rejected
- stale snapshots are rejected if directory contents changed outside the session
- missing sidecars fail with a reopen instruction

Dry-run is available from shell:

```bash
hx-oil apply --dry-run ~/.local/state/hx-oil/sessions/<id>/manifest.hxoil
```

## Refresh behavior

`space r` throws away staged text edits in the manifest buffer and regenerates the listing from the live directory snapshot. Use it after external filesystem changes or after a stale-snapshot refusal.

Successful apply also rewrites the manifest to the new canonical state, so `:reload` shows the refreshed directory immediately.

## Navigation behavior

- `space e` on a file entry opens that file
- `space e` on a directory entry opens a new manifest buffer rooted there
- `space e` on comment lines, blank lines, or out-of-range lines is a no-op
- `space u` opens the parent directory buffer

## Rollout / fallback

This is additive. Existing Helix picker and explorer commands still work.

If `hx-oil` refuses an edit pattern, fall back to one of these:

- apply one rename/create/delete hunk at a time in the manifest
- refresh the manifest and retry
- use the existing picker/explorer flow for one-off navigation
- use shell moves/removals for cases outside v1 scope
