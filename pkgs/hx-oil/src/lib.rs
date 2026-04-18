use std::collections::{BTreeMap, HashMap, HashSet};
use std::fmt::Write as _;
use std::fs::{self, OpenOptions};
use std::path::{Path, PathBuf};
use std::process;
use std::sync::atomic::{AtomicU64, Ordering};
use std::time::{Duration, SystemTime, UNIX_EPOCH};

use anyhow::{Context, Result, anyhow, bail, ensure};
use regex::Regex;
use serde::{Deserialize, Serialize};

pub const MANIFEST_FILE_NAME: &str = "manifest.hxoil";
pub const SIDECAR_FILE_NAME: &str = "manifest.hxoil.json";
pub const SESSION_RETENTION: Duration = Duration::from_secs(7 * 24 * 60 * 60);
const SUBDIR_INDENT: &str = "    ";
const SIDECAR_VERSION: u32 = 2;

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

#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash)]
pub enum EntryMark {
    None,
    Marked,
    DeleteFlagged,
}

impl EntryMark {
    fn prefix(self) -> &'static str {
        match self {
            Self::None => "  ",
            Self::Marked => "* ",
            Self::DeleteFlagged => "D ",
        }
    }
}

#[derive(Debug, Clone, PartialEq, Eq, PartialOrd, Ord, Hash)]
pub enum EntryScope {
    Root,
    Subdir(String),
}

impl EntryScope {
    fn absolute_root<'a>(&'a self, root: &'a Path) -> PathBuf {
        match self {
            Self::Root => root.to_path_buf(),
            Self::Subdir(path) => root.join(path),
        }
    }

    fn actual_relative_path(&self, relative_path: &str) -> String {
        match self {
            Self::Root => relative_path.to_owned(),
            Self::Subdir(path) => format!("{path}/{relative_path}"),
        }
    }
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct SnapshotEntry {
    #[serde(default)]
    pub id: u64,
    pub index: usize,
    pub relative_path: String,
    pub kind: EntryKind,
    pub mtime_ns: u64,
    pub size: u64,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct SubdirState {
    pub relative_path: String,
    pub entries: Vec<SnapshotEntry>,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct ManifestEntry {
    pub relative_path: String,
    pub kind: EntryKind,
    pub line_number: usize,
    pub mark: EntryMark,
    pub scope: EntryScope,
}

impl ManifestEntry {
    fn actual_relative_path(&self) -> String {
        self.scope.actual_relative_path(&self.relative_path)
    }

    fn absolute_root(&self, root: &Path) -> PathBuf {
        self.scope.absolute_root(root)
    }
}

#[derive(Debug, Clone)]
pub struct ManifestDocument {
    pub root: PathBuf,
    pub lines: Vec<ManifestLine>,
}

impl ManifestDocument {
    fn entries(&self) -> Vec<ManifestEntry> {
        self.lines
            .iter()
            .filter_map(|line| match line {
                ManifestLine::Entry(entry) => Some(entry.clone()),
                _ => None,
            })
            .collect()
    }

    fn visible_subdirs(&self) -> Vec<String> {
        self.lines
            .iter()
            .filter_map(|line| match line {
                ManifestLine::SubdirStart { name, .. } => Some(name.clone()),
                _ => None,
            })
            .collect()
    }
}

#[derive(Debug, Clone)]
pub enum ManifestLine {
    Blank { line_number: usize },
    Comment { text: String, line_number: usize },
    Entry(ManifestEntry),
    SubdirStart { name: String, line_number: usize },
    SubdirEnd { name: String, line_number: usize },
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Sidecar {
    #[serde(default = "default_sidecar_version")]
    pub version: u32,
    pub root: PathBuf,
    pub manifest_path: PathBuf,
    pub created_at: u64,
    #[serde(default)]
    pub next_entry_id: u64,
    pub entries: Vec<SnapshotEntry>,
    #[serde(default)]
    pub subdirs: Vec<SubdirState>,
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

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum BulkKind {
    Copy,
    Move,
    Symlink,
    RelativeSymlink,
}

impl BulkKind {
    fn label(self) -> &'static str {
        match self {
            Self::Copy => "COPY",
            Self::Move => "MOVE",
            Self::Symlink => "SYMLINK",
            Self::RelativeSymlink => "RELSYMLINK",
        }
    }
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct BulkItem {
    pub kind: BulkKind,
    pub entry_kind: EntryKind,
    pub source: PathBuf,
    pub destination: PathBuf,
    pub rendered_source: String,
    pub rendered_destination: String,
    pub link_target: Option<PathBuf>,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct BulkPlan {
    pub kind: BulkKind,
    pub target_root: PathBuf,
    pub items: Vec<BulkItem>,
}

#[derive(Debug, Clone)]
pub enum TransformKind {
    Regex { pattern: String, replace: String },
    Prefix { value: String },
    Suffix { value: String },
    Lower,
    Upper,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct TransformItem {
    pub kind: EntryKind,
    pub from: String,
    pub to: String,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct TransformPlan {
    pub scope_root: PathBuf,
    pub items: Vec<TransformItem>,
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

pub fn alternate_manifest_state_path(state_home: &Path) -> PathBuf {
    state_home.join("hx-oil").join("alternate-manifest")
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
    rewrite_session_files(&root, &manifest_path, None, &[])
}

pub fn refresh_session(manifest_path: &Path) -> Result<PathBuf> {
    let session = load_session(manifest_path)?;
    let document = parse_manifest_file(manifest_path)?;
    rewrite_session_files(
        &session.sidecar.root,
        manifest_path,
        Some(&session.sidecar),
        &document.visible_subdirs(),
    )
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
    let document = parse_manifest_file(manifest_path)?;

    let Some(line) = document
        .lines
        .iter()
        .find(|line| manifest_line_number(line) == line_number)
    else {
        return Ok(manifest_path.to_path_buf());
    };

    let ManifestLine::Entry(entry) = line else {
        return Ok(manifest_path.to_path_buf());
    };

    let target_root = entry.absolute_root(&session.sidecar.root);
    let target = target_root.join(&entry.relative_path);

    match entry.kind {
        EntryKind::File => Ok(target),
        EntryKind::Directory => {
            ensure!(
                target.is_dir(),
                "directory entry {} does not exist yet; apply the manifest first",
                entry.kind.render_path(&entry.actual_relative_path())
            );
            render_session(&target, state_home)
        }
    }
}

pub fn dry_run_apply(manifest_path: &Path) -> Result<String> {
    let session = load_session(manifest_path)?;
    let document = parse_and_validate_document(manifest_path, &session.sidecar.root)?;
    validate_apply_snapshot(&session, &document)?;
    validate_document_entries(&document)?;
    validate_visible_subdir_roots(&document)?;

    let mut plans = build_apply_plans(&session, &document)?;
    let mut rendered = String::new();

    for (scope_root, plan) in &plans {
        validate_apply_targets(scope_root, plan)?;
    }

    for (_, plan) in plans.drain(..) {
        rendered.push_str(&render_plan(&plan));
    }

    if rendered.is_empty() {
        rendered.push_str("No changes.\n");
    }
    Ok(rendered)
}

pub fn apply_manifest(manifest_path: &Path) -> Result<String> {
    let session = load_session(manifest_path)?;
    let document = parse_and_validate_document(manifest_path, &session.sidecar.root)?;
    validate_apply_snapshot(&session, &document)?;
    validate_document_entries(&document)?;
    validate_visible_subdir_roots(&document)?;

    let visible_subdirs = document.visible_subdirs();
    let plans = build_apply_plans(&session, &document)?;
    let mut rendered = String::new();

    for (scope_root, plan) in &plans {
        validate_apply_targets(scope_root, plan)?;
    }

    for (scope_root, plan) in &plans {
        execute_plan(scope_root, plan)?;
        rendered.push_str(&render_plan(plan));
    }

    if rendered.is_empty() {
        rendered.push_str("No changes.\n");
    }

    rewrite_session_files(
        &session.sidecar.root,
        manifest_path,
        Some(&session.sidecar),
        &visible_subdirs,
    )?;

    Ok(rendered)
}

pub fn mark_toggle(manifest_path: &Path, lines: &[usize]) -> Result<PathBuf> {
    let session = load_session(manifest_path)?;
    let mut document = parse_and_validate_document(manifest_path, &session.sidecar.root)?;

    for line in lines {
        let entry = entry_at_line_mut(&mut document, *line)?;
        entry.mark = match entry.mark {
            EntryMark::None => EntryMark::Marked,
            EntryMark::Marked => EntryMark::None,
            EntryMark::DeleteFlagged => bail!(
                "line {line}: entry is delete-flagged; use flag-delete to change delete state"
            ),
        };
    }

    write_manifest_document(manifest_path, &document)?;
    Ok(manifest_path.to_path_buf())
}

pub fn remember_alternate_manifest(manifest_path: &Path, state_home: &Path) -> Result<PathBuf> {
    let state_file = alternate_manifest_state_path(state_home);
    fs::create_dir_all(
        state_file
            .parent()
            .context("alternate manifest state file has no parent")?,
    )
    .with_context(|| format!("failed to create {}", state_file.display()))?;
    fs::write(&state_file, manifest_path.display().to_string())
        .with_context(|| format!("failed to write {}", state_file.display()))?;
    Ok(state_file)
}

pub fn clear_marks(manifest_path: &Path) -> Result<PathBuf> {
    let session = load_session(manifest_path)?;
    let mut document = parse_and_validate_document(manifest_path, &session.sidecar.root)?;

    for line in &mut document.lines {
        if let ManifestLine::Entry(entry) = line
            && entry.mark == EntryMark::Marked
        {
            entry.mark = EntryMark::None;
        }
    }

    write_manifest_document(manifest_path, &document)?;
    Ok(manifest_path.to_path_buf())
}

pub fn flag_delete(manifest_path: &Path, lines: &[usize]) -> Result<PathBuf> {
    let session = load_session(manifest_path)?;
    let mut document = parse_and_validate_document(manifest_path, &session.sidecar.root)?;

    for line in lines {
        let entry = entry_at_line_mut(&mut document, *line)?;
        entry.mark = match entry.mark {
            EntryMark::DeleteFlagged => EntryMark::None,
            EntryMark::None | EntryMark::Marked => EntryMark::DeleteFlagged,
        };
    }

    write_manifest_document(manifest_path, &document)?;
    Ok(manifest_path.to_path_buf())
}

pub fn run_bulk_op(
    manifest_path: &Path,
    kind: BulkKind,
    execute: bool,
    target: Option<&Path>,
    target_manifest: Option<&Path>,
    alternate_manifest: Option<&Path>,
) -> Result<String> {
    let session = load_session(manifest_path)?;
    let document = parse_and_validate_document(manifest_path, &session.sidecar.root)?;
    validate_apply_snapshot(&session, &document)?;
    validate_document_entries(&document)?;

    let state_home = xdg_state_home()?;
    let plan = build_bulk_plan(
        &session,
        &document,
        kind,
        target,
        target_manifest,
        alternate_manifest,
        Some(&alternate_manifest_state_path(&state_home)),
    )?;
    let rendered = render_bulk_plan(&plan);

    if !execute {
        return Ok(rendered);
    }

    execute_bulk_plan(&plan)?;
    rewrite_session_files(
        &session.sidecar.root,
        manifest_path,
        Some(&session.sidecar),
        &document.visible_subdirs(),
    )?;
    refresh_target_manifest_if_needed(target_manifest, alternate_manifest)?;
    Ok(rendered)
}

pub fn run_transform(manifest_path: &Path, kind: TransformKind, execute: bool) -> Result<String> {
    let session = load_session(manifest_path)?;
    let document = parse_and_validate_document(manifest_path, &session.sidecar.root)?;
    validate_apply_snapshot(&session, &document)?;
    validate_document_entries(&document)?;

    let plan = build_transform_plan(&session, &document, kind)?;
    let rendered = render_transform_plan(&plan);

    if !execute {
        return Ok(rendered);
    }

    execute_transform_plan(&session, &plan)?;
    rewrite_session_files(
        &session.sidecar.root,
        manifest_path,
        Some(&session.sidecar),
        &document.visible_subdirs(),
    )?;
    Ok(rendered)
}

pub fn insert_subdir(manifest_path: &Path, line_number: usize) -> Result<PathBuf> {
    let mut session = load_session(manifest_path)?;
    let mut document = parse_and_validate_document(manifest_path, &session.sidecar.root)?;

    let line_index = line_index_for_entry(&document, line_number)?;
    let entry = match &document.lines[line_index] {
        ManifestLine::Entry(entry) => entry.clone(),
        _ => bail!("line {line_number} is not a directory entry"),
    };

    ensure!(
        matches!(entry.scope, EntryScope::Root),
        "bounded nesting: inline insertion only works from the root listing"
    );
    ensure!(
        entry.kind == EntryKind::Directory,
        "line {line_number} is not a directory entry"
    );
    ensure!(
        !document
            .visible_subdirs()
            .iter()
            .any(|name| name == &entry.relative_path),
        "subdir {} is already inserted",
        entry.relative_path
    );

    let (entries, next_id) = collect_snapshot_with_ids(
        &session.sidecar.root.join(&entry.relative_path),
        session
            .sidecar
            .subdirs
            .iter()
            .find(|state| state.relative_path == entry.relative_path)
            .map(|state| state.entries.as_slice()),
        session.sidecar.next_entry_id,
    )?;
    session.sidecar.next_entry_id = next_id;
    session.sidecar.subdirs.push(SubdirState {
        relative_path: entry.relative_path.clone(),
        entries: entries.clone(),
    });

    let mut inserted = Vec::new();
    inserted.push(ManifestLine::SubdirStart {
        name: entry.relative_path.clone(),
        line_number: 0,
    });
    inserted.extend(entries.into_iter().map(|snapshot| {
        ManifestLine::Entry(ManifestEntry {
            relative_path: snapshot.relative_path,
            kind: snapshot.kind,
            line_number: 0,
            mark: EntryMark::None,
            scope: EntryScope::Subdir(entry.relative_path.clone()),
        })
    }));
    inserted.push(ManifestLine::SubdirEnd {
        name: entry.relative_path.clone(),
        line_number: 0,
    });

    document
        .lines
        .splice(line_index + 1..line_index + 1, inserted);
    write_manifest_document(manifest_path, &document)?;
    write_sidecar(&session.sidecar_path, &session.sidecar)?;
    Ok(manifest_path.to_path_buf())
}

pub fn collapse_subdir(manifest_path: &Path, line_number: usize) -> Result<PathBuf> {
    let mut session = load_session(manifest_path)?;
    let mut document = parse_and_validate_document(manifest_path, &session.sidecar.root)?;
    let target = subdir_for_line(&document, line_number)?;
    remove_subdir_block(&mut document, &target)?;
    session
        .sidecar
        .subdirs
        .retain(|state| state.relative_path != target);
    write_manifest_document(manifest_path, &document)?;
    write_sidecar(&session.sidecar_path, &session.sidecar)?;
    Ok(manifest_path.to_path_buf())
}

pub fn refresh_subdir(manifest_path: &Path, line_number: usize) -> Result<PathBuf> {
    let mut session = load_session(manifest_path)?;
    let mut document = parse_and_validate_document(manifest_path, &session.sidecar.root)?;
    let target = subdir_for_line(&document, line_number)?;

    let existing = session
        .sidecar
        .subdirs
        .iter()
        .find(|state| state.relative_path == target)
        .map(|state| state.entries.as_slice());
    let (entries, next_id) = collect_snapshot_with_ids(
        &session.sidecar.root.join(&target),
        existing,
        session.sidecar.next_entry_id,
    )?;
    session.sidecar.next_entry_id = next_id;

    let Some(state) = session
        .sidecar
        .subdirs
        .iter_mut()
        .find(|state| state.relative_path == target)
    else {
        bail!("subdir block {target} is missing from the sidecar; reopen the directory buffer");
    };
    state.entries = entries.clone();

    replace_subdir_entries(&mut document, &target, entries)?;
    write_manifest_document(manifest_path, &document)?;
    write_sidecar(&session.sidecar_path, &session.sidecar)?;
    Ok(manifest_path.to_path_buf())
}

pub fn parse_manifest_text(text: &str) -> Result<Vec<ManifestEntry>> {
    Ok(parse_manifest_document(text)?.entries())
}

pub fn parse_manifest_file(manifest_path: &Path) -> Result<ManifestDocument> {
    let content = fs::read_to_string(manifest_path)
        .with_context(|| format!("failed to read manifest {}", manifest_path.display()))?;
    parse_manifest_document(&content)
}

pub fn render_manifest(root: &Path, entries: &[SnapshotEntry]) -> String {
    render_canonical_manifest(root, entries, &[])
}

pub fn collect_snapshot(root: &Path) -> Result<Vec<SnapshotEntry>> {
    let (entries, _) = collect_snapshot_with_ids(root, None, 1)?;
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

    let mut sidecar = serde_json::from_str::<Sidecar>(
        &fs::read_to_string(&sidecar_path)
            .with_context(|| format!("failed to read sidecar {}", sidecar_path.display()))?,
    )
    .with_context(|| format!("failed to parse sidecar {}", sidecar_path.display()))?;

    upgrade_sidecar(&mut sidecar);

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

fn default_sidecar_version() -> u32 {
    1
}

fn parse_and_validate_document(
    manifest_path: &Path,
    expected_root: &Path,
) -> Result<ManifestDocument> {
    let document = parse_manifest_file(manifest_path)?;
    ensure!(
        document.root == expected_root,
        "manifest root header does not match the sidecar for {}; reopen the directory buffer",
        manifest_path.display()
    );
    Ok(document)
}

fn rewrite_session_files(
    root: &Path,
    manifest_path: &Path,
    previous: Option<&Sidecar>,
    open_subdirs: &[String],
) -> Result<PathBuf> {
    let previous_entries = previous.map(|sidecar| sidecar.entries.as_slice());
    let previous_next_id = previous.map(|sidecar| sidecar.next_entry_id).unwrap_or(1);
    let (entries, mut next_entry_id) =
        collect_snapshot_with_ids(root, previous_entries, previous_next_id)?;

    let mut subdirs = Vec::new();
    for name in open_subdirs {
        let Some(root_entry) = entries
            .iter()
            .find(|entry| entry.relative_path == *name && entry.kind == EntryKind::Directory)
        else {
            continue;
        };
        let previous_subdir = previous.and_then(|sidecar| {
            sidecar
                .subdirs
                .iter()
                .find(|state| state.relative_path == root_entry.relative_path)
        });
        let (subdir_entries, updated_next_id) = collect_snapshot_with_ids(
            &root.join(name),
            previous_subdir.map(|state| state.entries.as_slice()),
            next_entry_id,
        )?;
        next_entry_id = updated_next_id;
        subdirs.push(SubdirState {
            relative_path: name.clone(),
            entries: subdir_entries,
        });
    }

    let sidecar = Sidecar {
        version: SIDECAR_VERSION,
        root: root.to_path_buf(),
        manifest_path: manifest_path.to_path_buf(),
        created_at: SystemTime::now()
            .duration_since(UNIX_EPOCH)
            .context("system clock is before unix epoch")?
            .as_secs(),
        next_entry_id,
        entries: entries.clone(),
        subdirs: subdirs.clone(),
    };
    let sidecar_path = sidecar_path_for(manifest_path);

    fs::create_dir_all(
        manifest_path
            .parent()
            .context("manifest path has no parent directory")?,
    )
    .with_context(|| format!("failed to create {}", manifest_path.display()))?;
    fs::write(
        manifest_path,
        render_canonical_manifest(root, &entries, &subdirs),
    )
    .with_context(|| format!("failed to write manifest {}", manifest_path.display()))?;
    write_sidecar(&sidecar_path, &sidecar)?;
    Ok(manifest_path.to_path_buf())
}

fn write_sidecar(sidecar_path: &Path, sidecar: &Sidecar) -> Result<()> {
    fs::write(sidecar_path, serde_json::to_vec_pretty(sidecar)?)
        .with_context(|| format!("failed to write sidecar {}", sidecar_path.display()))
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

fn collect_snapshot_with_ids(
    root: &Path,
    previous: Option<&[SnapshotEntry]>,
    next_id: u64,
) -> Result<(Vec<SnapshotEntry>, u64)> {
    let mut entries = Vec::new();

    for entry in fs::read_dir(root).with_context(|| format!("failed to read {}", root.display()))? {
        let entry = entry?;
        let relative_path = entry
            .file_name()
            .into_string()
            .map_err(|_| anyhow!("non-utf8 entry under {} is unsupported", root.display()))?;
        let file_type = entry.file_type()?;
        let metadata = entry.metadata()?;
        let kind = if file_type.is_dir() {
            EntryKind::Directory
        } else {
            EntryKind::File
        };

        entries.push(SnapshotEntry {
            id: 0,
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

    let mut next = if next_id == 0 { 1 } else { next_id };
    let previous_ids: HashMap<(String, EntryKind), u64> = previous
        .unwrap_or(&[])
        .iter()
        .map(|entry| ((entry.relative_path.clone(), entry.kind), entry.id))
        .collect();
    let previous_max = previous
        .unwrap_or(&[])
        .iter()
        .map(|entry| entry.id)
        .max()
        .unwrap_or(0);
    if next <= previous_max {
        next = previous_max + 1;
    }

    for (index, entry) in entries.iter_mut().enumerate() {
        entry.index = index;
        entry.id = previous_ids
            .get(&(entry.relative_path.clone(), entry.kind))
            .copied()
            .unwrap_or_else(|| {
                let assigned = next;
                next += 1;
                assigned
            });
    }

    Ok((entries, next))
}

fn render_canonical_manifest(
    root: &Path,
    entries: &[SnapshotEntry],
    subdirs: &[SubdirState],
) -> String {
    let mut rendered = String::new();
    let _ = writeln!(rendered, "# hx-oil root: {}", root.display());
    let _ = writeln!(rendered, "# blank lines and comment lines are ignored");

    let subdir_map: HashMap<&str, &SubdirState> = subdirs
        .iter()
        .map(|state| (state.relative_path.as_str(), state))
        .collect();

    for entry in entries {
        let manifest_entry = ManifestEntry {
            relative_path: entry.relative_path.clone(),
            kind: entry.kind,
            line_number: 0,
            mark: EntryMark::None,
            scope: EntryScope::Root,
        };
        let _ = writeln!(rendered, "{}", render_manifest_entry(&manifest_entry));

        if let Some(subdir) = subdir_map.get(entry.relative_path.as_str()) {
            let _ = writeln!(rendered, "# hx-oil subdir: {}", subdir.relative_path);
            for child in &subdir.entries {
                let manifest_entry = ManifestEntry {
                    relative_path: child.relative_path.clone(),
                    kind: child.kind,
                    line_number: 0,
                    mark: EntryMark::None,
                    scope: EntryScope::Subdir(subdir.relative_path.clone()),
                };
                let _ = writeln!(rendered, "{}", render_manifest_entry(&manifest_entry));
            }
            let _ = writeln!(rendered, "# hx-oil end-subdir: {}", subdir.relative_path);
        }
    }

    rendered
}

fn write_manifest_document(manifest_path: &Path, document: &ManifestDocument) -> Result<()> {
    fs::write(manifest_path, render_manifest_document(document))
        .with_context(|| format!("failed to write manifest {}", manifest_path.display()))
}

fn render_manifest_document(document: &ManifestDocument) -> String {
    let mut rendered = String::new();
    let _ = writeln!(rendered, "# hx-oil root: {}", document.root.display());
    let _ = writeln!(rendered, "# blank lines and comment lines are ignored");

    for line in &document.lines {
        match line {
            ManifestLine::Blank { .. } => rendered.push('\n'),
            ManifestLine::Comment { text, .. } => {
                rendered.push_str(text);
                rendered.push('\n');
            }
            ManifestLine::Entry(entry) => {
                rendered.push_str(&render_manifest_entry(entry));
                rendered.push('\n');
            }
            ManifestLine::SubdirStart { name, .. } => {
                let _ = writeln!(rendered, "# hx-oil subdir: {name}");
            }
            ManifestLine::SubdirEnd { name, .. } => {
                let _ = writeln!(rendered, "# hx-oil end-subdir: {name}");
            }
        }
    }

    rendered
}

fn render_manifest_entry(entry: &ManifestEntry) -> String {
    let mut rendered = String::new();
    if matches!(entry.scope, EntryScope::Subdir(_)) {
        rendered.push_str(SUBDIR_INDENT);
    }
    rendered.push_str(entry.mark.prefix());
    rendered.push_str(&entry.kind.render_path(&entry.relative_path));
    rendered
}

fn parse_manifest_document(text: &str) -> Result<ManifestDocument> {
    let mut lines = Vec::new();
    let mut root = None;
    let mut current_subdir: Option<String> = None;

    for (index, line) in text.lines().enumerate() {
        let line_number = index + 1;
        if line_number == 1 {
            let Some(value) = line.strip_prefix("# hx-oil root: ") else {
                bail!("manifest is missing the hx-oil root header; reopen the directory buffer");
            };
            root = Some(PathBuf::from(value));
            continue;
        }
        if line_number == 2 && line == "# blank lines and comment lines are ignored" {
            continue;
        }
        if let Some(name) = line.strip_prefix("# hx-oil subdir: ") {
            ensure!(
                current_subdir.is_none(),
                "nested subdir blocks are unsupported in this manifest"
            );
            current_subdir = Some(name.to_owned());
            lines.push(ManifestLine::SubdirStart {
                name: name.to_owned(),
                line_number,
            });
            continue;
        }
        if let Some(name) = line.strip_prefix("# hx-oil end-subdir: ") {
            let Some(current) = current_subdir.take() else {
                bail!("line {line_number}: unexpected hx-oil end-subdir marker");
            };
            ensure!(
                current == name,
                "line {line_number}: mismatched hx-oil end-subdir marker for {name}"
            );
            lines.push(ManifestLine::SubdirEnd {
                name: name.to_owned(),
                line_number,
            });
            continue;
        }
        if line.trim().is_empty() {
            lines.push(ManifestLine::Blank { line_number });
            continue;
        }
        if line.starts_with('#') {
            lines.push(ManifestLine::Comment {
                text: line.to_owned(),
                line_number,
            });
            continue;
        }

        let scope = match &current_subdir {
            Some(path) => EntryScope::Subdir(path.clone()),
            None => EntryScope::Root,
        };
        lines.push(ManifestLine::Entry(parse_manifest_entry_line(
            line_number,
            line,
            scope,
        )?));
    }

    ensure!(current_subdir.is_none(), "unterminated hx-oil subdir block");
    Ok(ManifestDocument {
        root: root.context("manifest is missing the hx-oil root header")?,
        lines,
    })
}

fn parse_manifest_entry_line(
    line_number: usize,
    line: &str,
    scope: EntryScope,
) -> Result<ManifestEntry> {
    let payload = if matches!(scope, EntryScope::Subdir(_)) {
        line.strip_prefix(SUBDIR_INDENT).ok_or_else(|| {
            anyhow!("line {line_number}: inserted subdir entries must start with four spaces")
        })?
    } else {
        line
    };

    let (mark, rest) = if let Some(rest) = payload.strip_prefix("* ") {
        (EntryMark::Marked, rest)
    } else if let Some(rest) = payload.strip_prefix("D ") {
        (EntryMark::DeleteFlagged, rest)
    } else if let Some(rest) = payload.strip_prefix("  ") {
        (EntryMark::None, rest)
    } else {
        (EntryMark::None, payload)
    };

    let (relative_path, kind) = if let Some(path) = rest.strip_suffix('/') {
        (path.to_owned(), EntryKind::Directory)
    } else {
        (rest.to_owned(), EntryKind::File)
    };

    Ok(ManifestEntry {
        relative_path,
        kind,
        line_number,
        mark,
        scope,
    })
}

fn validate_apply_snapshot(session: &Session, document: &ManifestDocument) -> Result<()> {
    let current_root = collect_snapshot_with_ids(&session.sidecar.root, None, 1)?.0;
    ensure!(
        snapshot_lists_match(&current_root, &session.sidecar.entries),
        "stale snapshot for {}; refresh or reopen the directory buffer before applying",
        session.sidecar.root.display()
    );

    for name in document.visible_subdirs() {
        let Some(state) = session
            .sidecar
            .subdirs
            .iter()
            .find(|state| state.relative_path == name)
        else {
            bail!(
                "missing sidecar metadata for inserted subdir {name}; refresh or reopen the directory buffer"
            );
        };
        let current = collect_snapshot_with_ids(&session.sidecar.root.join(&name), None, 1)?.0;
        ensure!(
            snapshot_lists_match(&current, &state.entries),
            "stale snapshot for {}; refresh the subtree or reopen the directory buffer before applying",
            session.sidecar.root.join(&name).display()
        );
    }

    Ok(())
}

fn snapshot_lists_match(left: &[SnapshotEntry], right: &[SnapshotEntry]) -> bool {
    left.len() == right.len()
        && left.iter().zip(right).all(|(left, right)| {
            left.index == right.index
                && left.relative_path == right.relative_path
                && left.kind == right.kind
                && left.mtime_ns == right.mtime_ns
                && left.size == right.size
        })
}

fn validate_document_entries(document: &ManifestDocument) -> Result<()> {
    let mut seen = HashSet::new();
    for entry in document.entries() {
        validate_entry_name(&entry.relative_path, entry.kind, entry.line_number)?;
        ensure!(
            seen.insert((entry.scope.clone(), entry.relative_path.clone())),
            "duplicate target path in manifest: {}",
            entry.kind.render_path(&entry.actual_relative_path())
        );
    }
    Ok(())
}

fn validate_visible_subdir_roots(document: &ManifestDocument) -> Result<()> {
    let root_entries: HashSet<String> = document
        .entries()
        .into_iter()
        .filter(|entry| {
            matches!(entry.scope, EntryScope::Root) && entry.kind == EntryKind::Directory
        })
        .map(|entry| entry.relative_path)
        .collect();

    for name in document.visible_subdirs() {
        ensure!(
            root_entries.contains(&name),
            "unsafe subtree mutation: inserted subdir {name} must keep its root directory entry unchanged"
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
        "line {line_number}: nested paths are unsupported"
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

fn build_apply_plans(
    session: &Session,
    document: &ManifestDocument,
) -> Result<Vec<(PathBuf, Plan)>> {
    let entries = document.entries();
    let mut grouped: BTreeMap<EntryScope, Vec<ManifestEntry>> = BTreeMap::new();
    for entry in entries {
        if entry.mark != EntryMark::DeleteFlagged {
            grouped.entry(entry.scope.clone()).or_default().push(entry);
        }
    }

    let mut plans = Vec::new();
    for (scope, edited_entries) in grouped {
        let original = match &scope {
            EntryScope::Root => session.sidecar.entries.clone(),
            EntryScope::Subdir(path) => session
                .sidecar
                .subdirs
                .iter()
                .find(|state| state.relative_path == *path)
                .map(|state| state.entries.clone())
                .context("missing sidecar metadata for inserted subdir")?,
        };
        let scope_root = scope.absolute_root(&session.sidecar.root);
        let plan = build_plan(&scope_root, &original, &edited_entries)?;
        plans.push((scope_root, plan));
    }

    let visible_subdirs: HashSet<String> = document.visible_subdirs().into_iter().collect();
    for state in &session.sidecar.subdirs {
        if visible_subdirs.contains(&state.relative_path)
            && !document
                .entries()
                .iter()
                .any(|entry| entry.scope == EntryScope::Subdir(state.relative_path.clone()))
            && !state.entries.is_empty()
        {
            plans.push((
                session.sidecar.root.join(&state.relative_path),
                Plan {
                    root: session.sidecar.root.join(&state.relative_path),
                    operations: state
                        .entries
                        .iter()
                        .map(|entry| Operation::Delete {
                            path: entry.relative_path.clone(),
                            kind: entry.kind,
                        })
                        .collect(),
                    final_entries: Vec::new(),
                },
            ));
        }
    }

    Ok(plans)
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
    let current_paths: HashSet<String> = collect_snapshot_with_ids(root, None, 1)?
        .0
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

fn build_bulk_plan(
    session: &Session,
    document: &ManifestDocument,
    kind: BulkKind,
    target: Option<&Path>,
    target_manifest: Option<&Path>,
    alternate_manifest: Option<&Path>,
    alternate_state_path: Option<&Path>,
) -> Result<BulkPlan> {
    let marked = marked_entries(document)?;
    let scope = single_scope(&marked)?;
    let source_root = scope.absolute_root(&session.sidecar.root);
    let target_root = resolve_target_root(
        &session.sidecar.root,
        target,
        target_manifest,
        alternate_manifest,
        alternate_state_path,
    )?;

    ensure!(
        target_root.is_dir(),
        "bulk target is not a directory: {}",
        target_root.display()
    );

    let mut seen_destinations = HashSet::new();
    let mut items = Vec::new();
    for entry in marked {
        let source = source_root.join(&entry.relative_path);
        let destination = target_root.join(&entry.relative_path);
        ensure!(
            seen_destinations.insert(destination.clone()),
            "bulk target collision: {}",
            destination.display()
        );

        match kind {
            BulkKind::Copy | BulkKind::Symlink | BulkKind::RelativeSymlink => {
                ensure!(
                    !destination.exists(),
                    "bulk target collision: {}",
                    destination.display()
                );
            }
            BulkKind::Move => {
                ensure!(
                    destination != source,
                    "bulk move resolves to the source path itself: {}",
                    source.display()
                );
                ensure!(
                    !destination.exists(),
                    "bulk target collision: {}",
                    destination.display()
                );
            }
        }

        let link_target = if kind == BulkKind::RelativeSymlink {
            Some(diff_paths(
                &source,
                destination.parent().context("destination has no parent")?,
            )?)
        } else if kind == BulkKind::Symlink {
            Some(source.clone())
        } else {
            None
        };

        items.push(BulkItem {
            kind,
            entry_kind: entry.kind,
            source: source.clone(),
            destination: destination.clone(),
            rendered_source: entry.kind.render_path(&entry.actual_relative_path()),
            rendered_destination: entry.kind.render_path(&entry.relative_path),
            link_target,
        });
    }

    ensure!(
        !items.is_empty(),
        "no marked entries selected for bulk operation"
    );

    Ok(BulkPlan {
        kind,
        target_root,
        items,
    })
}

fn execute_bulk_plan(plan: &BulkPlan) -> Result<()> {
    for item in &plan.items {
        match plan.kind {
            BulkKind::Copy => copy_path(&item.source, &item.destination)?,
            BulkKind::Move => fs::rename(&item.source, &item.destination).with_context(|| {
                format!(
                    "failed to move {} to {}",
                    item.source.display(),
                    item.destination.display()
                )
            })?,
            BulkKind::Symlink | BulkKind::RelativeSymlink => {
                std::os::unix::fs::symlink(
                    item.link_target.as_ref().context("missing link target")?,
                    &item.destination,
                )
                .with_context(|| {
                    format!(
                        "failed to create symlink {} -> {}",
                        item.destination.display(),
                        item.link_target
                            .as_ref()
                            .unwrap_or(&PathBuf::from("?"))
                            .display()
                    )
                })?;
            }
        }
    }

    Ok(())
}

fn render_bulk_plan(plan: &BulkPlan) -> String {
    let mut rendered = String::new();
    let _ = writeln!(rendered, "TARGET {}", plan.target_root.display());
    for item in &plan.items {
        match plan.kind {
            BulkKind::Copy | BulkKind::Move => {
                let _ = writeln!(
                    rendered,
                    "{} {} {} -> {}",
                    plan.kind.label(),
                    item.entry_kind.label(),
                    item.rendered_source,
                    item.destination.display()
                );
            }
            BulkKind::Symlink | BulkKind::RelativeSymlink => {
                let _ = writeln!(
                    rendered,
                    "{} {} {} -> {} ({})",
                    plan.kind.label(),
                    item.entry_kind.label(),
                    item.rendered_source,
                    item.destination.display(),
                    item.link_target
                        .as_ref()
                        .unwrap_or(&PathBuf::from("?"))
                        .display()
                );
            }
        }
    }
    rendered
}

fn build_transform_plan(
    session: &Session,
    document: &ManifestDocument,
    kind: TransformKind,
) -> Result<TransformPlan> {
    let marked = marked_entries(document)?;
    let scope = single_scope(&marked)?;
    let scope_root = scope.absolute_root(&session.sidecar.root);
    let regex = match &kind {
        TransformKind::Regex { pattern, .. } => Some(Regex::new(pattern)?),
        _ => None,
    };

    let all_scope_entries: Vec<ManifestEntry> = document
        .entries()
        .into_iter()
        .filter(|entry| entry.scope == scope)
        .collect();
    let marked_source_names: HashSet<String> = marked
        .iter()
        .map(|entry| entry.relative_path.clone())
        .collect();
    let unmarked_names: HashSet<String> = all_scope_entries
        .iter()
        .filter(|entry| !marked_source_names.contains(&entry.relative_path))
        .map(|entry| entry.relative_path.clone())
        .collect();

    let mut produced = HashSet::new();
    let mut items = Vec::new();
    for entry in marked {
        let next = apply_transform(&kind, regex.as_ref(), &entry.relative_path)?;
        ensure!(
            next != entry.relative_path,
            "transform no-op for {}",
            entry.kind.render_path(&entry.actual_relative_path())
        );
        validate_entry_name(&next, entry.kind, entry.line_number)?;
        ensure!(
            !unmarked_names.contains(&next),
            "transform collision: {} already exists",
            entry.kind.render_path(&scope.actual_relative_path(&next))
        );
        ensure!(
            produced.insert(next.clone()),
            "transform collision: multiple entries map to {}",
            entry.kind.render_path(&scope.actual_relative_path(&next))
        );
        ensure!(
            !marked_source_names.contains(&next),
            "transform collision: {} would replace another marked source entry",
            entry.kind.render_path(&scope.actual_relative_path(&next))
        );
        items.push(TransformItem {
            kind: entry.kind,
            from: entry.relative_path,
            to: next,
        });
    }

    ensure!(
        !items.is_empty(),
        "no marked entries selected for transform"
    );

    Ok(TransformPlan { scope_root, items })
}

fn render_transform_plan(plan: &TransformPlan) -> String {
    let mut rendered = String::new();
    let _ = writeln!(rendered, "SCOPE {}", plan.scope_root.display());
    for item in &plan.items {
        let _ = writeln!(
            rendered,
            "TRANSFORM {} {} -> {}",
            item.kind.label(),
            item.kind.render_path(&item.from),
            item.kind.render_path(&item.to)
        );
    }
    rendered
}

fn execute_transform_plan(session: &Session, plan: &TransformPlan) -> Result<()> {
    for item in &plan.items {
        fs::rename(
            plan.scope_root.join(&item.from),
            plan.scope_root.join(&item.to),
        )
        .with_context(|| {
            format!(
                "failed to rename {} to {}",
                plan.scope_root.join(&item.from).display(),
                plan.scope_root.join(&item.to).display()
            )
        })?;
    }
    let _ = session;
    Ok(())
}

fn apply_transform(kind: &TransformKind, regex: Option<&Regex>, input: &str) -> Result<String> {
    Ok(match kind {
        TransformKind::Regex { replace, .. } => regex
            .context("missing compiled regex")?
            .replace_all(input, replace.as_str())
            .into_owned(),
        TransformKind::Prefix { value } => format!("{value}{input}"),
        TransformKind::Suffix { value } => format!("{input}{value}"),
        TransformKind::Lower => input.to_lowercase(),
        TransformKind::Upper => input.to_uppercase(),
    })
}

fn resolve_target_root(
    current_root: &Path,
    target: Option<&Path>,
    target_manifest: Option<&Path>,
    alternate_manifest: Option<&Path>,
    alternate_state_path: Option<&Path>,
) -> Result<PathBuf> {
    if let Some(target) = target {
        return target
            .canonicalize()
            .with_context(|| format!("failed to canonicalize target {}", target.display()));
    }
    if let Some(target_manifest) = target_manifest {
        return Ok(load_session(target_manifest)?.sidecar.root);
    }
    if let Some(alternate_manifest) = alternate_manifest {
        return Ok(load_session(alternate_manifest)?.sidecar.root);
    }
    if let Some(alternate_state_path) = alternate_state_path
        && let Ok(contents) = fs::read_to_string(alternate_state_path)
    {
        let remembered = PathBuf::from(contents.trim());
        if remembered.exists() {
            return Ok(load_session(&remembered)?.sidecar.root);
        }
    }
    Ok(current_root.to_path_buf())
}

fn marked_entries(document: &ManifestDocument) -> Result<Vec<ManifestEntry>> {
    let marked: Vec<ManifestEntry> = document
        .entries()
        .into_iter()
        .filter(|entry| entry.mark == EntryMark::Marked)
        .collect();
    ensure!(!marked.is_empty(), "no marked entries selected");
    Ok(marked)
}

fn single_scope(entries: &[ManifestEntry]) -> Result<EntryScope> {
    let mut scopes = entries.iter().map(|entry| entry.scope.clone());
    let first = scopes.next().context("no entries selected")?;
    ensure!(
        scopes.all(|scope| scope == first),
        "marked entries span multiple roots; operate on one directory scope at a time"
    );
    Ok(first)
}

fn copy_path(source: &Path, destination: &Path) -> Result<()> {
    let metadata = fs::symlink_metadata(source)
        .with_context(|| format!("failed to inspect {}", source.display()))?;
    if metadata.is_dir() {
        fs::create_dir(destination)
            .with_context(|| format!("failed to create {}", destination.display()))?;
        for child in
            fs::read_dir(source).with_context(|| format!("failed to read {}", source.display()))?
        {
            let child = child?;
            copy_path(&child.path(), &destination.join(child.file_name()))?;
        }
        Ok(())
    } else {
        fs::copy(source, destination).with_context(|| {
            format!(
                "failed to copy {} to {}",
                source.display(),
                destination.display()
            )
        })?;
        Ok(())
    }
}

fn diff_paths(path: &Path, base: &Path) -> Result<PathBuf> {
    let path = path.canonicalize()?;
    let base = base.canonicalize()?;
    let path_components: Vec<_> = path.components().collect();
    let base_components: Vec<_> = base.components().collect();
    let shared = path_components
        .iter()
        .zip(&base_components)
        .take_while(|(left, right)| left == right)
        .count();

    let mut result = PathBuf::new();
    for _ in shared..base_components.len() {
        result.push("..");
    }
    for component in &path_components[shared..] {
        result.push(component.as_os_str());
    }
    Ok(result)
}

fn refresh_target_manifest_if_needed(
    target_manifest: Option<&Path>,
    alternate_manifest: Option<&Path>,
) -> Result<()> {
    if let Some(target_manifest) = target_manifest {
        let _ = refresh_session(target_manifest)?;
    } else if let Some(alternate_manifest) = alternate_manifest {
        let _ = refresh_session(alternate_manifest)?;
    }
    Ok(())
}

fn manifest_line_number(line: &ManifestLine) -> usize {
    match line {
        ManifestLine::Blank { line_number }
        | ManifestLine::Comment { line_number, .. }
        | ManifestLine::SubdirStart { line_number, .. }
        | ManifestLine::SubdirEnd { line_number, .. } => *line_number,
        ManifestLine::Entry(entry) => entry.line_number,
    }
}

fn entry_at_line_mut(
    document: &mut ManifestDocument,
    line_number: usize,
) -> Result<&mut ManifestEntry> {
    for line in &mut document.lines {
        if let ManifestLine::Entry(entry) = line
            && entry.line_number == line_number
        {
            return Ok(entry);
        }
    }
    bail!("line {line_number} is not an editable manifest entry")
}

fn line_index_for_entry(document: &ManifestDocument, line_number: usize) -> Result<usize> {
    document
        .lines
        .iter()
        .position(
            |line| matches!(line, ManifestLine::Entry(entry) if entry.line_number == line_number),
        )
        .context("line is not an editable manifest entry")
}

fn subdir_for_line(document: &ManifestDocument, line_number: usize) -> Result<String> {
    for line in &document.lines {
        match line {
            ManifestLine::Entry(entry) if entry.line_number == line_number => {
                if let EntryScope::Subdir(path) = &entry.scope {
                    return Ok(path.clone());
                }
            }
            ManifestLine::SubdirStart {
                name,
                line_number: current,
            }
            | ManifestLine::SubdirEnd {
                name,
                line_number: current,
            } if *current == line_number => {
                return Ok(name.clone());
            }
            _ => {}
        }
    }
    bail!("line {line_number} is not inside an inserted subdir block")
}

fn remove_subdir_block(document: &mut ManifestDocument, target: &str) -> Result<()> {
    let start = document
        .lines
        .iter()
        .position(|line| matches!(line, ManifestLine::SubdirStart { name, .. } if name == target))
        .context("subdir block start not found")?;
    let end = document
        .lines
        .iter()
        .position(|line| matches!(line, ManifestLine::SubdirEnd { name, .. } if name == target))
        .context("subdir block end not found")?;
    document.lines.drain(start..=end);
    Ok(())
}

fn replace_subdir_entries(
    document: &mut ManifestDocument,
    target: &str,
    entries: Vec<SnapshotEntry>,
) -> Result<()> {
    let start = document
        .lines
        .iter()
        .position(|line| matches!(line, ManifestLine::SubdirStart { name, .. } if name == target))
        .context("subdir block start not found")?;
    let end = document
        .lines
        .iter()
        .position(|line| matches!(line, ManifestLine::SubdirEnd { name, .. } if name == target))
        .context("subdir block end not found")?;

    let replacement = entries.into_iter().map(|snapshot| {
        ManifestLine::Entry(ManifestEntry {
            relative_path: snapshot.relative_path,
            kind: snapshot.kind,
            line_number: 0,
            mark: EntryMark::None,
            scope: EntryScope::Subdir(target.to_owned()),
        })
    });
    document.lines.splice(start + 1..end, replacement);
    Ok(())
}

fn upgrade_sidecar(sidecar: &mut Sidecar) {
    let mut next = sidecar.next_entry_id.max(1);
    for entry in &sidecar.entries {
        next = next.max(entry.id.saturating_add(1));
    }
    for state in &sidecar.subdirs {
        for entry in &state.entries {
            next = next.max(entry.id.saturating_add(1));
        }
    }

    for entry in &mut sidecar.entries {
        if entry.id == 0 {
            entry.id = next;
            next += 1;
        }
    }
    for state in &mut sidecar.subdirs {
        for entry in &mut state.entries {
            if entry.id == 0 {
                entry.id = next;
                next += 1;
            }
        }
    }

    sidecar.next_entry_id = next;
    sidecar.version = SIDECAR_VERSION;
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
        assert!(rendered.contains("  drafts/\n  notes.md\n"));

        let parsed = parse_manifest_text(&rendered)?;
        assert_eq!(
            parsed,
            vec![
                ManifestEntry {
                    relative_path: "drafts".to_owned(),
                    kind: EntryKind::Directory,
                    line_number: 3,
                    mark: EntryMark::None,
                    scope: EntryScope::Root,
                },
                ManifestEntry {
                    relative_path: "notes.md".to_owned(),
                    kind: EntryKind::File,
                    line_number: 4,
                    mark: EntryMark::None,
                    scope: EntryScope::Root,
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
        assert!(refreshed.contains("  drafts/\n  ideas.txt\n  keep.txt\n  tail.txt\n"));
        Ok(())
    }

    #[test]
    fn delete_flags_compose_with_removed_lines() -> Result<()> {
        let (_temp, root, state) = sandbox()?;
        touch_file(&root.join("a.txt"), "a")?;
        touch_file(&root.join("b.txt"), "b")?;
        touch_file(&root.join("c.txt"), "c")?;

        let manifest = render(&root, &state)?;
        write_manifest_entries(&manifest, &["D a.txt", "  b.txt"])?;

        let dry_run = dry_run_apply(&manifest)?;
        assert!(dry_run.contains("DELETE FILE a.txt"));
        assert!(dry_run.contains("DELETE FILE c.txt"));
        Ok(())
    }

    #[test]
    fn mark_toggle_clear_and_flag_preserve_text_edits() -> Result<()> {
        let (_temp, root, state) = sandbox()?;
        touch_file(&root.join("alpha.txt"), "a")?;
        touch_file(&root.join("beta.txt"), "b")?;

        let manifest = render(&root, &state)?;
        write_manifest_entries(&manifest, &["  renamed.txt", "  beta.txt"])?;
        mark_toggle(&manifest, &[3])?;
        flag_delete(&manifest, &[4])?;
        clear_marks(&manifest)?;

        let text = fs::read_to_string(&manifest)?;
        assert!(text.contains("  renamed.txt"));
        assert!(text.contains("D beta.txt"));
        Ok(())
    }

    #[test]
    fn bulk_copy_move_and_relative_symlink_preview() -> Result<()> {
        let (_temp, root, state) = sandbox()?;
        let target = root.join("target");
        fs::create_dir(&target)?;
        touch_file(&root.join("alpha.txt"), "a")?;

        let manifest = render(&root, &state)?;
        write_manifest_entries(&manifest, &["* alpha.txt", "  target/"])?;
        let target_manifest = render_session(&target, &state)?;

        let copy = run_bulk_op(
            &manifest,
            BulkKind::Copy,
            false,
            None,
            Some(&target_manifest),
            None,
        )?;
        assert!(copy.contains(&format!("TARGET {}", target.display())));
        assert!(copy.contains("COPY FILE alpha.txt"));

        let rel = run_bulk_op(
            &manifest,
            BulkKind::RelativeSymlink,
            false,
            None,
            Some(&target_manifest),
            None,
        )?;
        assert!(rel.contains("RELSYMLINK FILE alpha.txt"));
        Ok(())
    }

    #[test]
    fn bulk_move_uses_alternate_manifest_target() -> Result<()> {
        let (_temp, root, state) = sandbox()?;
        let target = root.join("target");
        fs::create_dir(&target)?;
        touch_file(&root.join("alpha.txt"), "a")?;

        let manifest = render(&root, &state)?;
        write_manifest_entries(&manifest, &["* alpha.txt", "  target/"])?;
        let target_manifest = render_session(&target, &state)?;

        let preview = run_bulk_op(
            &manifest,
            BulkKind::Move,
            false,
            None,
            None,
            Some(&target_manifest),
        )?;
        assert!(preview.contains(&format!("TARGET {}", target.display())));
        Ok(())
    }

    #[test]
    fn transform_preview_and_collision_rejection() -> Result<()> {
        let (_temp, root, state) = sandbox()?;
        touch_file(&root.join("alpha.txt"), "a")?;
        touch_file(&root.join("beta.txt"), "b")?;

        let manifest = render(&root, &state)?;
        write_manifest_entries(&manifest, &["* alpha.txt", "  beta.txt"])?;
        let preview = run_transform(
            &manifest,
            TransformKind::Prefix {
                value: "new-".to_owned(),
            },
            false,
        )?;
        assert!(preview.contains("TRANSFORM FILE alpha.txt -> new-alpha.txt"));

        let collision = run_transform(
            &manifest,
            TransformKind::Regex {
                pattern: "alpha".to_owned(),
                replace: "beta".to_owned(),
            },
            false,
        )
        .unwrap_err()
        .to_string();
        assert!(collision.contains("collision"));
        Ok(())
    }

    #[test]
    fn inline_subdir_insert_refresh_and_collapse() -> Result<()> {
        let (_temp, root, state) = sandbox()?;
        fs::create_dir(root.join("drafts"))?;
        touch_file(&root.join("drafts").join("a.md"), "a")?;

        let manifest = render(&root, &state)?;
        insert_subdir(&manifest, 3)?;
        let inserted = fs::read_to_string(&manifest)?;
        assert!(inserted.contains("# hx-oil subdir: drafts"));
        assert!(inserted.contains("      a.md"));

        touch_file(&root.join("drafts").join("b.md"), "b")?;
        refresh_subdir(&manifest, 4)?;
        let refreshed = fs::read_to_string(&manifest)?;
        assert!(refreshed.contains("      b.md"));

        collapse_subdir(&manifest, 4)?;
        let collapsed = fs::read_to_string(&manifest)?;
        assert!(!collapsed.contains("# hx-oil subdir: drafts"));
        Ok(())
    }

    #[test]
    fn reject_nested_inline_subdir_insertion() -> Result<()> {
        let (_temp, root, state) = sandbox()?;
        fs::create_dir(root.join("drafts"))?;
        fs::create_dir(root.join("drafts").join("nested"))?;

        let manifest = render(&root, &state)?;
        insert_subdir(&manifest, 3)?;

        let error = insert_subdir(&manifest, 5).unwrap_err().to_string();
        assert!(error.contains("bounded nesting"));
        Ok(())
    }

    #[test]
    fn reject_reordered_entries() -> Result<()> {
        let (_temp, root, state) = sandbox()?;
        touch_file(&root.join("a.txt"), "a")?;
        touch_file(&root.join("b.txt"), "b")?;

        let manifest = render(&root, &state)?;
        write_manifest_entries(&manifest, &["  b.txt", "  a.txt"])?;

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
        write_manifest_entries(&manifest, &["  keep.txt"])?;

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
        write_manifest_entries(&manifest, &["  same.txt", "  same.txt"])?;

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
        write_manifest_entries(&manifest, &["  renamed.txt"])?;
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
        assert!(refreshed.contains("  keep.txt\n  new.txt\n"));
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
