{
  lib,
  varsRoot ? ../vars/per-machine,
}:
let
  publicKeyPath = machine: varsRoot + "/${machine}/openssh/ssh.id_ed25519.pub/value";

  readPublicKey =
    machine:
    let
      path = publicKeyPath machine;
    in
    if builtins.pathExists path then lib.trim (builtins.readFile path) else null;

  requirePublicKey =
    machine:
    let
      publicKey = readPublicKey machine;
    in
    if publicKey == null then throw "missing SSH host public key for ${machine}" else publicKey;
in
{
  inherit
    publicKeyPath
    readPublicKey
    requirePublicKey
    ;
}
