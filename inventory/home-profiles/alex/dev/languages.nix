{ pkgs, ... }:
{
  home.packages = with pkgs; [
    # C/C++ development
    clang

    # Go development
    go

    # Rust development
    # rustc
    # cargo

    # Node.js development
    nodejs

    # Python development (python3 already installed, adding pip support)
    python3Packages.pip

    # Java development
    jdk

    # Lua development
    lua
    luarocks

    # PHP development
    php
    php.packages.composer

    # Julia development
    julia
  ];
}
