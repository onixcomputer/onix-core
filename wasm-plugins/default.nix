# Build wasm plugins for builtins.wasm.
#
# Produces .wasm files (wasm32-unknown-unknown) that work with the
# nix fork's builtins.wasm. Output is platform-independent — the
# same .wasm binaries run on any host architecture.
{
  rustPlatform,
  lld,
  binaryen,
}:
rustPlatform.buildRustPackage {
  pname = "nix-wasm-plugins";
  version = "0.1.0";

  src = ./.;
  cargoLock.lockFile = ./Cargo.lock;

  CARGO_BUILD_TARGET = "wasm32-unknown-unknown";

  nativeBuildInputs = [
    lld
    binaryen
  ];

  buildPhase = ''
    cargo build --release --target wasm32-unknown-unknown
  '';

  checkPhase = ""; # no host tests for wasm targets
  doCheck = false;

  installPhase = ''
    mkdir -p $out
    for f in target/wasm32-unknown-unknown/release/*.wasm; do
      [ -f "$f" ] || continue
      name=$(basename "$f")
      # Skip deps artifacts (only top-level crate outputs)
      case "$name" in
        yaml_plugin.wasm|ini_plugin.wasm)
          wasm-opt -O3 --enable-bulk-memory -o "$out/$name" "$f"
          ;;
        nickel_plugin.wasm)
          # Nickel's malachite (big numbers) uses trunc_sat instructions
          wasm-opt -O3 --enable-bulk-memory --enable-nontrapping-float-to-int -o "$out/$name" "$f"
          ;;
      esac
    done
  '';
}
