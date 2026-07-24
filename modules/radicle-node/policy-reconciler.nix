{ pkgs }:
pkgs.runCommand "radicle-policy-reconciler"
  {
    nativeBuildInputs = [
      pkgs.gcc
      pkgs.rustc
    ];
  }
  ''
    mkdir -p "$out/bin"
    rustc --edition 2024 -D warnings --test ${./policy-reconciler.rs} -o policy-reconciler-tests
    ./policy-reconciler-tests
    rustc --edition 2024 -D warnings -C strip=symbols ${./policy-reconciler.rs} \
      -o "$out/bin/radicle-policy-reconciler"
  ''
