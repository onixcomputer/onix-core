{ lib }:
settings:
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
  bucket = value: nonEmpty value && builtins.match "[a-z0-9][a-z0-9.-]*[a-z0-9]" value != null;
  positiveInteger = value: builtins.isInt value && value > 0;
  assertions = [
    {
      assertion = httpUrl settings.sourceEndpoint;
      message = "rustfs backup sourceEndpoint must be an HTTP or HTTPS URL";
    }
    {
      assertion = settings.buckets != [ ] && lib.all bucket settings.buckets;
      message = "rustfs backup buckets must contain valid S3 bucket names";
    }
    {
      assertion = lib.unique settings.buckets == settings.buckets;
      message = "rustfs backup buckets must be unique";
    }
    {
      assertion = nonEmpty settings.targetDir && lib.hasPrefix "/" settings.targetDir;
      message = "rustfs backup targetDir must be an absolute path";
    }
    {
      assertion = nonEmpty settings.schedule;
      message = "rustfs backup schedule must not be empty";
    }
    {
      assertion = positiveInteger settings.retentionDays;
      message = "rustfs backup retentionDays must be a positive integer";
    }
    {
      assertion = nonEmpty settings.adminGenerator;
      message = "rustfs backup adminGenerator must not be empty";
    }
    {
      assertion = bucket settings.restoreProbeBucket;
      message = "rustfs backup restoreProbeBucket must be a valid S3 bucket name";
    }
    {
      assertion = !(builtins.elem settings.restoreProbeBucket settings.buckets);
      message = "rustfs backup restoreProbeBucket must not overlap a source bucket";
    }
  ];
in
{
  inherit assertions;
  errors = builtins.map (assertion: assertion.message) (
    builtins.filter (assertion: !assertion.assertion) assertions
  );
}
