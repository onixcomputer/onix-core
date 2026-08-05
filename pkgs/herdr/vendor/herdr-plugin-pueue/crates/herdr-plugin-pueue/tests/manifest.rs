const MANIFEST: &str = include_str!(concat!(
    env!("CARGO_MANIFEST_DIR"),
    "/../../herdr-plugin.toml"
));
const PLUGIN_ID: &str = "dev.herdr.pueue";
const MINIMUM_HERDR_VERSION: &str = "0.7.5";
const LINUX_PLATFORM: &str = "linux";
const SUPPORTED_PLATFORM_COUNT: usize = 1;
const POPUP_ACTION_ID: &str = "open-dashboard";
const SPLIT_ACTION_ID: &str = "open-dashboard-split";
const POPUP_PANE_ID: &str = "dashboard";
const SPLIT_PANE_ID: &str = "dashboard-split";
const POPUP_PLACEMENT: &str = "popup";
const SPLIT_PLACEMENT: &str = "split";
const PLUGIN_BINARY_PATH: &str = "./target/release/herdr-plugin-pueue";
const BUILD_COMMAND_ARGUMENT_COUNT: usize = 8;
const TARGET_DIRECTORY_OPTION: &str = "--target-dir";
const TARGET_DIRECTORY: &str = "target";

fn section_by_id<'a>(
    manifest: &'a toml::Value,
    section: &str,
    id: &str,
) -> Option<&'a toml::Value> {
    manifest[section]
        .as_array()?
        .iter()
        .find(|entry| entry["id"].as_str() == Some(id))
}

fn command_program(entry: &toml::Value) -> Option<&str> {
    entry["command"]
        .as_array()?
        .first()
        .and_then(toml::Value::as_str)
}

#[test]
fn manifest_declares_linux_popup_and_split_contracts() -> Result<(), Box<dyn std::error::Error>> {
    // r[verify herdr.pueue_plugin.distribution.open]
    // r[verify herdr.pueue_plugin.distribution.split]
    let manifest: toml::Value = toml::from_str(MANIFEST)?;
    assert_eq!(manifest["id"].as_str(), Some(PLUGIN_ID));
    assert_eq!(
        manifest["min_herdr_version"].as_str(),
        Some(MINIMUM_HERDR_VERSION)
    );
    let platforms = manifest["platforms"]
        .as_array()
        .ok_or("platforms must be an array")?;
    assert_eq!(platforms.len(), SUPPORTED_PLATFORM_COUNT);
    assert_eq!(
        platforms.first().and_then(toml::Value::as_str),
        Some(LINUX_PLATFORM)
    );

    let build_command = manifest["build"]
        .as_array()
        .and_then(|commands| commands.first())
        .and_then(|entry| entry["command"].as_array())
        .ok_or("build command must be present")?;
    assert_eq!(build_command.len(), BUILD_COMMAND_ARGUMENT_COUNT);
    assert!(build_command.windows(2).any(|arguments| {
        arguments[0].as_str() == Some(TARGET_DIRECTORY_OPTION)
            && arguments[1].as_str() == Some(TARGET_DIRECTORY)
    }));

    let popup_action = section_by_id(&manifest, "actions", POPUP_ACTION_ID)
        .ok_or("popup action must be present")?;
    let split_action = section_by_id(&manifest, "actions", SPLIT_ACTION_ID)
        .ok_or("split action must be present")?;
    let popup =
        section_by_id(&manifest, "panes", POPUP_PANE_ID).ok_or("popup pane must be present")?;
    let split =
        section_by_id(&manifest, "panes", SPLIT_PANE_ID).ok_or("split pane must be present")?;
    assert_eq!(command_program(popup_action), Some(PLUGIN_BINARY_PATH));
    assert_eq!(command_program(split_action), Some(PLUGIN_BINARY_PATH));
    assert_eq!(command_program(popup), Some(PLUGIN_BINARY_PATH));
    assert_eq!(command_program(split), Some(PLUGIN_BINARY_PATH));
    assert_eq!(popup["placement"].as_str(), Some(POPUP_PLACEMENT));
    assert_eq!(split["placement"].as_str(), Some(SPLIT_PLACEMENT));
    assert!(split.get("width").is_none());
    assert!(split.get("height").is_none());
    Ok(())
}

#[test]
fn malformed_manifest_is_rejected() {
    let malformed = "id = [unterminated";
    assert!(toml::from_str::<toml::Value>(malformed).is_err());
}
