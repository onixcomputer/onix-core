{ lib }:
let
  evaluate = import ./settings.nix { inherit lib; };
  validServer = {
    bindAddress = "100.100.103.95";
    port = 39400;
    storageEndpoint = "http://100.100.103.95:39000";
    bucketName = "onix-niks3";
    region = "us-east-1";
    accessKeyId = "niks3-cache";
    provisionStorage = true;
    rustfsAdminGenerator = "rustfs-rustfs-cluster";
    openFirewall = true;
    firewallInterface = "tailscale0";
    gcOlderThan = "720h";
    gcFailedUploadsOlderThan = "6h";
    gcSchedule = "daily";
    maxNarSize = "8G";
  };
  negativeIdleTimeoutSeconds = -1;
  validUploader = {
    serverUrl = "http://100.100.103.95:39400";
    batchSize = 50;
    idleExitTimeoutSeconds = 0;
    maxConcurrentUploads = 8;
    verifyS3Integrity = true;
  };
  serverCases = [
    {
      name = "empty-bind";
      expected = "bindAddress";
      settings = validServer // {
        bindAddress = "";
      };
    }
    {
      name = "invalid-port";
      expected = "port";
      settings = validServer // {
        port = 0;
      };
    }
    {
      name = "invalid-endpoint";
      expected = "storageEndpoint";
      settings = validServer // {
        storageEndpoint = "s3.invalid";
      };
    }
    {
      name = "invalid-bucket";
      expected = "bucketName";
      settings = validServer // {
        bucketName = "Invalid_Bucket";
      };
    }
    {
      name = "empty-region";
      expected = "region";
      settings = validServer // {
        region = "";
      };
    }
    {
      name = "empty-key";
      expected = "accessKeyId";
      settings = validServer // {
        accessKeyId = "";
      };
    }
    {
      name = "missing-admin";
      expected = "administrator";
      settings = validServer // {
        rustfsAdminGenerator = "";
      };
    }
    {
      name = "missing-interface";
      expected = "firewallInterface";
      settings = validServer // {
        firewallInterface = null;
      };
    }
    {
      name = "invalid-gc-age";
      expected = "gcOlderThan";
      settings = validServer // {
        gcOlderThan = "old";
      };
    }
    {
      name = "invalid-failed-age";
      expected = "gcFailedUploadsOlderThan";
      settings = validServer // {
        gcFailedUploadsOlderThan = "old";
      };
    }
    {
      name = "empty-schedule";
      expected = "gcSchedule";
      settings = validServer // {
        gcSchedule = "";
      };
    }
    {
      name = "invalid-size";
      expected = "maxNarSize";
      settings = validServer // {
        maxNarSize = "large";
      };
    }
  ];
  uploaderCases = [
    {
      name = "invalid-url";
      expected = "serverUrl";
      settings = validUploader // {
        serverUrl = "niks3.invalid";
      };
    }
    {
      name = "invalid-batch";
      expected = "batchSize";
      settings = validUploader // {
        batchSize = 0;
      };
    }
    {
      name = "negative-idle";
      expected = "idleExitTimeoutSeconds";
      settings = validUploader // {
        idleExitTimeoutSeconds = negativeIdleTimeoutSeconds;
      };
    }
    {
      name = "invalid-concurrency";
      expected = "maxConcurrentUploads";
      settings = validUploader // {
        maxConcurrentUploads = 0;
      };
    }
    {
      name = "invalid-verify";
      expected = "verifyS3Integrity";
      settings = validUploader // {
        verifyS3Integrity = "yes";
      };
    }
  ];
  errorsFor = role: settings: (evaluate role settings).errors;
  missing =
    role: cases:
    builtins.filter (
      case: !(lib.any (error: lib.hasInfix case.expected error) (errorsFor role case.settings))
    ) cases;
in
{
  positiveErrors = errorsFor "server" validServer ++ errorsFor "uploader" validUploader;
  missingNegativeCases = missing "server" serverCases ++ missing "uploader" uploaderCases;
  negativeErrors =
    lib.concatMap (case: errorsFor "server" case.settings) serverCases
    ++ lib.concatMap (case: errorsFor "uploader" case.settings) uploaderCases;
}
