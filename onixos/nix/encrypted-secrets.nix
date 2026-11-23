# Fails evaluation when a sops secret on this machine is not a sops-encrypted
# file that the machine's age key can open.
#
# OnixOS maps each secret artifact file to `sops.secrets."<artifact>/<file>"`
# after checking only that the file exists, and sops-nix validates a
# binary-format file only by parsing it as JSON. A plaintext secret or a
# ciphertext for other recipients would otherwise pass evaluation and fail
# at activation, after the file had been copied to the target's store.
# Only the sops envelope is read; nothing is decrypted.
{ machineName, ageRecipient }:
{ config, lib, ... }:
let
  isCiphertext = value: builtins.isString value && lib.hasPrefix "ENC[AES256_GCM," value;

  # sops writes binary- and JSON-format files as one JSON object.
  jsonFormats = [
    "binary"
    "json"
  ];

  problem =
    name: secret:
    let
      file = toString secret.sopsFile;
      content = builtins.readFile secret.sopsFile;
      envelope = if lib.hasPrefix "{" content then builtins.fromJSON content else null;
      recipients = map (stanza: stanza.recipient or null) (envelope.sops.age or [ ]);
    in
    if !(builtins.elem secret.format jsonFormats) then
      "${name}: format ${secret.format} cannot be checked; use binary or json"
    else if envelope == null || !(envelope ? sops) then
      "${name}: ${file} is not a sops-encrypted file"
    else if !(isCiphertext (envelope.sops.mac or null)) then
      "${name}: ${file} has no encrypted sops MAC"
    else if secret.format == "binary" && !(isCiphertext (envelope.data or null)) then
      "${name}: ${file} holds unencrypted data"
    else if !(builtins.elem ageRecipient recipients) then
      "${name}: ${file} is not encrypted to ${machineName}'s age key"
    else
      null;

  problems = lib.filter (message: message != null) (lib.mapAttrsToList problem config.sops.secrets);
in
{
  assertions = [
    {
      assertion = problems == [ ];
      message =
        "sops secrets on ${machineName} must be encrypted to its age key ${ageRecipient}:\n  "
        + lib.concatStringsSep "\n  " problems;
    }
  ];
}
