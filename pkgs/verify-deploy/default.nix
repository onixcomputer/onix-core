{
  writeShellScriptBin,
  openssh,
  nix,
  coreutils,
  diffutils,
}:

writeShellScriptBin "verify-deploy" ''
  set -euo pipefail
  PATH="${openssh}/bin:${nix}/bin:${coreutils}/bin:${diffutils}/bin:$PATH"

  usage() {
    echo "Usage: verify-deploy <machine-name>"
    echo ""
    echo "Verify that a deployed machine is running the expected system closure."
    echo "Compares the locally-built store path against the target's /run/current-system."
    echo ""
    echo "Uses iroh-ssh for connectivity (iroh-<machine>), falls back to"
    echo "the deploy target hostname from machines.nix."
    exit 1
  }

  [ -z "''${1:-}" ] && usage
  machine="$1"

  echo "=== verify-deploy: $machine ==="

  # Build the expected system closure locally
  echo "Building expected closure..."
  expected="$(nix build --no-link --print-out-paths \
    ".#nixosConfigurations.$machine.config.system.build.toplevel" 2>/dev/null)" || {
    echo "ERROR: Failed to build .#nixosConfigurations.$machine"
    exit 1
  }
  echo "Expected: $expected"

  # Determine SSH target: try iroh first, then direct hostname
  ssh_target="iroh-$machine"
  if ! ssh -o ConnectTimeout=10 -o BatchMode=yes "$ssh_target" true 2>/dev/null; then
    ssh_target="root@$machine"
    if ! ssh -o ConnectTimeout=10 -o BatchMode=yes "$ssh_target" true 2>/dev/null; then
      echo "ERROR: Cannot reach $machine via iroh-$machine or root@$machine"
      exit 1
    fi
  fi
  echo "Connected via: $ssh_target"

  # Read the target's current system
  actual="$(ssh -o BatchMode=yes "$ssh_target" readlink -f /run/current-system)"
  echo "Actual:   $actual"

  # Compare
  if [ "$expected" = "$actual" ]; then
    echo ""
    echo "✓ VERIFIED: $machine is running the expected system"
    exit 0
  else
    echo ""
    echo "✗ MISMATCH: $machine is running a different system"
    echo "  Expected: $expected"
    echo "  Actual:   $actual"

    # Show what changed between the two closures if both are local
    if [ -e "$actual" ]; then
      echo ""
      echo "Store path diff:"
      diff <(nix path-info -r "$expected" | sort) \
           <(nix path-info -r "$actual" | sort) || true
    fi

    exit 1
  fi
''
