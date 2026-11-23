# Host-side operator helpers for the live-pilot guests. They reach the guest
# only through QEMU's loopback forward (127.0.0.1:2222) as root with the
# operator's private key, which never leaves the host.
{ pkgs }:
let
  ssh = pkgs.writeShellApplication {
    name = "kiln-pilot-ssh";
    runtimeInputs = [
      pkgs.openssh
      pkgs.coreutils
    ];
    text = ''
      # Usage: kiln-pilot-ssh [--] COMMAND...
      #   KILN_PILOT_SSH_KEY   private key (default ~/.local/state/kiln-pilot-ssh/pilot-ssh)
      #   NIX_DISK_IMAGE       the guest's disk image; its host key is pinned in
      #                        NIX_DISK_IMAGE.known_hosts on first use
      if [ "''${1:-}" = "--" ]; then shift; fi
      [ "$#" -gt 0 ] || { echo "usage: kiln-pilot-ssh [--] COMMAND..." >&2; exit 2; }
      key="''${KILN_PILOT_SSH_KEY:-$HOME/.local/state/kiln-pilot-ssh/pilot-ssh}"
      disk="''${NIX_DISK_IMAGE:?set NIX_DISK_IMAGE to the guest disk image}"
      test -f "$key" || { echo "kiln-pilot-ssh: no private key at $key" >&2; exit 2; }
      known="$disk.known_hosts"
      # accept-new records the guest key once per disk image and refuses a
      # changed key afterwards; a new disk image gets its own file.
      exec ssh -F none -p 2222 -i "$key" -o IdentitiesOnly=yes -o BatchMode=yes \
        -o StrictHostKeyChecking=accept-new -o UserKnownHostsFile="$known" \
        -o GlobalKnownHostsFile=/dev/null -o HostKeyAlias=kiln-pilot-guest \
        -o PreferredAuthentications=publickey -o ForwardAgent=no -o ClearAllForwardings=yes \
        -o ConnectTimeout=10 root@127.0.0.1 -- "$@"
    '';
  };
  stage = pkgs.writeShellApplication {
    name = "kiln-pilot-stage";
    runtimeInputs = [ ssh ];
    text = ''
      # Usage: kiln-pilot-stage UNIT   (e.g. poll, host-owner-admit, or a full unit name)
      [ "$#" -eq 1 ] || { echo "usage: kiln-pilot-stage UNIT" >&2; exit 2; }
      case "$1" in
        *[!A-Za-z0-9@._-]*) echo "kiln-pilot-stage: invalid unit name" >&2; exit 2 ;;
        *.service) unit="$1" ;;
        kiln-*) unit="$1.service" ;;
        *) unit="kiln-implementation-$1.service" ;;
      esac
      kiln-pilot-ssh -- sh -s "$unit" <<'REMOTE'
      unit="$1"
      systemctl start "$unit"
      status=$?
      echo "== $unit: start exit $status"
      systemctl show "$unit" -p Result -p ActiveState -p ExecMainStatus -p ExecMainCode
      for log in $(systemctl show "$unit" -p StandardOutput -p StandardError --value | sed -n 's/^\(append\|file\)://p'); do
        echo "== $log (tail)"
        tail -n 20 "$log" 2>/dev/null || true
      done
      echo "== journal (tail)"
      journalctl -u "$unit" -n 20 --no-pager
      exit $status
      REMOTE
    '';
  };
  collect = pkgs.writeShellApplication {
    name = "kiln-pilot-collect";
    runtimeInputs = [
      ssh
      pkgs.b3sum
      pkgs.coreutils
    ];
    text = ''
      # Usage: kiln-pilot-collect DIR
      [ "$#" -eq 1 ] || { echo "usage: kiln-pilot-collect DIR" >&2; exit 2; }
      mkdir -p "$1"
      stamp="$(date -u +%Y%m%dT%H%M%SZ)"
      out="$1/kiln-pilot-evidence-$stamp"
      # Every receipt path the runbook lists; /etc manifests are dereferenced.
      kiln-pilot-ssh -- sh -s > "$out.files.b3" <<'REMOTE'
      cd /
      set -- var/log/kiln-implementation-coordinator var/log/kiln-implementation-executor \
        var/log/kiln-implementation-verifier var/log/kiln-implementation-publisher \
        var/lib/kiln-implementation/controller var/lib/kiln-implementation/lattice \
        var/lib/kiln-implementation/candidate-export var/lib/kiln-implementation/verifier/reports \
        var/lib/kiln-implementation/canonical-ci var/lib/kiln-implementation/kiln/work.sqlite \
        etc/kiln-implementation/deployment.json etc/kiln-implementation/pilot-manifest.json
      present=""
      for path in "$@"; do [ -e "$path" ] && present="$present $path"; done
      # shellcheck disable=SC2086
      find -L $present -type f -print0 | sort -z | xargs -0 b3sum
      REMOTE
      kiln-pilot-ssh -- sh -s > "$out.tar.gz" <<'REMOTE'
      cd /
      present=""
      for path in var/log/kiln-implementation-coordinator var/log/kiln-implementation-executor \
        var/log/kiln-implementation-verifier var/log/kiln-implementation-publisher \
        var/lib/kiln-implementation/controller var/lib/kiln-implementation/lattice \
        var/lib/kiln-implementation/candidate-export var/lib/kiln-implementation/verifier/reports \
        var/lib/kiln-implementation/canonical-ci var/lib/kiln-implementation/kiln/work.sqlite \
        etc/kiln-implementation/deployment.json etc/kiln-implementation/pilot-manifest.json; do
        [ -e "$path" ] && present="$present $path"
      done
      # shellcheck disable=SC2086
      tar --dereference -czf - $present
      REMOTE
      b3sum "$out.tar.gz" > "$out.tar.gz.b3"
      echo "$out.tar.gz"
      echo "$out.files.b3"
      echo "$out.tar.gz.b3"
    '';
  };
in
{
  kiln-pilot-ssh = ssh;
  kiln-pilot-stage = stage;
  kiln-pilot-collect = collect;
}
