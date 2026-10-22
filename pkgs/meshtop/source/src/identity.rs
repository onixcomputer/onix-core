use std::fs::{self, File, OpenOptions};
use std::io::{self, Read, Write};
use std::path::{Path, PathBuf};

use anyhow::{Context, Result};
use iroh::SecretKey;

pub fn default_path(agent: bool) -> Result<PathBuf> {
    let home = std::env::var_os("HOME").context("HOME is unset; pass --key explicitly")?;
    Ok(PathBuf::from(home)
        .join(".local/state/meshtop")
        .join(if agent { "agent.key" } else { "viewer.key" }))
}

/// Stable 32-byte seed. Never silently replace an existing, invalid identity.
pub fn load_or_create(path: &Path) -> Result<SecretKey> {
    match open_existing(path) {
        Ok(mut file) => {
            let mut bytes = [0_u8; 32];
            file.read_exact(&mut bytes)
                .context("reading identity seed")?;
            Ok(SecretKey::from_bytes(&bytes))
        }
        Err(error) if error.kind() == io::ErrorKind::NotFound => create(path),
        Err(error) => Err(error).with_context(|| format!("opening identity {}", path.display())),
    }
}

fn create(path: &Path) -> Result<SecretKey> {
    if let Some(parent) = path.parent() {
        fs::create_dir_all(parent).with_context(|| format!("creating {}", parent.display()))?;
    }
    let mut options = OpenOptions::new();
    options.write(true).create_new(true);
    #[cfg(unix)]
    {
        use std::os::unix::fs::OpenOptionsExt;
        options.mode(0o600).custom_flags(libc::O_NOFOLLOW);
    }
    match options.open(path) {
        Ok(mut file) => {
            let key = SecretKey::generate();
            file.write_all(&key.to_bytes())
                .context("writing identity seed")?;
            file.sync_all().context("syncing identity seed")?;
            Ok(key)
        }
        Err(error) if error.kind() == io::ErrorKind::AlreadyExists => {
            // Another instance created it first; only accept a complete, correctly protected file.
            let mut file = open_existing(path)?;
            let mut bytes = [0_u8; 32];
            file.read_exact(&mut bytes)
                .context("reading concurrent identity seed")?;
            Ok(SecretKey::from_bytes(&bytes))
        }
        Err(error) => Err(error).with_context(|| format!("creating identity {}", path.display())),
    }
}

fn open_existing(path: &Path) -> io::Result<File> {
    let mut options = OpenOptions::new();
    options.read(true);
    #[cfg(unix)]
    {
        use std::os::unix::fs::OpenOptionsExt;
        options.custom_flags(libc::O_NOFOLLOW);
    }
    let file = options.open(path)?;
    let metadata = file.metadata()?;
    if !metadata.is_file() || metadata.len() != 32 {
        return Err(io::Error::new(
            io::ErrorKind::InvalidData,
            "identity must be a 32-byte regular file",
        ));
    }
    #[cfg(unix)]
    {
        use std::os::unix::fs::{MetadataExt, PermissionsExt};
        if metadata.permissions().mode() & 0o777 != 0o600
            || metadata.uid() != unsafe { libc::geteuid() }
        {
            return Err(io::Error::new(
                io::ErrorKind::PermissionDenied,
                "identity must be owned by this user and mode 0600",
            ));
        }
    }
    Ok(file)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn identity_survives_restart_and_does_not_replace_invalid_file() {
        let dir = tempfile::tempdir().unwrap();
        let path = dir.path().join("agent.key");
        let id = load_or_create(&path).unwrap().public();
        assert_eq!(id, load_or_create(&path).unwrap().public());
        fs::write(&path, b"bad").unwrap();
        assert!(load_or_create(&path).is_err());
    }

    #[cfg(unix)]
    #[test]
    fn rejects_permissive_file_and_symlink() {
        use std::os::unix::fs::{PermissionsExt, symlink};
        let dir = tempfile::tempdir().unwrap();
        let path = dir.path().join("agent.key");
        load_or_create(&path).unwrap();
        fs::set_permissions(&path, fs::Permissions::from_mode(0o644)).unwrap();
        assert!(load_or_create(&path).is_err());
        fs::set_permissions(&path, fs::Permissions::from_mode(0o600)).unwrap();
        let link = dir.path().join("link.key");
        symlink(&path, &link).unwrap();
        assert!(load_or_create(&link).is_err());
    }
}
