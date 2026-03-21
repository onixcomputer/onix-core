# Compositor startup applications — source of truth.
#
# Defines the services and apps spawned when the compositor launches.
# Each entry carries the logical name used by the Nix stub plus the
# command tokens passed to niri's `spawn-at-startup`.
#
# Consumed by: startup.nix (exposes as readOnly HM options)
# Validated at `ncl export` time.
#
# Workflow:
#   1. Edit this file
#   2. Run: ncl export inventory/home-profiles/brittonr/base/startup.ncl
#   3. Commit .ncl
let NonEmpty =
  std.contract.from_validator (match {
    value if std.is_string value && std.string.length value > 0 => 'Ok,
    _ => 'Error { message = "must be a non-empty string" },
  }
  )
in

let StartupEntry = {
  name | doc "Logical name (for reference / comments)" | NonEmpty,
  command | doc "Executable path or name" | NonEmpty,
  args | doc "Command arguments" | Array String | default = [],
}
in

{
  # System services spawned at compositor startup.
  # Noctalia replaces waybar, swayosd, swww, and mako — so noctalia-shell
  # is the first thing launched. wl-walls lifecycle is plugin-managed.
  services | Array StartupEntry = [
    { name = "noctalia-shell", command = "noctalia-shell" },
    { name = "clipboard", command = "@wl-paste@", args = ["--watch", "@cliphist@", "store"] },
    { name = "polkit", command = "@polkit-gnome@" },
    { name = "network-applet", command = "@nm-applet@" },
    { name = "bluetooth-applet", command = "@blueman-applet@" },
  ],

  # User applications spawned at startup.
  apps | Array StartupEntry = [
    {
      name = "vesktop",
      command = "vesktop",
      args = [
        "--enable-features=UseOzonePlatform",
        "--ozone-platform=wayland",
        "--enable-wayland-ime",
        "--disable-gpu-sandbox",
      ],
    },
    { name = "element-desktop", command = "element-desktop" },
    { name = "sysmon", command = "@terminal@", args = ["start", "--", "@sysmon@"] },
    { name = "journalctl", command = "@terminal@", args = ["start", "--", "@journalctl@", "-f"] },
  ],
}
