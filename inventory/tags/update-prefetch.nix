# Hourly background build of the next system closure.
# Pin to machines that have local checkout of the flake repo.
_: {
  imports = [ ./common/update-prefetch.nix ];
}
