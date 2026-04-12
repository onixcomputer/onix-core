# Lemonade server — OpenAI-compatible local LLM inference server.
# Builds only the headless server (lemond), CLI (lemonade), and legacy
# shim (lemonade-server). No Electron app, tray, or web UI.
#
# At runtime, lemonade manages llama.cpp backends. On NixOS, set
# LEMONADE_LLAMACPP_ROCM_BIN (or vulkan/cpu) env vars to point at
# a nixpkgs-built llama-server binary instead of letting it download
# dynamically-linked upstream binaries that won't run on NixOS.
{
  pkgs,
  lib,
}:
let
  # cpp-httplib: header-only HTTP library.
  # nixpkgs version doesn't export a pkg-config file that lemonade's
  # cmake can find, so we provide the source via FetchContent override.
  httplib-src = pkgs.fetchFromGitHub {
    owner = "yhirose";
    repo = "cpp-httplib";
    rev = "v0.26.0";
    hash = "sha256-+VPebnFMGNyChM20q4Z+kVOyI/qDLQjRsaGS0vo8kDM=";
  };
in
pkgs.stdenv.mkDerivation rec {
  pname = "lemonade-server";
  version = "10.2.0";

  src = pkgs.fetchFromGitHub {
    owner = "lemonade-sdk";
    repo = "lemonade";
    rev = "v${version}";
    hash = "sha256-r6b98zW+guE27HZe26MiQhlHIltfZyNPRN7HIdpKrYI=";
  };

  nativeBuildInputs = with pkgs; [
    cmake
    ninja
    pkg-config
  ];

  buildInputs = with pkgs; [
    nlohmann_json
    cli11
    curl
    openssl
    zlib
    zstd
    libwebsockets
    systemdLibs
    libdrm
    libcap
  ];

  cmakeFlags = [
    "-DBUILD_WEB_APP=OFF"
    "-DCMAKE_INSTALL_PREFIX=${placeholder "out"}"
    # Block network access — all deps must be system or pre-fetched
    "-DFETCHCONTENT_FULLY_DISCONNECTED=ON"
    # cpp-httplib: pkg-config name mismatch between nixpkgs and upstream.
    # Provide pre-fetched source instead.
    "-DFETCHCONTENT_SOURCE_DIR_HTTPLIB=${httplib-src}"
  ];

  # httplib in nixpkgs installs as cpp-httplib pkgconfig, but lemonade
  # looks for it via find_path for httplib.h. Help CMake find it.
  env.CPLUS_INCLUDE_PATH = lib.makeSearchPathOutput "dev" "include" [
    pkgs.httplib
    pkgs.cli11
  ];

  # Build only the server targets (no tray, electron, or web app).
  # The daemon binary is "lemonade-router" in the cmake build system.
  buildFlags = [
    "lemonade-router"
    "lemonade"
    "lemonade-server"
    "copy_resources"
  ];

  installPhase = ''
    runHook preInstall

    mkdir -p $out/bin $out/share/lemonade-server

    # Server daemon, CLI, and legacy shim.
    # Upstream renamed the daemon binary across releases (`lemonade-router`
    # vs `lemond`), so accept either and install both names for compat.
    # cmake hook may run installPhase from the build dir or source root.
    # Use find to locate the binaries reliably.
    local router=$(find /build \( -name lemonade-router -o -name lemond \) -type f -executable | head -1)
    local cli=$(find /build -name lemonade -type f -executable -not -path '*/cli11/*' | head -1)
    local shim=$(find /build -name lemonade-server -type f -executable | head -1)
    local res=$(find /build -name resources -type d -path '*/build/resources' | head -1)

    install -m755 "$router" $out/bin/lemond
    ln -s lemond $out/bin/lemonade-router
    install -m755 "$cli" $out/bin/
    install -m755 "$shim" $out/bin/

    # Resources (model registry, backend versions, defaults, static UI)
    cp -r "$res" $out/share/lemonade-server/

    runHook postInstall
  '';

  # lemond resolves resources via get_executable_dir()/resources.
  # Symlink from bin/ to the share/ resources directory.
  postInstall = ''
    ln -s $out/share/lemonade-server/resources $out/bin/resources
  '';

  meta = {
    description = "Lemonade — OpenAI-compatible local LLM, image, and speech server";
    homepage = "https://github.com/lemonade-sdk/lemonade";
    license = lib.licenses.asl20;
    platforms = lib.platforms.linux;
    mainProgram = "lemond";
  };
}
