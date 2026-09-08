{ lib }:
settings:
let
  safeSegment = value: builtins.isString value && builtins.match "[a-zA-Z0-9_-]+" value != null;
  safePrefix =
    builtins.isString settings.prefix && lib.all safeSegment (lib.splitString "/" settings.prefix);
  bucketPolicy = import ../../lib/rustfs-bucket-policy.nix { inherit lib; };
  base = builtins.fromJSON (
    bucketPolicy.render {
      bucketName = settings.bucket;
      allowDelete = false;
      allowMultipart = false;
    }
  );
  objectPolicy = lib.findFirst (statement: statement.Sid == "BucketObjects") null base.Statement;
  accountRoot = "arn:aws:s3:::${settings.bucket}/${settings.prefix}/users/${settings.account}";
in
assert lib.assertMsg (
  safeSegment settings.bucket && safeSegment settings.account && safePrefix
) "Drift bucket, account, and prefix must not contain wildcards or path traversal";
base
// {
  Statement = [
    (
      objectPolicy
      // {
        Resource = [
          "${accountRoot}/state.json"
          "${accountRoot}/blobs/*"
        ];
      }
    )
  ];
}
