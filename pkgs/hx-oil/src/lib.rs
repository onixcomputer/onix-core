use std::collections::{HashMap, HashSet};
use std::fmt::Write as _;
use std::fs::{self, OpenOptions};
use std::path::{Path, PathBuf};
use std::process;
use std::sync::atomic::{AtomicU64, Ordering};
use std::time::{Duration, SystemTime, UNIX_EPOCH};

use anyhow::{Context, Result, bail, ensure};
use serde::{Deserialize, Serialize};

pub const MANIFEST_FILE_NAME: &str = "manifest.hxoil";
pub const SIDECAR_FILE_NAME: &str = "manifest.hxoil.json";
pub const SESSION_RETENTION: Duration = Duration::from_secs(7 * 24 * 60 * 60);

static SESSION_COUNTER: AtomicU64 = AtomicU64::new(0);

#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum EntryKind {
    File,
    Directory,
}

impl EntryKind {
    fn label(self) -> &'static str {
        match self {
            Self::File => "FILE",
            Self::Directory => "DIR",
        }
    }

    fn render_path(self, path: &str) -> String {
        match self {
            Self::File => path.to_owned(),
            Self::Directory => format!("{path}/"),
        }
    }
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct SnapshotEntry {
    pub index: usize,
    pub relative_path: String,
    pub kind: EntryKind,
    pub mtime_ns: u64,
    pub size: u64,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct ManifestEntry {
    pub relative_path: String,
    pub kind: EntryKind,
    pub line_number: usize,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Sidecar {
    pub root: PathBuf,
    pub manifest_path: PathBuf,
    pub created_at: u64,
    pub entries: Vec<SnapshotEntry>,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub enum Operation {
    Create {
        path: String,
        kind: EntryKind,
    },
    Rename {
        from: String,
        to: String,
        kind: EntryKind,
    },
    Delete {
        path: String,
        kind: EntryKind,
    },
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct Plan {
    pub root: PathBuf,
    pub operations: Vec<Operation>,
    pub final_entries: Vec<ManifestEntry>,
}

#[derive(Debug, Clone)]
pub struct Session {
    pub manifest_path: PathBuf,
    pub sidecar_path: PathBuf,
    pub sidecar: Sidecar,
}

pub fn xdg_state_home() -> Result<PathBuf> {
    if let Some(path) = std::env::var_os("XDG_STATE_HOME") {
        return Ok(PathBuf::from(path));
    }

    let home = std::env::var_os("HOME").context("$HOME is not set")?;
    Ok(PathBuf::from(home).join(".local/state"))
}

pub fn sessions_root(state_home: &Path) -> PathBuf {
    state_home.join("hx-oil").join("sessions")
}

pub fn ensure_gc(state_home: &Path) -> Result<usize> {
    gc_sessions_at(state_home, SystemTime::now())
}

pub fn gc_sessions_at(state_home: &Path, now: SystemTime) -> Result<usize> {
    let sessions = sessions_root(state_home);
    if !sessions.exists() {
        return Ok(0);
    }

    let cutoff = now
        .checked_sub(SESSION_RETENTION)
        .unwrap_or(UNIX_EPOCH + Duration::from_secs(0));
    let mut removed = 0;

    for entry in fs::read_dir(&sessions)
        .with_context(|| format!("failed to read session root {}", sessions.display()))?
    {
        let entry = entry?;
        let path = entry.path();
        if !entry.file_type()?.is_dir() {
            continue;
        }

        let modified = entry.metadata()?.modified().unwrap_or(now);
        if modified < cutoff {
            fs::remove_dir_all(&path)
                .with_context(|| format!("failed to remove stale session {}", path.display()))?;
            removed += 1;
        }
    }

    Ok(removed)
}

pub fn resolve_root(from: &Path) -> Result<PathBuf> {
    let metadata =
        fs::metadata(from).with_context(|| format!("failed to inspect {}", from.display()))?;
    let path = if metadata.is_dir() {
        from
    } else {
        from.parent()
            .context("input file has no parent directory")?
    };
    path.canonicalize()
        .with_context(|| format!("failed to canonicalize {}", path.display()))
}

pub fn render_session(from: &Path, state_home: &Path) -> Result<PathBuf> {
    let root = resolve_root(from)?;
    let session_dir = create_session_dir(state_home)?;
    let manifest_path = session_dir.join(MANIFEST_FILE_NAME);
    write_session_files(&root, &manifest_path)
}

pub fn refresh_session(manifest_path: &Path) -> Result<PathBuf> {
    let session = load_session(manifest_path)?;
    write_session_files(&session.sidecar.root, manifest_path)
}

pub fn parent_session(manifest_path: &Path, state_home: &Path) -> Result<PathBuf> {
    let session = load_session(manifest_path)?;
    let parent = session
        .sidecar
        .root
        .parent()
        .unwrap_or(session.sidecar.root.as_path());
    render_session(parent, state_home)
}

pub fn open_at_line(
    manifest_path: &Path,
    line_number: usize,
    state_home: &Path,
) -> Result<PathBuf> {
    let session = load_session(manifest_path)?;
    let content = fs::read_to_string(manifest_path)
        .with_context(|| format!("failed to read manifest {}", manifest_path.display()))?;
    let lines: Vec<&str> = content.lines().collect();

    let Some(line) = line_number
        .checked_sub(1)
        .and_then(|index| lines.get(index).copied())
    else {
        return Ok(manifest_path.to_path_buf());
    };

    if should_ignore_manifest_line(line) {
        return Ok(manifest_path.to_path_buf());
    }

    let entry = parse_manifest_entry_line(line_number, line)?;
    let target = session.sidecar.root.join(&entry.relative_path);

    match entry.kind {
        EntryKind::File => Ok(target),
        EntryKind::Directory => {
            ensure!(
                target.is_dir(),
                "directory entry {} does not exist yet; apply the manifest first",
                entry.kind.render_path(&entry.relative_path)
            );
            render_session(&target, state_home)
        }
    }
}

pub fn dry_run_apply(manifest_path: &Path) -> Result<String> {
    let session = load_session(manifest_path)?;
    validate_manifest_header(manifest_path, &session.sidecar.root)?;
    validate_current_snapshot(&session)?;
    let edited_entries = parse_manifest_file(manifest_path)?;
    validate_entries(&edited_entries)?;
    let plan = build_plan(
        &session.sidecar.root,
        &session.sidecar.entries,
        &edited_entries,
    )?;
    Ok(render_plan(&plan))
}

pub fn apply_manifest(manifest_path: &Path) -> Result<String> {
    let session = load_session(manifest_path)?;
    validate_manifest_header(manifest_path, &session.sidecar.root)?;
    validate_current_snapshot(&session)?;
    let edited_entries = parse_manifest_file(manifest_path)?;
    validate_entries(&edited_entries)?;
    let plan = build_plan(
        &session.sidecar.root,
        &session.sidecar.entries,
        &edited_entries,
    )?;
    validate_apply_targets(&session.sidecar.root, &plan)?;
    execute_plan(&session.sidecar.root, &plan)?;
    write_session_files(&session.sidecar.root, manifest_path)?;
    Ok(render_plan(&plan))
}

pub fn parse_manifest_text(text: &str) -> Result<Vec<ManifestEntry>> {
    text.lines()
        .enumerate()
        .filter_map(|(index, line)| {
            if should_ignore_manifest_line(line) {
                None
            } else {
                Some(parse_manifest_entry_line(index + 1, line))
            }
        })
        .collect()
}

pub fn parse_manifest_file(manifest_path: &Path) -> Result<Vec<ManifestEntry>> {
    let content = fs::read_to_string(manifest_path)
        .with_context(|| format!("failed to read manifest {}", manifest_path.display()))?;
    parse_manifest_text(&content)
}

pub fn render_manifest(root: &Path, entries: &[SnapshotEntry]) -> String {
    let mut rendered = String::new();
    let _ = writeln!(rendered, "# hx-oil root: {}", root.display());
    let _ = writeln!(rendered, "# blank lines and comment lines are ignored");

    for entry in entries {
        let _ = writeln!(rendered, "{}", entry.kind.render_path(&entry.relative_path));
    }

    rendered
}

pub fn collect_snapshot(root: &Path) -> Result<Vec<SnapshotEntry>> {
    let mut entries = Vec::new();

    for entry in fs::read_dir(root).with_context(|| format!("failed to read {}", root.display()))? {
        let entry = entry?;
        let relative_path = entry.file_name().into_string().map_err(|_| {
            anyhow::anyhow!("non-utf8 entry under {} is unsupported", root.display())
        })?;
        let file_type = entry.file_type()?;
        let metadata = entry.metadata()?;
        let kind = if file_type.is_dir() {
            EntryKind::Directory
        } else {
            EntryKind::File
        };

        entries.push(SnapshotEntry {
            index: 0,
            relative_path,
            kind,
            mtime_ns: metadata_mtime_ns(&metadata)?,
            size: metadata.len(),
        });
    }

    entries.sort_by(|left, right| {
        kind_sort_key(left.kind)
            .cmp(&kind_sort_key(right.kind))
            .then_with(|| left.relative_path.cmp(&right.relative_path))
    });

    for (index, entry) in entries.iter_mut().enumerate() {
        entry.index = index;
    }

    Ok(entries)
}

pub fn load_session(manifest_path: &Path) -> Result<Session> {
    let sidecar_path = sidecar_path_for(manifest_path);
    if !sidecar_path.exists() {
        bail!(
            "missing sidecar for {}; reopen the directory buffer with hx-oil render",
            manifest_path.display()
        );
    }

    let sidecar = serde_json::from_str::<Sidecar>(
        &fs::read_to_string(&sidecar_path)
            .with_context(|| format!("failed to read sidecar {}", sidecar_path.display()))?,
    )
    .with_context(|| format!("failed to parse sidecar {}", sidecar_path.display()))?;

    ensure!(
        sidecar.manifest_path == manifest_path,
        "sidecar path mismatch for {}; reopen the directory buffer",
        manifest_path.display()
    );

    Ok(Session {
        manifest_path: manifest_path.to_path_buf(),
        sidecar_path,
        sidecar,
    })
}

pub fn session_dir_for_manifest(manifest_path: &Path) -> Result<PathBuf> {
    manifest_path
        .parent()
        .map(Path::to_path_buf)
        .context("manifest path has no parent directory")
}

pub fn sidecar_path_for(manifest_path: &Path) -> PathBuf {
    manifest_path.with_extension("hxoil.json")
}

fn write_session_files(root: &Path, manifest_path: &Path) -> Result<PathBuf> {
    let entries = collect_snapshot(root)?;
    let sidecar = Sidecar {
        root: root.to_path_buf(),
        manifest_path: manifest_path.to_path_buf(),
        created_at: SystemTime::now()
            .duration_since(UNIX_EPOCH)
            .context("system clock is before unix epoch")?
            .as_secs(),
        entries: entries.clone(),
    };
    let sidecar_path = sidecar_path_for(manifest_path);

    fs::create_dir_all(
        manifest_path
            .parent()
            .context("manifest path has no parent directory")?,
    )
    .with_context(|| format!("failed to create {}", manifest_path.display()))?;
    fs::write(manifest_path, render_manifest(root, &entries))
        .with_context(|| format!("failed to write manifest {}", manifest_path.display()))?;
    fs::write(&sidecar_path, serde_json::to_vec_pretty(&sidecar)?)
        .with_context(|| format!("failed to write sidecar {}", sidecar_path.display()))?;
    Ok(manifest_path.to_path_buf())
}

fn create_session_dir(state_home: &Path) -> Result<PathBuf> {
    let sessions = sessions_root(state_home);
    fs::create_dir_all(&sessions)
        .with_context(|| format!("failed to create {}", sessions.display()))?;

    for _ in 0..32 {
        let session_dir = sessions.join(new_session_id()?);
        match fs::create_dir(&session_dir) {
            Ok(()) => return Ok(session_dir),
            Err(error) if error.kind() == std::io::ErrorKind::AlreadyExists => continue,
            Err(error) => {
                return Err(error).with_context(|| {
                    format!("failed to create session {}", session_dir.display())
                });
            }
        }
    }

    bail!("failed to allocate a unique hx-oil session directory")
}

fn new_session_id() -> Result<String> {
    let now = SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .context("system clock is before unix epoch")?;
    let counter = SESSION_COUNTER.fetch_add(1, Ordering::Relaxed);
    Ok(format!(
        "{}-{:09}-{}-{}",
        now.as_secs(),
        now.subsec_nanos(),
        process::id(),
        counter
    ))
}

fn validate_manifest_header(manifest_path: &Path, expected_root: &Path) -> Result<()> {
    let content = fs::read_to_string(manifest_path)
        .with_context(|| format!("failed to read manifest {}", manifest_path.display()))?;
    let Some(header) = content.lines().next() else {
        bail!("manifest {} is empty", manifest_path.display());
    };
    let Some(root) = header.strip_prefix("# hx-oil root: ") else {
        bail!(
            "manifest {} is missing the hx-oil root header; reopen the directory buffer",
            manifest_path.display()
        );
    };
    ensure!(
        Path::new(root) == expected_root,
        "manifest root header does not match the sidecar for {}; reopen the directory buffer",
        manifest_path.display()
    );
    Ok(())
}

fn validate_current_snapshot(session: &Session) -> Result<()> {
    let current = collect_snapshot(&session.sidecar.root)?;
    ensure!(
        current == session.sidecar.entries,
        "stale snapshot for {}; refresh or reopen the directory buffer before applying",
        session.sidecar.root.display()
    );
    Ok(())
}

fn validate_entries(entries: &[ManifestEntry]) -> Result<()> {
    let mut seen = HashSet::new();
    for entry in entries {
        validate_entry_name(&entry.relative_path, entry.kind, entry.line_number)?;
        ensure!(
            seen.insert(entry.relative_path.clone()),
            "duplicate target path in manifest: {}",
            entry.kind.render_path(&entry.relative_path)
        );
    }
    Ok(())
}

fn validate_entry_name(name: &str, kind: EntryKind, line_number: usize) -> Result<()> {
    ensure!(
        !name.is_empty(),
        "line {line_number}: empty entry is not allowed"
    );
    ensure!(
        name == name.trim(),
        "line {line_number}: leading or trailing whitespace is unsupported"
    );
    ensure!(
        !name.contains('/'),
        "line {line_number}: nested paths are unsupported in v1"
    );
    ensure!(
        name != "." && name != "..",
        "line {line_number}: '.' and '..' are not valid hx-oil entries"
    );
    ensure!(
        !name.starts_with('#'),
        "line {line_number}: entry names starting with '#' are unsupported"
    );
    if matches!(kind, EntryKind::Directory) {
        ensure!(
            !name.ends_with('/'),
            "line {line_number}: directory marker may only appear once"
        );
    }
    Ok(())
}

fn build_plan(root: &Path, original: &[SnapshotEntry], edited: &[ManifestEntry]) -> Result<Plan> {
    let mut exact_positions = HashMap::new();
    for (index, entry) in original.iter().enumerate() {
        exact_positions.insert((entry.relative_path.clone(), entry.kind), index);
    }

    let mut exact_matches = Vec::new();
    let mut last_original_index = None;

    for (edited_index, entry) in edited.iter().enumerate() {
        if let Some(&original_index) =
            exact_positions.get(&(entry.relative_path.clone(), entry.kind))
        {
            if let Some(previous) = last_original_index {
                ensure!(
                    original_index > previous,
                    "unsupported reordering: existing entries must keep their original order; apply one local rename/create/delete hunk at a time"
                );
            }
            last_original_index = Some(original_index);
            exact_matches.push((original_index, edited_index));
        }
    }

    let mut operations = Vec::new();
    let mut original_start = 0usize;
    let mut edited_start = 0usize;

    for (original_index, edited_index) in exact_matches
        .iter()
        .copied()
        .chain(std::iter::once((original.len(), edited.len())))
    {
        let original_hunk = &original[original_start..original_index];
        let edited_hunk = &edited[edited_start..edited_index];
        plan_hunk(original_hunk, edited_hunk, &mut operations)?;

        original_start = if original_index < original.len() {
            original_index + 1
        } else {
            original_index
        };
        edited_start = if edited_index < edited.len() {
            edited_index + 1
        } else {
            edited_index
        };
    }

    Ok(Plan {
        root: root.to_path_buf(),
        operations,
        final_entries: edited.to_vec(),
    })
}

fn plan_hunk(
    original_hunk: &[SnapshotEntry],
    edited_hunk: &[ManifestEntry],
    operations: &mut Vec<Operation>,
) -> Result<()> {
    match (original_hunk.len(), edited_hunk.len()) {
        (0, 0) => Ok(()),
        (0, _) => {
            operations.extend(edited_hunk.iter().map(|entry| Operation::Create {
                path: entry.relative_path.clone(),
                kind: entry.kind,
            }));
            Ok(())
        }
        (_, 0) => {
            operations.extend(original_hunk.iter().map(|entry| Operation::Delete {
                path: entry.relative_path.clone(),
                kind: entry.kind,
            }));
            Ok(())
        }
        (1, 1) => {
            let original = &original_hunk[0];
            let edited = &edited_hunk[0];
            ensure!(
                original.kind == edited.kind,
                "unsupported kind change: {} cannot become {} in-place",
                original.kind.render_path(&original.relative_path),
                edited.kind.render_path(&edited.relative_path)
            );
            operations.push(Operation::Rename {
                from: original.relative_path.clone(),
                to: edited.relative_path.clone(),
                kind: original.kind,
            });
            Ok(())
        }
        _ => bail!(
            "ambiguous edit hunk: {} original entries vs {} edited entries; keep original order and apply one local rename/create/delete hunk at a time",
            original_hunk.len(),
            edited_hunk.len()
        ),
    }
}

fn validate_apply_targets(root: &Path, plan: &Plan) -> Result<()> {
    let current_paths: HashSet<String> = collect_snapshot(root)?
        .into_iter()
        .map(|entry| entry.relative_path)
        .collect();
    let delete_paths: HashSet<String> = plan
        .operations
        .iter()
        .filter_map(|operation| match operation {
            Operation::Delete { path, .. } => Some(path.clone()),
            _ => None,
        })
        .collect();

    for operation in &plan.operations {
        if let Operation::Delete {
            path,
            kind: EntryKind::Directory,
        } = operation
        {
            let absolute_path = root.join(path);
            ensure!(
                is_directory_empty(&absolute_path)?,
                "refusing to delete non-empty directory {}",
                absolute_path.display()
            );
        }
    }

    for operation in &plan.operations {
        match operation {
            Operation::Create { path, .. } => {
                if current_paths.contains(path) && !delete_paths.contains(path) {
                    bail!("target already exists: {}", root.join(path).display());
                }
            }
            Operation::Rename { from, to, .. } => {
                if from == to {
                    continue;
                }
                if current_paths.contains(to) && !delete_paths.contains(to) {
                    bail!("rename target already exists: {}", root.join(to).display());
                }
            }
            Operation::Delete { .. } => {}
        }
    }

    Ok(())
}

fn execute_plan(root: &Path, plan: &Plan) -> Result<()> {
    for operation in &plan.operations {
        if let Operation::Delete { path, kind } = operation {
            let absolute_path = root.join(path);
            match kind {
                EntryKind::File => fs::remove_file(&absolute_path),
                EntryKind::Directory => fs::remove_dir(&absolute_path),
            }
            .with_context(|| format!("failed to delete {}", absolute_path.display()))?;
        }
    }

    for operation in &plan.operations {
        if let Operation::Rename { from, to, .. } = operation {
            let from_path = root.join(from);
            let to_path = root.join(to);
            fs::rename(&from_path, &to_path).with_context(|| {
                format!(
                    "failed to rename {} to {}",
                    from_path.display(),
                    to_path.display()
                )
            })?;
        }
    }

    for operation in &plan.operations {
        if let Operation::Create { path, kind } = operation {
            let absolute_path = root.join(path);
            match kind {
                EntryKind::File => {
                    OpenOptions::new()
                        .write(true)
                        .create_new(true)
                        .open(&absolute_path)
                        .with_context(|| format!("failed to create {}", absolute_path.display()))?;
                }
                EntryKind::Directory => fs::create_dir(&absolute_path)
                    .with_context(|| format!("failed to create {}", absolute_path.display()))?,
            }
        }
    }

    Ok(())
}

fn render_plan(plan: &Plan) -> String {
    if plan.operations.is_empty() {
        return "No changes.\n".to_owned();
    }

    let mut rendered = String::new();
    for operation in &plan.operations {
        match operation {
            Operation::Create { path, kind } => {
                let _ = writeln!(
                    rendered,
                    "CREATE {} {}",
                    kind.label(),
                    kind.render_path(path)
                );
            }
            Operation::Rename { from, to, kind } => {
                let _ = writeln!(
                    rendered,
                    "RENAME {} {} -> {}",
                    kind.label(),
                    kind.render_path(from),
                    kind.render_path(to)
                );
            }
            Operation::Delete { path, kind } => {
                let _ = writeln!(
                    rendered,
                    "DELETE {} {}",
                    kind.label(),
                    kind.render_path(path)
                );
            }
        }
    }

    rendered
}

fn parse_manifest_entry_line(line_number: usize, line: &str) -> Result<ManifestEntry> {
    let (relative_path, kind) = if let Some(path) = line.strip_suffix('/') {
        (path.to_owned(), EntryKind::Directory)
    } else {
        (line.to_owned(), EntryKind::File)
    };

    Ok(ManifestEntry {
        relative_path,
        kind,
        line_number,
    })
}

fn should_ignore_manifest_line(line: &str) -> bool {
    line.trim().is_empty() || line.starts_with('#')
}

fn metadata_mtime_ns(metadata: &fs::Metadata) -> Result<u64> {
    let duration = metadata
        .modified()
        .context("failed to read mtime")?
        .duration_since(UNIX_EPOCH)
        .context("mtime is before unix epoch")?;
    let nanos = duration.as_nanos();
    u64::try_from(nanos).context("mtime does not fit into u64")
}

fn kind_sort_key(kind: EntryKind) -> u8 {
    match kind {
        EntryKind::Directory => 0,
        EntryKind::File => 1,
    }
}

fn is_directory_empty(path: &Path) -> Result<bool> {
    Ok(fs::read_dir(path)
        .with_context(|| format!("failed to inspect {}", path.display()))?
        .next()
        .is_none())
}

#[cfg(test)]
mod tests {
    use super::*;
    use filetime::{FileTime, set_file_mtime};
    use tempfile::TempDir;

    fn sandbox() -> Result<(TempDir, PathBuf, PathBuf)> {
        let temp = TempDir::new()?;
        let root = temp.path().join("root");
        let state = temp.path().join("state");
        fs::create_dir_all(&root)?;
        fs::create_dir_all(&state)?;
        Ok((temp, root, state))
    }

    fn touch_file(path: &Path, contents: &str) -> Result<()> {
        fs::write(path, contents).with_context(|| format!("failed to write {}", path.display()))
    }

    fn render(root: &Path, state: &Path) -> Result<PathBuf> {
        render_session(root, state)
    }

    fn write_manifest_entries(manifest_path: &Path, lines: &[&str]) -> Result<()> {
        let session = load_session(manifest_path)?;
        let mut rendered = format!("# hx-oil root: {}\n", session.sidecar.root.display());
        rendered.push_str("# blank lines and comment lines are ignored\n");
        for line in lines {
            rendered.push_str(line);
            rendered.push('\n');
        }
        fs::write(manifest_path, rendered)?;
        Ok(())
    }

    #[test]
    fn render_and_parse_manifest_round_trip() -> Result<()> {
        let (_temp, root, state) = sandbox()?;
        fs::create_dir(root.join("drafts"))?;
        touch_file(&root.join("notes.md"), "hi")?;

        let manifest = render(&root, &state)?;
        let rendered = fs::read_to_string(&manifest)?;

        assert!(rendered.contains(&format!("# hx-oil root: {}", root.display())));
        assert!(rendered.contains("drafts/\nnotes.md\n"));

        let parsed = parse_manifest_text(&rendered)?;
        assert_eq!(
            parsed,
            vec![
                ManifestEntry {
                    relative_path: "drafts".to_owned(),
                    kind: EntryKind::Directory,
                    line_number: 3,
                },
                ManifestEntry {
                    relative_path: "notes.md".to_owned(),
                    kind: EntryKind::File,
                    line_number: 4,
                },
            ]
        );
        Ok(())
    }

    #[test]
    fn apply_supports_rename_create_delete_and_directory_create() -> Result<()> {
        let (_temp, root, state) = sandbox()?;
        touch_file(&root.join("alpha.txt"), "a")?;
        touch_file(&root.join("keep.txt"), "k")?;
        touch_file(&root.join("old.txt"), "o")?;
        touch_file(&root.join("tail.txt"), "t")?;

        let manifest = render(&root, &state)?;
        write_manifest_entries(&manifest, &["ideas.txt", "keep.txt", "tail.txt", "drafts/"])?;

        let dry_run = dry_run_apply(&manifest)?;
        assert!(dry_run.contains("RENAME FILE alpha.txt -> ideas.txt"));
        assert!(dry_run.contains("DELETE FILE old.txt"));
        assert!(dry_run.contains("CREATE DIR drafts/"));

        let applied = apply_manifest(&manifest)?;
        assert_eq!(dry_run, applied);
        assert!(root.join("ideas.txt").exists());
        assert!(!root.join("alpha.txt").exists());
        assert!(!root.join("old.txt").exists());
        assert!(root.join("drafts").is_dir());

        let refreshed = fs::read_to_string(&manifest)?;
        assert!(refreshed.contains("drafts/\nideas.txt\nkeep.txt\ntail.txt\n"));
        Ok(())
    }

    #[test]
    fn apply_creates_new_file() -> Result<()> {
        let (_temp, root, state) = sandbox()?;
        touch_file(&root.join("keep.txt"), "k")?;

        let manifest = render(&root, &state)?;
        write_manifest_entries(&manifest, &["keep.txt", "todo.md"])?;

        apply_manifest(&manifest)?;
        assert!(root.join("todo.md").exists());
        Ok(())
    }

    #[test]
    fn reject_reordered_entries() -> Result<()> {
        let (_temp, root, state) = sandbox()?;
        touch_file(&root.join("a.txt"), "a")?;
        touch_file(&root.join("b.txt"), "b")?;

        let manifest = render(&root, &state)?;
        write_manifest_entries(&manifest, &["b.txt", "a.txt"])?;

        let error = dry_run_apply(&manifest).unwrap_err().to_string();
        assert!(error.contains("unsupported reordering"));
        Ok(())
    }

    #[test]
    fn reject_non_empty_directory_delete() -> Result<()> {
        let (_temp, root, state) = sandbox()?;
        fs::create_dir(root.join("folder"))?;
        touch_file(&root.join("folder").join("nested.txt"), "n")?;
        touch_file(&root.join("keep.txt"), "k")?;

        let manifest = render(&root, &state)?;
        write_manifest_entries(&manifest, &["keep.txt"])?;

        let error = apply_manifest(&manifest).unwrap_err().to_string();
        assert!(error.contains("non-empty directory"));
        assert!(root.join("folder").exists());
        Ok(())
    }

    #[test]
    fn reject_duplicate_target_paths() -> Result<()> {
        let (_temp, root, state) = sandbox()?;
        touch_file(&root.join("a.txt"), "a")?;
        touch_file(&root.join("b.txt"), "b")?;

        let manifest = render(&root, &state)?;
        write_manifest_entries(&manifest, &["same.txt", "same.txt"])?;

        let error = dry_run_apply(&manifest).unwrap_err().to_string();
        assert!(error.contains("duplicate target path"));
        Ok(())
    }

    #[test]
    fn reject_missing_sidecar() -> Result<()> {
        let (_temp, root, state) = sandbox()?;
        touch_file(&root.join("keep.txt"), "k")?;

        let manifest = render(&root, &state)?;
        fs::remove_file(sidecar_path_for(&manifest))?;

        let error = apply_manifest(&manifest).unwrap_err().to_string();
        assert!(error.contains("reopen the directory buffer"));
        Ok(())
    }

    #[test]
    fn reject_stale_snapshot() -> Result<()> {
        let (_temp, root, state) = sandbox()?;
        touch_file(&root.join("keep.txt"), "k")?;

        let manifest = render(&root, &state)?;
        write_manifest_entries(&manifest, &["renamed.txt"])?;
        touch_file(&root.join("keep.txt"), "changed")?;

        let error = apply_manifest(&manifest).unwrap_err().to_string();
        assert!(error.contains("stale snapshot"));
        Ok(())
    }

    #[test]
    fn refresh_updates_manifest_after_external_changes() -> Result<()> {
        let (_temp, root, state) = sandbox()?;
        touch_file(&root.join("keep.txt"), "k")?;

        let manifest = render(&root, &state)?;
        touch_file(&root.join("new.txt"), "n")?;

        refresh_session(&manifest)?;
        let refreshed = fs::read_to_string(&manifest)?;
        assert!(refreshed.contains("keep.txt\nnew.txt\n"));
        Ok(())
    }

    #[test]
    fn open_at_line_comment_blank_and_out_of_range_are_noop() -> Result<()> {
        let (_temp, root, state) = sandbox()?;
        touch_file(&root.join("keep.txt"), "k")?;

        let manifest = render(&root, &state)?;
        let noop_comment = open_at_line(&manifest, 1, &state)?;
        let noop_blank = open_at_line(&manifest, 200, &state)?;

        assert_eq!(noop_comment, manifest);
        assert_eq!(noop_blank, manifest);
        Ok(())
    }

    #[test]
    fn open_at_line_on_file_and_directory() -> Result<()> {
        let (_temp, root, state) = sandbox()?;
        fs::create_dir(root.join("drafts"))?;
        touch_file(&root.join("notes.md"), "n")?;

        let manifest = render(&root, &state)?;
        let directory_manifest = open_at_line(&manifest, 3, &state)?;
        let file_path = open_at_line(&manifest, 4, &state)?;

        assert!(directory_manifest.ends_with(MANIFEST_FILE_NAME));
        assert_eq!(file_path, root.join("notes.md"));
        Ok(())
    }

    #[test]
    fn parent_traversal_opens_parent_manifest() -> Result<()> {
        let (_temp, root, state) = sandbox()?;
        let child = root.join("child");
        fs::create_dir(&child)?;
        touch_file(&root.join("top.txt"), "t")?;

        let manifest = render(&child, &state)?;
        let parent_manifest = parent_session(&manifest, &state)?;
        let parent_text = fs::read_to_string(parent_manifest)?;

        assert!(parent_text.contains("top.txt"));
        assert!(parent_text.contains(&format!("# hx-oil root: {}", root.display())));
        Ok(())
    }

    #[test]
    fn gc_removes_old_sessions() -> Result<()> {
        let (_temp, root, state) = sandbox()?;
        touch_file(&root.join("keep.txt"), "k")?;

        let old_manifest = render(&root, &state)?;
        let old_session = session_dir_for_manifest(&old_manifest)?;
        let recent_manifest = render(&root, &state)?;
        let recent_session = session_dir_for_manifest(&recent_manifest)?;

        let old_time = FileTime::from_unix_time(
            (SystemTime::now() - SESSION_RETENTION - Duration::from_secs(60))
                .duration_since(UNIX_EPOCH)?
                .as_secs() as i64,
            0,
        );
        set_file_mtime(&old_session, old_time)?;

        let removed = gc_sessions_at(&state, SystemTime::now())?;
        assert_eq!(removed, 1);
        assert!(!old_session.exists());
        assert!(recent_session.exists());
        Ok(())
    }
}
