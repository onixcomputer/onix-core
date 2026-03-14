{ pkgs, ... }:
{
  packages = {
    dumbpipe = pkgs.callPackage ../pkgs/dumbpipe { };
    sendme = pkgs.callPackage ../pkgs/sendme { };
    verify-deploy = pkgs.callPackage ../pkgs/verify-deploy { };
  };
}
