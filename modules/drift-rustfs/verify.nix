{
  pkgs,
  lib,
  settings,
  credentials,
}:
let
  probeTimeoutSeconds = 15;
  httpOk = "200";
  httpDenied = "403";
  httpMissing = "404";
  httpPreconditionFailed = "412";
in
pkgs.writeShellApplication {
  name = "drift-storage-check";
  runtimeInputs = [
    pkgs.curl
    pkgs.coreutils
    pkgs.util-linux
  ];
  text = ''
    # The secret exists only on the deployed host.
    # shellcheck source=/dev/null
    source ${lib.escapeShellArg credentials}
    umask ${settings.serviceUmask}
    temporary=$(mktemp -d)
    trap 'rm -rf "$temporary"' EXIT
    printf 'user = "%s:%s"\n' "$DRIFT_S3_ACCESS_KEY_ID" "$DRIFT_S3_SECRET_ACCESS_KEY" > "$temporary/auth"
    printf '%s\n' 'Drift deployment storage probe' > "$temporary/payload"
    key="${settings.prefix}/users/${settings.account}/blobs/deployment-$(uuidgen)"
    url="${settings.endpoint}/${settings.bucket}/$key"
    request() {
      method="$1"
      shift
      target="$1"
      shift
      curl --config "$temporary/auth" --aws-sigv4 ${lib.escapeShellArg "aws:amz:${settings.region}:s3"} \
        --silent --show-error --max-time ${toString probeTimeoutSeconds} \
        --request "$method" --url "$target" --output "$temporary/response" \
        --write-out '%{http_code}' "$@"
    }
    expect_status() {
      if [ "$actual" != "$1" ]; then
        printf 'Expected HTTP %s, received %s\n' "$1" "$actual" >&2
        return 1
      fi
    }
    actual=$(request GET "$url")
    expect_status ${httpMissing}
    actual=$(request PUT "$url" --header 'If-None-Match: *' --data-binary "@$temporary/payload")
    expect_status ${httpOk}
    actual=$(request GET "$url")
    expect_status ${httpOk}
    cmp "$temporary/payload" "$temporary/response"
    actual=$(request PUT "$url" --header 'If-None-Match: *' --data-binary "@$temporary/payload")
    expect_status ${httpPreconditionFailed}
    actual=$(request PUT "$url" --header 'If-Match: "stale-deployment-etag"' --data-binary "@$temporary/payload")
    expect_status ${httpPreconditionFailed}
    actual=$(request GET "${settings.endpoint}/${settings.bucket}/${settings.prefix}/users/other-account/state.json")
    expect_status ${httpDenied}
    actual=$(request DELETE "$url")
    expect_status ${httpDenied}
    printf '%s\n' 'PASS: absence, create, read, content match, duplicate rejection, stale-write rejection, account denial, delete denial'
  '';
}
