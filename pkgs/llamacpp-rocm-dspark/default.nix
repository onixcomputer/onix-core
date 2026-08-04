# llama.cpp pinned to the known-good DeepSeek-V4-Flash-0731 revision.
# HIP gfx1151 build with the cmake flags verified by the Strix Halo
# 0731 deployment guide (darnoq99/deepseek-v4-flash-0731-strix-halo).
# Kept separate from llamacpp-rocm-rpc so Lemonade hosts stay on their
# release-tag runtime.
{
  pkgs,
  lib,
}:
let
  # r[onix.aspen1.deepseek.runtime]
  upstreamRev = "0b14b87d7c20cb753b94b96854dd7b45306fc696";
  base = pkgs.llama-cpp.override {
    rocmSupport = true;
    rpcSupport = false;
    rocmGpuTargets = [ "gfx1151" ];
    vulkanSupport = false;
    cudaSupport = false;
  };
in
base.overrideAttrs (old: {
  pname = "llamacpp-rocm-dspark";
  version = "0.1.0-${lib.substring 0 7 upstreamRev}";
  src = pkgs.fetchFromGitHub {
    owner = "ggml-org";
    repo = "llama.cpp";
    rev = upstreamRev;
    hash = "sha256-ti8LjvWt6+Q6ybRLaqgbWo/CR5XF+GA7+fVrebPPymg=";
  };
  npmDepsHash = "sha256-B7uEynAG70a3xauBKc20RuFa9cnWaWzVBCh+LPLBnIM=";

  cmakeFlags = (old.cmakeFlags or [ ]) ++ [
    (lib.cmakeBool "GGML_HIP_MMQ_MFMA" true)
    (lib.cmakeBool "GGML_HIP_NO_VMM" true)
    (lib.cmakeBool "GGML_HIP_GRAPHS" false)
    (lib.cmakeBool "GGML_NATIVE" false)
  ];

  meta = old.meta // {
    description = "llama.cpp pinned for DeepSeek-V4-Flash-0731 DSpark serving on gfx1151";
  };
})
