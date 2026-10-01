#!/bin/bash
set -euo pipefail
site_packages=/opt/vllm/lib/python3.14/site-packages
export LD_LIBRARY_PATH="${site_packages}/_rocm_sdk_core/lib/llvm/lib:${LD_LIBRARY_PATH:-}"
for library_dir in "${site_packages}"/_rocm_sdk_*/lib "${site_packages}/torch/lib"; do
  if [ -d "$library_dir" ]; then
    export LD_LIBRARY_PATH="$library_dir:$LD_LIBRARY_PATH"
  fi
done
export PYTHONPATH="${site_packages}/_rocm_sdk_core/share/amd_smi:${PYTHONPATH:-}"
export CC="${site_packages}/_rocm_sdk_core/lib/llvm/bin/clang"
export FLASH_ATTENTION_TRITON_AMD_ENABLE=TRUE
export VLLM_ROCM_USE_AITER=0
export HIP_VISIBLE_DEVICES=0
exec "$@"
