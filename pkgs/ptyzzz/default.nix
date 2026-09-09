{
  lib,
  rustPlatform,
  fetchFromGitHub,
  fetchurl,
}:

let
  # wezterm-term and wezterm-surface are pinned to this wezterm monorepo rev
  # in ptyZZZ's Cargo.lock.
  weztermRev = "577474d89ee61aef4a48145cdec82a638d874751";

  # wezterm-term include_str!s this compiled terminfo entry from
  # <repo-root>/termwiz/data/wezterm — outside its own crate directory, so
  # cargo's vendored copy lacks it. Restore it into the vendor tree in
  # preBuild below.
  weztermTerminfo = fetchurl {
    url = "https://raw.githubusercontent.com/wezterm/wezterm/${weztermRev}/termwiz/data/wezterm";
    hash = "sha256-ml4XxNLolQMmMyjA/KwosyxNaq922l2OXt/88vfpI4c=";
  };
in
# ptyZZZ: a terminal as a unix pipe — keystrokes in as JSONL on stdin,
# server-side-emulated screen frames out as JSONL HTML on stdout.
rustPlatform.buildRustPackage rec {
  pname = "ptyzzz";
  version = "0.1.0";

  src = fetchFromGitHub {
    owner = "cablehead";
    repo = "ptyZZZ";
    rev = "v${version}";
    hash = "sha256-5bMRZ7eOIS1qFQzx8iNn5h0NyipbQBqISbkyowIvNlY=";
  };

  cargoHash = "sha256-SR6v7Zu+FeZvzEt8EzJsUbZ/hs8R+zH3/qZrTCt1sgM=";

  # The vendored wezterm-term include_bytes!es the terminfo entry via a
  # monorepo-relative path that escapes its crate directory. Place the file
  # exactly where the include resolves, anchored on the vendored crate dir.
  preBuild = ''
    crateDir=$(find /build -maxdepth 4 -type d -name 'wezterm-term-*' | head -1)
    test -n "$crateDir"
    mkdir -p "$crateDir/../termwiz/data"
    cp ${weztermTerminfo} "$crateDir/../termwiz/data/wezterm"
  '';

  # Pulls wezterm-term/wezterm-surface as pinned git dependencies; the vendor
  # fetch clones them over public HTTPS. No network tests in the sandbox.
  doCheck = false;

  meta = {
    description = "A terminal as a unix pipe: keystrokes in as JSONL, screen out as HTML";
    homepage = "https://github.com/cablehead/ptyZZZ";
    license = lib.licenses.mit;
    mainProgram = "ptyZZZ";
    platforms = lib.platforms.unix;
  };
}
