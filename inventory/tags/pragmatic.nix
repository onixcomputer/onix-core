{ pkgs, ... }:
{
  services = {
    # A fuse filesystem that dynamically populates contents of /bin
    # and /usr/bin/ so that it contains all executables from the PATH
    # of the requesting process.
    envfs.enable = true;
  };

  programs = {
    # I got tired of facing NixOS issues
    # Let's be more pragmatic and try to run binaries sometimes
    # at the cost of sweeping bugs under the rug.
    nix-ld = {
      enable = true;
      libraries = with pkgs; [
        stdenv.cc.cc.lib
        zlib # numpy
      ];
    };
  };
}
