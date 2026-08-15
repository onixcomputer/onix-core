{
  inputs,
  lib,
  pkgs,
  ...
}:
let
  requiredSystem = "aarch64-linux";
  actualSystem = pkgs.stdenv.hostPlatform.system;
  authorizedKeys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILYzh3yIsSTOYXkJMFHBKzkakoDfonm3/RED5rqMqhIO britton@framework"
  ];
  sendmePackage = pkgs.callPackage ../../pkgs/sendme { };
  meshLlmPackage = pkgs.callPackage ../../pkgs/mesh-llm { };
in
{
  imports = [
    inputs.dgx-spark.nixosModules.dgx-spark
    ../../modules/dgx-spark-power
    ./common/shared-users.nix
  ];

  assertions = [
    {
      assertion = actualSystem == requiredSystem;
      message = "The dgx-spark tag requires ${requiredSystem}; got ${actualSystem}.";
    }
  ];

  hardware.dgx-spark.enable = true;
  # Cap GPU clocks at boot for the serving power profile (2200 MHz, ~32 W vs
  # ~47 W at boost, ~66 C vs ~72 C). Decode is memory-bound and unaffected;
  # prefill and compute-bound work is slower. See docs/dgx-spark-power-profile.md.
  services.dgx-spark-power.enable = true;
  services.openssh.enable = true;

  users.users = {
    brittonr.openssh.authorizedKeys.keys = lib.mkForce authorizedKeys;
    root.openssh.authorizedKeys.keys = lib.mkForce authorizedKeys;
  };

  environment.systemPackages = [
    sendmePackage
    meshLlmPackage
  ];
}
