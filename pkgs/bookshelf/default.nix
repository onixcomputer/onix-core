{
  lib,
  buildNpmPackage,
  fetchFromGitHub,
  makeWrapper,
  nodejs_24,
  libwebp,
  poppler-utils,
  which,
  curl,
}:
let
  version = "0.1.0-unstable-2026-08-25";
  revision = "8888795162ff76285f246957cc34cc9988253a60";
  applicationRoot = "lib/bookshelf";
  syncRoot = "lib/bookshelf-sync";
  documentationFileMode = "0644";
  demoBookCount = 9;
  installCheckPort = 39400;
  installCheckAttempts = 30;
  installCheckDelaySeconds = 1;
in
buildNpmPackage {
  pname = "bookshelf";
  inherit version;

  src = fetchFromGitHub {
    owner = "murerkinn";
    repo = "bookshelf";
    rev = revision;
    hash = "sha256-4ZWAs20GZM4/hI8jsMmvJc6efneyuBNEYbLjk5KNBIQ=";
  };

  npmDepsHash = "sha256-Qk9sBluK+Wfo8/2XSMkwgqugxtQIID2/quwuhbqF9rM=";
  nodejs = nodejs_24;
  nativeBuildInputs = [ makeWrapper ];
  nativeCheckInputs = [ curl ];

  env = {
    NEXT_TELEMETRY_DISABLED = "1";
    TURBO_TELEMETRY_DISABLED = "1";
  };

  postPatch = ''
    printf '%s\n' \
      '{' \
      '  "storage": {' \
      '    "provider": "fs",' \
      '    "directory": "/var/empty"' \
      '  }' \
      '}' \
      > bookshelf.config.json

    substituteInPlace apps/bookshelf/next.config.ts \
      --replace-fail 'import { initOpenNextCloudflareForDev } from "@opennextjs/cloudflare";' "" \
      --replace-fail 'initOpenNextCloudflareForDev();' "" \
      --replace-fail '  headers: securityHeaders,' $'  output: "standalone",\n\n  headers: securityHeaders,'
  '';

  npmBuildScript = "build";
  doCheck = true;

  installPhase = ''
    runHook preInstall

    mkdir -p "$out/${applicationRoot}/apps/bookshelf/.next"
    cp -r apps/bookshelf/.next/standalone/. "$out/${applicationRoot}/"
    cp -r apps/bookshelf/.next/static "$out/${applicationRoot}/apps/bookshelf/.next/static"
    cp -r apps/bookshelf/public "$out/${applicationRoot}/apps/bookshelf/public"
    mkdir -p "$out/${applicationRoot}/node_modules/@bookshelf" "$out/${applicationRoot}/packages"
    cp -r packages/core packages/provider-fs "$out/${applicationRoot}/packages/"
    ln -s ../../packages/core "$out/${applicationRoot}/node_modules/@bookshelf/core"
    ln -s ../../packages/provider-fs "$out/${applicationRoot}/node_modules/@bookshelf/provider-fs"

    mkdir -p "$out/${syncRoot}/node_modules/@bookshelf" "$out/${syncRoot}/packages"
    cp -r packages/core packages/provider-fs packages/sync "$out/${syncRoot}/packages/"
    ln -s ../../packages/core "$out/${syncRoot}/node_modules/@bookshelf/core"
    ln -s ../../packages/provider-fs "$out/${syncRoot}/node_modules/@bookshelf/provider-fs"

    mkdir -p "$out/bin" "$out/share/doc/bookshelf"
    makeWrapper ${nodejs_24}/bin/node "$out/bin/bookshelf-server" \
      --add-flags "$out/${applicationRoot}/apps/bookshelf/server.js"
    makeWrapper ${nodejs_24}/bin/node "$out/bin/bookshelf-sync" \
      --add-flags "$out/${syncRoot}/packages/sync/dist/sync.js" \
      --prefix PATH : ${
        lib.makeBinPath [
          libwebp
          poppler-utils
          which
        ]
      }

    install -m ${documentationFileMode} LICENSE THIRD-PARTY-NOTICES.md "$out/share/doc/bookshelf/"

    runHook postInstall
  '';

  doInstallCheck = true;
  installCheckPhase = ''
    runHook preInstallCheck

    check_root="$TMPDIR/bookshelf-install-check"
    mkdir -p "$check_root"
    ${nodejs_24}/bin/node tools/demo.mjs
    mv books "$check_root/books"
    cat > "$check_root/bookshelf.config.json" <<EOF
    {
      "input": "books",
      "output": "output",
      "storage": {
        "provider": "fs",
        "directory": "library"
      }
    }
    EOF

    output="$(cd "$check_root" && "$out/bin/bookshelf-sync" --dry-run --full)"
    if ! printf '%s\n' "$output" | grep -F '${toString demoBookCount} books built, 0 failed.' >/dev/null; then
      echo "positive: generated demo dry-run did not complete" >&2
      printf '%s\n' "$output" >&2
      exit 1
    fi

    if (cd "$check_root" && "$out/bin/bookshelf-sync" --unknown-option >/dev/null 2>&1); then
      echo "negative: bookshelf-sync accepted an unknown option" >&2
      exit 1
    fi

    mkdir -p "$check_root/library"
    BOOKSHELF_PROVIDER=fs \
      BOOKSHELF_DIRECTORY="$check_root/library" \
      HOSTNAME=127.0.0.1 \
      PORT=${toString installCheckPort} \
      NEXT_TELEMETRY_DISABLED=1 \
      "$out/bin/bookshelf-server" >"$check_root/server.log" 2>&1 &
    server_pid="$!"
    cleanup_server() {
      kill "$server_pid" 2>/dev/null || true
      wait "$server_pid" 2>/dev/null || true
    }
    trap cleanup_server EXIT

    attempt=0
    until curl -fsS "http://127.0.0.1:${toString installCheckPort}/" >"$check_root/index.html"; do
      attempt=$((attempt + 1))
      if [ "$attempt" -ge ${toString installCheckAttempts} ]; then
        cat "$check_root/server.log" >&2
        exit 1
      fi
      sleep ${toString installCheckDelaySeconds}
    done
    grep -F '<title>Bookshelf</title>' "$check_root/index.html" >/dev/null
    cleanup_server
    trap - EXIT

    runHook postInstallCheck
  '';

  meta = {
    description = "Self-hosted browser and OPDS library for owned EPUB and PDF files";
    homepage = "https://github.com/murerkinn/bookshelf";
    license = lib.licenses.mit;
    mainProgram = "bookshelf-server";
    platforms = lib.platforms.linux;
  };
}
