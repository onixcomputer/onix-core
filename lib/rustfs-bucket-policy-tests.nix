{ lib }:
let
  policyLib = import ./rustfs-bucket-policy.nix { inherit lib; };
  validSettings = {
    bucketName = "onix-build-cache";
    allowDelete = true;
    allowMultipart = true;
  };
  invalidCases = [
    {
      name = "empty-bucket";
      expected = "bucket name";
      settings = validSettings // {
        bucketName = "";
      };
    }
    {
      name = "non-string-bucket";
      expected = "bucket name";
      settings = validSettings // {
        bucketName = [ ];
      };
    }
    {
      name = "non-boolean-delete";
      expected = "allowDelete";
      settings = validSettings // {
        allowDelete = "yes";
      };
    }
    {
      name = "non-boolean-multipart";
      expected = "allowMultipart";
      settings = validSettings // {
        allowMultipart = "yes";
      };
    }
  ];
  renderedPolicy = builtins.fromJSON (policyLib.render validSettings);
  objectStatement = builtins.elemAt renderedPolicy.Statement 1;
in
{
  positiveErrors = policyLib.validate validSettings;
  negativeFailures = builtins.filter (
    case: !(lib.any (error: lib.hasInfix case.expected error) (policyLib.validate case.settings))
  ) invalidCases;
  objectResourceIsScoped = objectStatement.Resource == [ "arn:aws:s3:::onix-build-cache/*" ];
  objectActionsAreExplicit =
    builtins.elem "s3:GetObject" objectStatement.Action
    && builtins.elem "s3:PutObject" objectStatement.Action
    && builtins.elem "s3:DeleteObject" objectStatement.Action
    && !(builtins.elem "s3:*" objectStatement.Action);
}
