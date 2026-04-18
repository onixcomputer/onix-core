use std::fs;
use std::path::Path;
use std::process::Command;

use tempfile::TempDir;

fn sandbox() -> (TempDir, std::path::PathBuf, std::path::PathBuf) {
    let temp = TempDir::new().unwrap();
    let root = temp.path().join("root");
    let state = temp.path().join("state");
    fs::create_dir_all(&root).unwrap();
    fs::create_dir_all(&state).unwrap();
    (temp, root, state)
}

fn hx_oil() -> Command {
    Command::new(env!("CARGO_BIN_EXE_hx-oil"))
}

fn run(command: &mut Command, state: &Path) -> String {
    let output = command.env("XDG_STATE_HOME", state).output().unwrap();
    assert!(
        output.status.success(),
        "stderr: {}",
        String::from_utf8_lossy(&output.stderr)
    );
    String::from_utf8(output.stdout).unwrap()
}

#[test]
fn render_prints_only_manifest_path() {
    let (_temp, root, state) = sandbox();
    fs::write(root.join("keep.txt"), "k").unwrap();

    let stdout = run(
        hx_oil().args(["render", "--from", root.to_str().unwrap()]),
        &state,
    );
    let manifest = stdout.trim();

    assert!(manifest.ends_with("manifest.hxoil"));
    assert!(Path::new(manifest).exists());
    assert_eq!(stdout.lines().count(), 1);
}

#[test]
fn open_at_line_comment_is_noop() {
    let (_temp, root, state) = sandbox();
    fs::write(root.join("keep.txt"), "k").unwrap();

    let manifest = run(
        hx_oil().args(["render", "--from", root.to_str().unwrap()]),
        &state,
    );
    let manifest = manifest.trim().to_owned();

    let stdout = run(hx_oil().args(["open-at-line", &manifest, "1"]), &state);

    assert_eq!(stdout.trim(), manifest);
}
