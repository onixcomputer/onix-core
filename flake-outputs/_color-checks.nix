# Check for stale config.colors references in home-profiles.
#
# After the NCL color unification, all modules should use config.theme
# instead of config.colors. This check catches forgotten references.
{ pkgs, ... }:
{
  checks.no-stale-color-refs = pkgs.runCommand "no-stale-color-refs" { } ''
    stale=$(
      ${pkgs.ripgrep}/bin/rg -l \
        'config\.colors\b' \
        ${../../inventory/home-profiles} \
        --glob '*.nix' \
        --glob '!*color-scheme.nix' \
        || true
    )
    if [ -n "$stale" ]; then
      echo "ERROR: Found stale config.colors references (use config.theme instead):"
      echo "$stale"
      exit 1
    fi
    echo "No stale config.colors references found"
    touch $out
  '';
}
