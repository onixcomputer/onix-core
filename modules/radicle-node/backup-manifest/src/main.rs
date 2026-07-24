use std::env;
use std::ffi::{OsStr, OsString};
use std::fs::{self, File, Metadata, OpenOptions};
use std::io::{BufRead, BufReader, BufWriter, Read, Write};
use std::os::unix::ffi::{OsStrExt, OsStringExt};
use std::os::unix::fs::MetadataExt;
use std::path::{Component, Path, PathBuf};
use std::process;

const MANIFEST_HEADER: &str = "RADICLE_BACKUP_B3_V1";
const FILE_BUFFER_BYTES: usize = 64 * 1024;
const COMPARE_BUFFER_BYTES: usize = 64 * 1024;
const PERMISSION_MODE_MASK: u32 = 0o7777;
const RECORD_FIELD_COUNT: usize = 7;
const PATH_FIELD_INDEX: usize = RECORD_FIELD_COUNT - 1;
const COMMAND_ARGUMENT_COUNT: usize = 4;
const CREATE_COMMAND: &str = "create";
const VERIFY_COMMAND: &str = "verify";
const HASH_PLACEHOLDER: &str = "-";
const TEMPORARY_SUFFIX: &str = "partial";
const HEX_DIGIT_COUNT: usize = 16;
const HEX_CHARS_PER_BYTE: usize = 2;
const BITS_PER_HEX_DIGIT: u32 = 4;
const HEX_LOW_MASK: u8 = 15;
const DECIMAL_DIGIT_COUNT: u8 = 10;
const HEX_DIGITS: &[u8; HEX_DIGIT_COUNT] = b"0123456789abcdef";

#[derive(Clone, Copy, Debug, Eq, PartialEq)]
enum EntryKind {
    Directory,
    File,
    Symlink,
}

impl EntryKind {
    fn marker(self) -> &'static str {
        match self {
            Self::Directory => "D",
            Self::File => "F",
            Self::Symlink => "L",
        }
    }

    fn parse(marker: &str) -> Result<Self, String> {
        match marker {
            "D" => Ok(Self::Directory),
            "F" => Ok(Self::File),
            "L" => Ok(Self::Symlink),
            other => Err(format!("unsupported manifest entry kind: {other}")),
        }
    }
}

#[derive(Debug, Eq, PartialEq)]
struct ManifestRecord {
    kind: EntryKind,
    hash: String,
    size: u64,
    mode: u32,
    uid: u32,
    gid: u32,
    relative_path: PathBuf,
}

#[derive(Clone, Copy, Debug, Default, Eq, PartialEq)]
struct ManifestStats {
    records: u64,
    bytes: u64,
}

fn main() {
    if let Err(error) = run(env::args_os().collect()) {
        eprintln!("radicle-backup-manifest: {error}");
        process::exit(1);
    }
}

fn run(arguments: Vec<OsString>) -> Result<(), String> {
    if arguments.len() != COMMAND_ARGUMENT_COUNT {
        return Err(usage());
    }

    let command = arguments[1]
        .to_str()
        .ok_or_else(|| "command is not valid UTF-8".to_owned())?;
    let root = Path::new(&arguments[2]);
    let manifest = Path::new(&arguments[3]);

    match command {
        CREATE_COMMAND => {
            let stats = create_manifest_atomic(root, manifest)?;
            print_summary(manifest, stats)?;
        }
        VERIFY_COMMAND => {
            let stats = verify_manifest(root, manifest)?;
            print_summary(manifest, stats)?;
        }
        _ => return Err(usage()),
    }

    Ok(())
}

fn usage() -> String {
    "usage: radicle-backup-manifest <create|verify> <root> <manifest>".to_owned()
}

fn create_manifest_atomic(root: &Path, manifest: &Path) -> Result<ManifestStats, String> {
    validate_root(root)?;
    let temporary = temporary_manifest_path(manifest);
    let temporary_file = OpenOptions::new()
        .create_new(true)
        .write(true)
        .open(&temporary)
        .map_err(|error| format!("create temporary manifest {}: {error}", temporary.display()))?;

    let result = write_manifest(root, temporary_file);
    match result {
        Ok(stats) => {
            fs::rename(&temporary, manifest).map_err(|error| {
                format!(
                    "replace manifest {} with {}: {error}",
                    manifest.display(),
                    temporary.display()
                )
            })?;
            Ok(stats)
        }
        Err(error) => {
            let _ = fs::remove_file(&temporary);
            Err(error)
        }
    }
}

fn verify_manifest(root: &Path, manifest: &Path) -> Result<ManifestStats, String> {
    validate_root(root)?;
    let expected_stats = validate_manifest_format(manifest)?;
    let actual = temporary_manifest_path(manifest);
    let actual_file = OpenOptions::new()
        .create_new(true)
        .write(true)
        .open(&actual)
        .map_err(|error| format!("create verification manifest {}: {error}", actual.display()))?;

    let write_result = write_manifest(root, actual_file);
    if let Err(error) = write_result {
        let _ = fs::remove_file(&actual);
        return Err(error);
    }

    let comparison = files_equal(manifest, &actual);
    let _ = fs::remove_file(&actual);
    match comparison? {
        true => Ok(expected_stats),
        false => Err("manifest does not match the restored filesystem".to_owned()),
    }
}

fn validate_root(root: &Path) -> Result<(), String> {
    let metadata = fs::symlink_metadata(root)
        .map_err(|error| format!("inspect root {}: {error}", root.display()))?;
    if !metadata.file_type().is_dir() {
        return Err(format!(
            "manifest root is not a directory: {}",
            root.display()
        ));
    }
    Ok(())
}

fn temporary_manifest_path(manifest: &Path) -> PathBuf {
    let mut file_name = manifest
        .file_name()
        .unwrap_or_else(|| OsStr::new("manifest"))
        .to_os_string();
    file_name.push(format!(".{TEMPORARY_SUFFIX}.{}", process::id()));
    manifest.with_file_name(file_name)
}

fn write_manifest(root: &Path, file: File) -> Result<ManifestStats, String> {
    let root_metadata = fs::metadata(root)
        .map_err(|error| format!("inspect root filesystem {}: {error}", root.display()))?;
    let root_device = root_metadata.dev();
    let mut writer = BufWriter::new(file);
    writeln!(writer, "{MANIFEST_HEADER}")
        .map_err(|error| format!("write manifest header: {error}"))?;

    let mut stats = ManifestStats::default();
    walk_directory(root, Path::new(""), root_device, &mut writer, &mut stats)?;
    writer
        .flush()
        .map_err(|error| format!("flush manifest: {error}"))?;
    writer
        .get_ref()
        .sync_all()
        .map_err(|error| format!("sync manifest: {error}"))?;
    Ok(stats)
}

fn walk_directory(
    root: &Path,
    relative_directory: &Path,
    root_device: u64,
    writer: &mut BufWriter<File>,
    stats: &mut ManifestStats,
) -> Result<(), String> {
    let directory = root.join(relative_directory);
    let mut entries = fs::read_dir(&directory)
        .map_err(|error| format!("read directory {}: {error}", directory.display()))?
        .collect::<Result<Vec<_>, _>>()
        .map_err(|error| format!("read entry in {}: {error}", directory.display()))?;
    entries.sort_by(|left, right| {
        left.file_name()
            .as_bytes()
            .cmp(right.file_name().as_bytes())
    });

    for entry in entries {
        let relative_path = relative_directory.join(entry.file_name());
        validate_relative_path(&relative_path)?;
        let absolute_path = root.join(&relative_path);
        let metadata = fs::symlink_metadata(&absolute_path)
            .map_err(|error| format!("inspect {}: {error}", absolute_path.display()))?;
        if metadata.dev() != root_device {
            return Err(format!(
                "entry crosses the manifest root filesystem: {}",
                relative_path.display()
            ));
        }

        let record = record_for_path(&absolute_path, &relative_path, &metadata)?;
        write_record(writer, &record)?;
        stats.records = stats
            .records
            .checked_add(1)
            .ok_or_else(|| "manifest record count overflow".to_owned())?;
        stats.bytes = stats
            .bytes
            .checked_add(record.size)
            .ok_or_else(|| "manifest byte count overflow".to_owned())?;

        if record.kind == EntryKind::Directory {
            walk_directory(root, &relative_path, root_device, writer, stats)?;
        }
    }

    Ok(())
}

fn record_for_path(
    absolute_path: &Path,
    relative_path: &Path,
    metadata_before: &Metadata,
) -> Result<ManifestRecord, String> {
    let file_type = metadata_before.file_type();
    let (kind, hash, size) = if file_type.is_dir() {
        (EntryKind::Directory, HASH_PLACEHOLDER.to_owned(), 0)
    } else if file_type.is_file() {
        let hash = hash_file(absolute_path)?;
        let metadata_after = fs::metadata(absolute_path)
            .map_err(|error| format!("reinspect {}: {error}", absolute_path.display()))?;
        if file_identity_changed(metadata_before, &metadata_after) {
            return Err(format!(
                "file changed while hashing: {}",
                relative_path.display()
            ));
        }
        (EntryKind::File, hash, metadata_before.len())
    } else if file_type.is_symlink() {
        let target = fs::read_link(absolute_path)
            .map_err(|error| format!("read symlink {}: {error}", absolute_path.display()))?;
        let target_bytes = target.as_os_str().as_bytes();
        let size = u64::try_from(target_bytes.len())
            .map_err(|_| format!("symlink target is too large: {}", relative_path.display()))?;
        (
            EntryKind::Symlink,
            blake3::hash(target_bytes).to_hex().to_string(),
            size,
        )
    } else {
        return Err(format!(
            "unsupported filesystem entry in manifest root: {}",
            relative_path.display()
        ));
    };

    Ok(ManifestRecord {
        kind,
        hash,
        size,
        mode: metadata_before.mode() & PERMISSION_MODE_MASK,
        uid: metadata_before.uid(),
        gid: metadata_before.gid(),
        relative_path: relative_path.to_path_buf(),
    })
}

fn file_identity_changed(before: &Metadata, after: &Metadata) -> bool {
    before.dev() != after.dev()
        || before.ino() != after.ino()
        || before.len() != after.len()
        || before.mtime() != after.mtime()
        || before.mtime_nsec() != after.mtime_nsec()
        || before.ctime() != after.ctime()
        || before.ctime_nsec() != after.ctime_nsec()
}

fn hash_file(path: &Path) -> Result<String, String> {
    let mut file = File::open(path).map_err(|error| format!("open {}: {error}", path.display()))?;
    let mut hasher = blake3::Hasher::new();
    let mut buffer = [0_u8; FILE_BUFFER_BYTES];
    loop {
        let count = file
            .read(&mut buffer)
            .map_err(|error| format!("read {}: {error}", path.display()))?;
        if count == 0 {
            break;
        }
        hasher.update(&buffer[..count]);
    }
    Ok(hasher.finalize().to_hex().to_string())
}

fn write_record(writer: &mut BufWriter<File>, record: &ManifestRecord) -> Result<(), String> {
    let path_hex = hex_encode(record.relative_path.as_os_str().as_bytes());
    writeln!(
        writer,
        "{} {} {} {:o} {} {} {}",
        record.kind.marker(),
        record.hash,
        record.size,
        record.mode,
        record.uid,
        record.gid,
        path_hex
    )
    .map_err(|error| format!("write manifest record: {error}"))
}

fn validate_manifest_format(manifest: &Path) -> Result<ManifestStats, String> {
    let file = File::open(manifest)
        .map_err(|error| format!("open manifest {}: {error}", manifest.display()))?;
    let mut lines = BufReader::new(file).lines();
    let header = lines
        .next()
        .ok_or_else(|| "manifest is empty".to_owned())?
        .map_err(|error| format!("read manifest header: {error}"))?;
    if header != MANIFEST_HEADER {
        return Err("manifest header is invalid".to_owned());
    }

    let mut stats = ManifestStats::default();
    let mut previous_path: Option<Vec<u8>> = None;
    for line in lines {
        let line = line.map_err(|error| format!("read manifest record: {error}"))?;
        let record = parse_record(&line)?;
        let path_bytes = record.relative_path.as_os_str().as_bytes();
        if let Some(previous) = &previous_path
            && previous.as_slice() >= path_bytes
        {
            return Err("manifest paths are not strictly ordered".to_owned());
        }
        previous_path = Some(path_bytes.to_vec());
        stats.records = stats
            .records
            .checked_add(1)
            .ok_or_else(|| "manifest record count overflow".to_owned())?;
        stats.bytes = stats
            .bytes
            .checked_add(record.size)
            .ok_or_else(|| "manifest byte count overflow".to_owned())?;
    }
    Ok(stats)
}

fn parse_record(line: &str) -> Result<ManifestRecord, String> {
    let fields = line.split(' ').collect::<Vec<_>>();
    if fields.len() != RECORD_FIELD_COUNT {
        return Err("manifest record has the wrong field count".to_owned());
    }

    let kind = EntryKind::parse(fields[0])?;
    let hash = fields[1].to_owned();
    match kind {
        EntryKind::Directory if hash != HASH_PLACEHOLDER => {
            return Err("directory record must use the hash placeholder".to_owned());
        }
        EntryKind::File | EntryKind::Symlink if !valid_blake3_hex(&hash) => {
            return Err("file or symlink record has an invalid BLAKE3 hash".to_owned());
        }
        _ => {}
    }

    let size = fields[2]
        .parse::<u64>()
        .map_err(|_| "manifest record size is invalid".to_owned())?;
    let mode = u32::from_str_radix(fields[3], 8)
        .map_err(|_| "manifest record mode is invalid".to_owned())?;
    if mode & !PERMISSION_MODE_MASK != 0 {
        return Err("manifest record mode exceeds the permission mask".to_owned());
    }
    let uid = fields[4]
        .parse::<u32>()
        .map_err(|_| "manifest record uid is invalid".to_owned())?;
    let gid = fields[5]
        .parse::<u32>()
        .map_err(|_| "manifest record gid is invalid".to_owned())?;
    let relative_path = PathBuf::from(OsString::from_vec(hex_decode(fields[PATH_FIELD_INDEX])?));
    validate_relative_path(&relative_path)?;

    Ok(ManifestRecord {
        kind,
        hash,
        size,
        mode,
        uid,
        gid,
        relative_path,
    })
}

fn validate_relative_path(path: &Path) -> Result<(), String> {
    if path.as_os_str().is_empty() || path.is_absolute() {
        return Err("manifest path must be non-empty and relative".to_owned());
    }
    for component in path.components() {
        match component {
            Component::Normal(_) => {}
            _ => return Err("manifest path contains a forbidden component".to_owned()),
        }
    }
    Ok(())
}

fn valid_blake3_hex(value: &str) -> bool {
    value.len() == blake3::OUT_LEN * HEX_CHARS_PER_BYTE
        && value
            .bytes()
            .all(|byte| byte.is_ascii_digit() || (b'a'..=b'f').contains(&byte))
}

fn hex_encode(bytes: &[u8]) -> String {
    let mut output = String::with_capacity(bytes.len() * HEX_CHARS_PER_BYTE);
    for byte in bytes {
        output.push(char::from(
            HEX_DIGITS[usize::from(byte >> BITS_PER_HEX_DIGIT)],
        ));
        output.push(char::from(HEX_DIGITS[usize::from(byte & HEX_LOW_MASK)]));
    }
    output
}

fn hex_decode(value: &str) -> Result<Vec<u8>, String> {
    if !value.len().is_multiple_of(HEX_CHARS_PER_BYTE) {
        return Err("manifest path hex has an odd length".to_owned());
    }
    let mut bytes = Vec::with_capacity(value.len() / HEX_CHARS_PER_BYTE);
    for pair in value.as_bytes().chunks_exact(HEX_CHARS_PER_BYTE) {
        let high = hex_value(pair[0])?;
        let low = hex_value(pair[1])?;
        bytes.push((high << 4) | low);
    }
    Ok(bytes)
}

fn hex_value(value: u8) -> Result<u8, String> {
    match value {
        b'0'..=b'9' => Ok(value - b'0'),
        b'a'..=b'f' => Ok(value - b'a' + DECIMAL_DIGIT_COUNT),
        _ => Err("manifest path contains invalid hex".to_owned()),
    }
}

fn files_equal(left: &Path, right: &Path) -> Result<bool, String> {
    let mut left_file = File::open(left)
        .map_err(|error| format!("open expected manifest {}: {error}", left.display()))?;
    let mut right_file = File::open(right)
        .map_err(|error| format!("open actual manifest {}: {error}", right.display()))?;
    let mut left_buffer = [0_u8; COMPARE_BUFFER_BYTES];
    let mut right_buffer = [0_u8; COMPARE_BUFFER_BYTES];

    loop {
        let left_count = left_file
            .read(&mut left_buffer)
            .map_err(|error| format!("read expected manifest: {error}"))?;
        let right_count = right_file
            .read(&mut right_buffer)
            .map_err(|error| format!("read actual manifest: {error}"))?;
        if left_count != right_count {
            return Ok(false);
        }
        if left_count == 0 {
            return Ok(true);
        }
        if left_buffer[..left_count] != right_buffer[..right_count] {
            return Ok(false);
        }
    }
}

fn print_summary(manifest: &Path, stats: ManifestStats) -> Result<(), String> {
    let digest = hash_file(manifest)?;
    println!("manifest_blake3={digest}");
    println!("records={}", stats.records);
    println!("bytes={}", stats.bytes);
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::os::unix::fs::{PermissionsExt, symlink};

    fn test_root(name: &str) -> PathBuf {
        env::temp_dir().join(format!("radicle-backup-manifest-{name}-{}", process::id()))
    }

    fn reset(path: &Path) {
        let _ = fs::remove_dir_all(path);
        fs::create_dir_all(path).expect("create test root");
    }

    #[test]
    fn hex_round_trip_preserves_non_utf8_paths() {
        let input = b"repo-\xff-object";
        let encoded = hex_encode(input);
        let decoded = hex_decode(&encoded).expect("decode path");
        assert_eq!(decoded, input);
    }

    #[test]
    fn record_round_trip_preserves_metadata() {
        const CONTENT_BYTES: u64 = 7;
        const TEST_MODE: u32 = 0o640;
        const TEST_UID: u32 = 1000;
        const TEST_GID: u32 = 100;

        let record = ManifestRecord {
            kind: EntryKind::File,
            hash: blake3::hash(b"content").to_hex().to_string(),
            size: CONTENT_BYTES,
            mode: TEST_MODE,
            uid: TEST_UID,
            gid: TEST_GID,
            relative_path: PathBuf::from("storage/repo/objects/aa"),
        };
        let root = test_root("record");
        reset(&root);
        let output = root.join("record.txt");
        let file = File::create(&output).expect("create record file");
        let mut writer = BufWriter::new(file);
        write_record(&mut writer, &record).expect("write record");
        writer.flush().expect("flush record");
        let line = fs::read_to_string(&output).expect("read record");
        let parsed = parse_record(line.trim_end()).expect("parse record");
        assert_eq!(parsed, record);
        fs::remove_dir_all(root).expect("remove test root");
    }

    #[test]
    fn rejects_path_traversal_and_malformed_hashes() {
        assert!(validate_relative_path(Path::new("../secret")).is_err());
        assert!(validate_relative_path(Path::new("/absolute")).is_err());
        let traversal_hex = hex_encode(b"../secret");
        let malformed = format!("F short 1 600 0 0 {traversal_hex}");
        assert!(parse_record(&malformed).is_err());
    }

    #[test]
    fn create_and_verify_detects_content_and_permission_changes() {
        const MINIMUM_EXPECTED_RECORDS: u64 = 4;
        const MUTATED_FILE_MODE: u32 = 0o600;

        let root = test_root("integration");
        reset(&root);
        let source = root.join("source");
        fs::create_dir_all(source.join("nested")).expect("create source tree");
        fs::write(source.join("one"), b"alpha").expect("write first file");
        fs::write(source.join("nested/two"), b"beta").expect("write second file");
        symlink("one", source.join("link")).expect("create symlink");
        let manifest = root.join("manifest.b3m");

        let created = create_manifest_atomic(&source, &manifest).expect("create manifest");
        let verified = verify_manifest(&source, &manifest).expect("verify manifest");
        assert_eq!(created, verified);
        assert!(created.records >= MINIMUM_EXPECTED_RECORDS);

        fs::write(source.join("one"), b"changed").expect("mutate content");
        assert!(verify_manifest(&source, &manifest).is_err());

        fs::write(source.join("one"), b"alpha").expect("restore content");
        create_manifest_atomic(&source, &manifest).expect("replace manifest");
        let permissions = fs::Permissions::from_mode(MUTATED_FILE_MODE);
        fs::set_permissions(source.join("one"), permissions).expect("mutate permissions");
        assert!(verify_manifest(&source, &manifest).is_err());
        fs::remove_dir_all(root).expect("remove test root");
    }

    #[test]
    fn verification_rejects_extra_files() {
        let root = test_root("extra-file");
        reset(&root);
        let source = root.join("source");
        fs::create_dir_all(&source).expect("create source");
        fs::write(source.join("one"), b"alpha").expect("write source file");
        let manifest = root.join("manifest.b3m");
        create_manifest_atomic(&source, &manifest).expect("create manifest");
        fs::write(source.join("extra"), b"unexpected").expect("write extra file");
        assert!(verify_manifest(&source, &manifest).is_err());
        fs::remove_dir_all(root).expect("remove test root");
    }
}
