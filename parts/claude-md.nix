{ pkgs, ... }:
{
  packages.claude-md = pkgs.python3.pkgs.callPackage ../pkgs/claude-md { };
}
