{ lib }:
settings:
let
  nonEmpty = value: builtins.isString value && value != "";
  absolutePath = value: nonEmpty value && lib.hasPrefix "/" value;
  storageUrlValid =
    nonEmpty settings.storageEndpoint
    && (
      lib.hasPrefix "http://" settings.storageEndpoint
      || lib.hasPrefix "https://" settings.storageEndpoint
    )
    && !(builtins.elem settings.storageEndpoint [
      "http://"
      "https://"
    ]);
  bucketNameValid =
    nonEmpty settings.bucketName
    && builtins.match "[a-z0-9][a-z0-9.-]*[a-z0-9]" settings.bucketName != null;
  assertions = [
    {
      assertion = absolutePath settings.cacheDir;
      message = "kache-rustfs cacheDir must be an absolute path";
    }
    {
      assertion = nonEmpty settings.cacheMaxSize;
      message = "kache-rustfs cacheMaxSize must not be empty";
    }
    {
      assertion = nonEmpty settings.serviceUser;
      message = "kache-rustfs serviceUser must not be empty";
    }
    {
      assertion = storageUrlValid;
      message = "kache-rustfs storageEndpoint must be an HTTP or HTTPS URL";
    }
    {
      assertion = bucketNameValid;
      message = "kache-rustfs bucketName must be a valid non-empty S3 bucket name";
    }
    {
      assertion = nonEmpty settings.region;
      message = "kache-rustfs region must not be empty";
    }
    {
      assertion = nonEmpty settings.prefix;
      message = "kache-rustfs prefix must not be empty";
    }
    {
      assertion = nonEmpty settings.accessKeyId;
      message = "kache-rustfs accessKeyId must not be empty";
    }
    {
      assertion = !settings.provisionStorage || nonEmpty settings.rustfsAdminGenerator;
      message = "kache-rustfs provisioning requires a RustFS administrator generator";
    }
    {
      assertion = builtins.isInt settings.restartDelaySeconds && settings.restartDelaySeconds > 0;
      message = "kache-rustfs restartDelaySeconds must be a positive integer";
    }
  ];
in
{
  inherit assertions;
  errors = builtins.map (assertion: assertion.message) (
    builtins.filter (assertion: !assertion.assertion) assertions
  );
  remoteConfig = {
    type = "s3";
    bucket = settings.bucketName;
    endpoint = settings.storageEndpoint;
    region = settings.region;
    prefix = settings.prefix;
  };
}
