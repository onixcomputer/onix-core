# llama.cpp 0.4.0 with Qwen3.8-Flash-Next support for Strix Halo.
# This package stays separate from the proven DeepSeek and Lemonade runtimes.
{
  pkgs,
  lib,
}:
let
  # r[onix.aspen1.qwen_flash.runtime]
  upstreamRevision = "427291b5b34cd914a31b3fd3b61a68f6184f4b9f";
  upstreamBuildNumber = "10809";
  base = pkgs.llama-cpp.override {
    rocmSupport = true;
    rpcSupport = false;
    rocmGpuTargets = [ "gfx1151" ];
    vulkanSupport = false;
    cudaSupport = false;
  };
in
base.overrideAttrs (old: {
  pname = "llamacpp-rocm-qwen4exp";
  version = upstreamBuildNumber;
  src = pkgs.fetchFromGitHub {
    owner = "ggml-org";
    repo = "llama.cpp";
    rev = upstreamRevision;
    hash = "sha256-ZKKAvnQYvW/eDiWCwORwjloeQDQ+ySuqO9+gieKFZxk=";
  };
  npmDepsHash = "sha256-2Q7XhaLAArmviOLdQsNbYTfdyDE5pW9lR26cRHEVl9k=";

  cmakeFlags = (old.cmakeFlags or [ ]) ++ [
    (lib.cmakeBool "GGML_HIP_MMQ_MFMA" true)
    (lib.cmakeBool "GGML_HIP_NO_VMM" true)
    (lib.cmakeBool "GGML_HIP_GRAPHS" false)
    (lib.cmakeBool "GGML_NATIVE" false)
  ];

  meta = old.meta // {
    description = "llama.cpp 0.4.0 with Qwen4Exp support for ROCm gfx1151";
  };
})
