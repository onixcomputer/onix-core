# llama.cpp with ROCm HIP (gfx1151), RPC, and flash attention via rocWMMA.
# Overrides the nixpkgs llama-cpp package with Strix Halo-specific flags.
{
  pkgs,
  lib,
}:
let
  # r[onix.aspen3.ornith.runtime]
  upstreamTag = "b9859";
  base = pkgs.llama-cpp.override {
    rocmSupport = true;
    rpcSupport = true;
    rocmGpuTargets = [ "gfx1151" ];
    vulkanSupport = false;
    cudaSupport = false;
  };
in
base.overrideAttrs (old: {
  pname = "llamacpp-rocm-rpc";
  version = lib.removePrefix "b" upstreamTag;
  src = pkgs.fetchFromGitHub {
    owner = "ggml-org";
    repo = "llama.cpp";
    rev = upstreamTag;
    hash = "sha256-ecPtU/6kdUmJkzs1pVUV5hFLvQFnoLTTPlrm9NuoXzs=";
  };
  npmDepsHash = "sha256-X1DZgmhS/zHTqDT5zq0kywwntthcJ9vRXeqyO3zz6UU=";

  buildInputs = (old.buildInputs or [ ]) ++ [
    pkgs.rdma-core
    pkgs.rocmPackages.rocwmma
  ];

  cmakeFlags = (old.cmakeFlags or [ ]) ++ [
    (lib.cmakeBool "GGML_HIP_ROCWMMA_FATTN" true)
    (lib.cmakeBool "GGML_RPC_RDMA" true)
  ];

  # r[onix.aspen3.ornith.runtime]
  postInstall =
    lib.replaceStrings
      [ "cp bin/rpc-server $out/bin/llama-rpc-server" ]
      [
        ''
          if [ -x bin/rpc-server ]; then
            cp bin/rpc-server $out/bin/llama-rpc-server
          elif [ -x bin/llama-rpc-server ]; then
            cp bin/llama-rpc-server $out/bin/llama-rpc-server
          elif [ -x $out/bin/ggml-rpc-server ]; then
            ln -sf ggml-rpc-server $out/bin/llama-rpc-server
          else
            echo "missing llama.cpp RPC server binary" >&2
            exit 1
          fi
        ''
      ]
      (old.postInstall or "");

  # rocwmma headers must be on the HIP compiler include path.
  # CMAKE_HIP_FLAGS gets space-split by cmake, so inject via env instead.
  preConfigure = (old.preConfigure or "") + ''
    export CPLUS_INCLUDE_PATH="${pkgs.rocmPackages.rocwmma}/include''${CPLUS_INCLUDE_PATH:+:$CPLUS_INCLUDE_PATH}"
    export HIP_CLANG_EXTRA_FLAGS="-isystem ${pkgs.rocmPackages.rocwmma}/include"
  '';

  meta = old.meta // {
    description = "llama.cpp with ROCm HIP (gfx1151), RPC, and flash attention";
  };
})
