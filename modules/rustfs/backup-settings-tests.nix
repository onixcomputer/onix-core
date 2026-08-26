{ lib }:
let
  evaluate = import ./backup-settings.nix { inherit lib; };
  retentionDays = 14;
  valid = {
    sourceEndpoint = "http://100.110.43.11:39000";
    buckets = [
      "onix-celld-lab"
      "onix-site-celld"
      "onix-niks3-metadata-backup"
    ];
    targetDir = "/datapool/rustfs-authority-backup";
    schedule = "*-*-* 02:45:00";
    inherit retentionDays;
    adminGenerator = "rustfs-rustfs-cluster";
    restoreProbeBucket = "onix-restore-probe";
  };
  cases = [
    {
      name = "invalid-endpoint";
      expected = "sourceEndpoint";
      settings = valid // {
        sourceEndpoint = "s3.invalid";
      };
    }
    {
      name = "empty-buckets";
      expected = "buckets";
      settings = valid // {
        buckets = [ ];
      };
    }
    {
      name = "duplicate-buckets";
      expected = "unique";
      settings = valid // {
        buckets = [
          "onix-celld-lab"
          "onix-celld-lab"
        ];
      };
    }
    {
      name = "relative-target";
      expected = "targetDir";
      settings = valid // {
        targetDir = "backup/rustfs";
      };
    }
    {
      name = "zero-retention";
      expected = "retentionDays";
      settings = valid // {
        retentionDays = 0;
      };
    }
    {
      name = "probe-overlap";
      expected = "overlap";
      settings = valid // {
        restoreProbeBucket = "onix-celld-lab";
      };
    }
  ];
  errorsFor = settings: (evaluate settings).errors;
  missing = builtins.filter (
    case: !(lib.any (error: lib.hasInfix case.expected error) (errorsFor case.settings))
  ) cases;
in
{
  positiveErrors = errorsFor valid;
  missingNegativeCases = missing;
  negativeErrors = lib.concatMap (case: errorsFor case.settings) cases;
}
