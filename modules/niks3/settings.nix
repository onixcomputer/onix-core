{ lib }:
role: settings:
let
  nonEmpty = value: builtins.isString value && value != "";
  httpUrl =
    value:
    nonEmpty value
    && (lib.hasPrefix "http://" value || lib.hasPrefix "https://" value)
    && !(builtins.elem value [
      "http://"
      "https://"
    ]);
  positiveInteger = value: builtins.isInt value && value > 0;
  nonNegativeInteger = value: builtins.isInt value && value >= 0;
  duration = value: nonEmpty value && builtins.match "[1-9][0-9]*[smh]" value != null;
  size = value: value == null || (nonEmpty value && builtins.match "[1-9][0-9]*[KMGT]" value != null);
  bucket = value: nonEmpty value && builtins.match "[a-z0-9][a-z0-9.-]*[a-z0-9]" value != null;
  serverAssertions = [
    {
      assertion = nonEmpty settings.bindAddress;
      message = "niks3 bindAddress must not be empty";
    }
    {
      assertion = positiveInteger settings.port;
      message = "niks3 port must be a positive integer";
    }
    {
      assertion = httpUrl settings.storageEndpoint;
      message = "niks3 storageEndpoint must be an HTTP or HTTPS URL";
    }
    {
      assertion = bucket settings.bucketName;
      message = "niks3 bucketName must be a valid non-empty S3 bucket name";
    }
    {
      assertion = nonEmpty settings.region;
      message = "niks3 region must not be empty";
    }
    {
      assertion = nonEmpty settings.accessKeyId;
      message = "niks3 accessKeyId must not be empty";
    }
    {
      assertion = !settings.provisionStorage || nonEmpty settings.rustfsAdminGenerator;
      message = "niks3 provisioning requires a RustFS administrator generator";
    }
    {
      assertion = !settings.openFirewall || settings.firewallInterface != null;
      message = "niks3 openFirewall requires a private firewallInterface";
    }
    {
      assertion = duration settings.gcOlderThan;
      message = "niks3 gcOlderThan must be a positive duration";
    }
    {
      assertion = duration settings.gcFailedUploadsOlderThan;
      message = "niks3 gcFailedUploadsOlderThan must be a positive duration";
    }
    {
      assertion = nonEmpty settings.gcSchedule;
      message = "niks3 gcSchedule must not be empty";
    }
    {
      assertion = size settings.maxNarSize;
      message = "niks3 maxNarSize must be null or a positive size";
    }
  ];
  uploaderAssertions = [
    {
      assertion = httpUrl settings.serverUrl;
      message = "niks3 uploader serverUrl must be an HTTP or HTTPS URL";
    }
    {
      assertion = positiveInteger settings.batchSize;
      message = "niks3 uploader batchSize must be a positive integer";
    }
    {
      assertion = nonNegativeInteger settings.idleExitTimeoutSeconds;
      message = "niks3 uploader idleExitTimeoutSeconds must be a non-negative integer";
    }
    {
      assertion = positiveInteger settings.maxConcurrentUploads;
      message = "niks3 uploader maxConcurrentUploads must be a positive integer";
    }
    {
      assertion = builtins.isBool settings.verifyS3Integrity;
      message = "niks3 uploader verifyS3Integrity must be a boolean";
    }
  ];
  assertions = if role == "server" then serverAssertions else uploaderAssertions;
in
{
  inherit assertions;
  errors = builtins.map (assertion: assertion.message) (
    builtins.filter (assertion: !assertion.assertion) assertions
  );
}
