# llama.cpp with ROCm HIP (gfx1151), RPC, and flash attention via rocWMMA.
# Overrides the nixpkgs llama-cpp package with Strix Halo-specific flags.
{
  pkgs,
  lib,
}:
let
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

  buildInputs = (old.buildInputs or [ ]) ++ [
    pkgs.rocmPackages.rocwmma
  ];

  cmakeFlags = (old.cmakeFlags or [ ]) ++ [
    (lib.cmakeBool "GGML_HIP_ROCWMMA_FATTN" true)
  ];

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
