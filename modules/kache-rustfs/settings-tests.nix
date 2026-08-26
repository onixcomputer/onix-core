{ lib }:
let
  evaluate = import ./settings.nix { inherit lib; };
  validSettings = {
    cacheDir = "/var/cache/kache-nix/user-brittonr";
    cacheMaxSize = "32GiB";
    serviceUser = "brittonr";
    storageEndpoint = "http://100.110.43.11:39000";
    bucketName = "onix-kache";
    region = "us-east-1";
    prefix = "artifacts";
    accessKeyId = "kache-remote";
    provisionStorage = true;
    rustfsAdminGenerator = "rustfs-rustfs-cluster";
    restartDelaySeconds = 5;
  };
  cases = [
    {
      name = "relative-cache";
      expected = "cacheDir";
      settings = validSettings // {
        cacheDir = "cache";
      };
    }
    {
      name = "empty-size";
      expected = "cacheMaxSize";
      settings = validSettings // {
        cacheMaxSize = "";
      };
    }
    {
      name = "empty-user";
      expected = "serviceUser";
      settings = validSettings // {
        serviceUser = "";
      };
    }
    {
      name = "invalid-endpoint";
      expected = "storageEndpoint";
      settings = validSettings // {
        storageEndpoint = "s3.invalid";
      };
    }
    {
      name = "invalid-bucket";
      expected = "bucketName";
      settings = validSettings // {
        bucketName = "Invalid_Bucket";
      };
    }
    {
      name = "empty-region";
      expected = "region";
      settings = validSettings // {
        region = "";
      };
    }
    {
      name = "empty-prefix";
      expected = "prefix";
      settings = validSettings // {
        prefix = "";
      };
    }
    {
      name = "empty-key";
      expected = "accessKeyId";
      settings = validSettings // {
        accessKeyId = "";
      };
    }
    {
      name = "missing-admin";
      expected = "administrator";
      settings = validSettings // {
        rustfsAdminGenerator = "";
      };
    }
    {
      name = "invalid-restart";
      expected = "restartDelaySeconds";
      settings = validSettings // {
        restartDelaySeconds = 0;
      };
    }
  ];
  errorsFor = settings: (evaluate settings).errors;
in
{
  positiveErrors = errorsFor validSettings;
  missingNegativeCases = builtins.filter (
    case: !(lib.any (error: lib.hasInfix case.expected error) (errorsFor case.settings))
  ) cases;
  negativeErrors = lib.concatMap (case: errorsFor case.settings) cases;
}
