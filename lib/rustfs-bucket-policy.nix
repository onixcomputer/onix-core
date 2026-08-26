{ lib }:
let
  validate =
    settings:
    lib.optional (
      !(builtins.isString settings.bucketName) || settings.bucketName == ""
    ) "RustFS bucket name must be a non-empty string"
    ++ lib.optional (!builtins.isBool settings.allowDelete) "RustFS allowDelete must be a boolean"
    ++ lib.optional (
      !builtins.isBool settings.allowMultipart
    ) "RustFS allowMultipart must be a boolean";

  mkPolicy =
    settings:
    let
      bucketArn = "arn:aws:s3:::${settings.bucketName}";
      bucketActions = [
        "s3:GetBucketLocation"
        "s3:ListBucket"
      ]
      ++ lib.optionals settings.allowMultipart [ "s3:ListBucketMultipartUploads" ];
      objectActions = [
        "s3:GetObject"
        "s3:PutObject"
      ]
      ++ lib.optionals settings.allowDelete [ "s3:DeleteObject" ]
      ++ lib.optionals settings.allowMultipart [
        "s3:AbortMultipartUpload"
        "s3:ListMultipartUploadParts"
      ];
    in
    {
      Version = "2012-10-17";
      Statement = [
        {
          Sid = "BucketMetadata";
          Effect = "Allow";
          Action = bucketActions;
          Resource = [ bucketArn ];
        }
        {
          Sid = "BucketObjects";
          Effect = "Allow";
          Action = objectActions;
          Resource = [ "${bucketArn}/*" ];
        }
      ];
    };
in
{
  inherit validate;

  render =
    settings:
    let
      errors = validate settings;
    in
    assert lib.assertMsg (errors == [ ]) (lib.concatStringsSep "; " errors);
    builtins.toJSON (mkPolicy settings);
}
