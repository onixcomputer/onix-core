# syntax=docker/dockerfile:1.7
# r[impl onix.diffusion-gemma.runtime]
FROM ubuntu@sha256:008173c23f95b170204355c12626cb5a965d779a7e1283b09e9cffbb1bf33ca3 AS runtime-base
SHELL ["/bin/bash", "-euo", "pipefail", "-c"]
RUN apt-get update && apt-get install -y --no-install-recommends \
      ca-certificates curl git build-essential cmake pkg-config libssl-dev \
      libgomp1 libnuma1 libdrm2 libglib2.0-0t64 libgl1 \
    && rm -rf /var/lib/apt/lists/*
RUN --mount=type=bind,source=downloads,target=/downloads \
    printf '%s  %s\n' \
      c0dd1459d866bb8061bb8fdd7faab44452c2cf567f7bb9b55b7356cc3fbad8e8 /downloads/runtime.part01.tar.gz \
      e528f738a110b83aad1a07a1cc2fea6de65cce7053eb3029853598cded8d6693 /downloads/runtime.part02.tar.gz \
    | sha256sum --check -
RUN --mount=type=bind,source=downloads,target=/downloads \
    mkdir -p /opt/vllm \
    && cat /downloads/runtime.part01.tar.gz /downloads/runtime.part02.tar.gz | tar xz --no-same-owner -C /opt/vllm \
    && chmod a+rx /opt/vllm/bin/* /opt/vllm/lib/python3.14/site-packages/_rocm_sdk_core/lib/llvm/bin/*
COPY --chmod=0755 rocm-env.sh /usr/local/bin/rocm-env
ENV PATH="/opt/vllm/bin:${PATH}"
ENV PIP_NO_CACHE_DIR=1 PYTORCH_ROCM_ARCH=gfx1151 VLLM_TARGET_DEVICE=rocm
ENTRYPOINT ["/usr/local/bin/rocm-env"]
CMD ["python3", "-m", "vllm.entrypoints.openai.api_server", "--help"]

FROM runtime-base AS runtime
ARG VLLM_REV=58eacf242207c9b9b54abff57e684fc1a7d74548
ENV MAX_JOBS=8 CMAKE_BUILD_PARALLEL_LEVEL=8
RUN python3 - <<'PY'
from pathlib import Path
from importlib import metadata

for path in Path("/opt/vllm/bin").iterdir():
    if not path.is_file() or path.is_symlink():
        continue
    with path.open("rb") as stream:
        first = stream.readline(256)
        if not first.startswith(b"#!") or b"python" not in first:
            continue
        rest = stream.read()
    path.write_bytes(b"#!/opt/vllm/bin/python3\n" + rest)
    path.chmod(path.stat().st_mode | 0o111)

pins = sorted(
    f"{dist.metadata['Name']}=={dist.version}"
    for dist in metadata.distributions()
    if dist.metadata.get("Name", "").lower().startswith(("torch", "triton", "rocm"))
)
Path("/opt/rocm-constraints.txt").write_text("\n".join(pins) + "\n")
PY
RUN curl --fail --location --output /tmp/pip-26.2.1-py3-none-any.whl \
      https://files.pythonhosted.org/packages/f3/6e/1736e5b4ae2b778ef2f81c47d797de9f891d4d8acb047a24ca37a60294dd/pip-26.2.1-py3-none-any.whl \
    && printf '%s  %s\n' \
      71138adf1f4ca900cdb7d289c21b7494329f2332b6d85f0e1c42108c0384ed3e /tmp/pip-26.2.1-py3-none-any.whl \
      | sha256sum --check - \
    && PYTHONPATH=/tmp/pip-26.2.1-py3-none-any.whl python3 -m pip install \
      --no-index --no-deps --force-reinstall /tmp/pip-26.2.1-py3-none-any.whl \
    && rm /tmp/pip-26.2.1-py3-none-any.whl
# The inference bundle trims HIP tools and LLVM aliases required for source builds.
RUN python3 -m pip install --no-deps --force-reinstall \
      --report /opt/rocm-sdk-install.json \
      --index-url https://rocm.nightlies.amd.com/whl-multi-arch \
      rocm-sdk-core==7.15.0a20260724 \
      rocm-sdk-devel==7.15.0a20260724 \
    && python3 -m rocm_sdk init
WORKDIR /opt/vllm-src
RUN git init . \
    && git remote add origin https://github.com/vllm-project/vllm.git \
    && git fetch --depth=1 origin "${VLLM_REV}" \
    && git checkout --detach FETCH_HEAD \
    && test "$(git rev-parse HEAD)" = "${VLLM_REV}"
# Preserve the qualified ROCm stack; single-GPU safetensors serving does not
# use the distributed KV-transfer engines in requirements/rocm.txt.
RUN python3 use_existing_torch.py --prefix \
    && python3 -m pip uninstall -y vllm \
    && /usr/local/bin/rocm-env python3 -m pip install \
      --constraint /opt/rocm-constraints.txt \
      --requirement requirements/common.txt \
      "packaging>=26.2" "setuptools>=77.0.3,<80" "setuptools-scm>=8" \
      "setuptools-rust>=1.9" wheel "jinja2>=3.1.6"
RUN ln -s "$(python3 -m rocm_sdk path --root)" /opt/rocm
ENV ROCM_HOME=/opt/rocm ROCM_PATH=/opt/rocm HIP_PATH=/opt/rocm
ENV HIPCXX=/opt/rocm/lib/llvm/bin/amdclang++
ENV PATH="/opt/rocm/bin:/opt/rocm/lib/llvm/bin:${PATH}"
RUN /usr/local/bin/rocm-env bash -c \
      'export ROCM_HOME="$(python3 -m rocm_sdk path --root)"; \
       export ROCM_PATH="$ROCM_HOME"; \
       export CMAKE_PREFIX_PATH="$ROCM_HOME"; \
       python3 setup.py bdist_wheel' \
    && python3 -m pip install --no-deps --force-reinstall dist/*.whl \
    && sha256sum dist/*.whl > /opt/vllm-wheel.sha256 \
    && cp -a examples/features/diffusion_reads /opt/diffusion-reads \
    && rm -rf build dist .deps .git
# pip cannot remove the slim bundle's unrecorded, flattened library aliases.
# They must not coexist with the restored SDK: LLVM would be loaded twice.
RUN /usr/local/bin/rocm-env python3 - <<'PY'
import importlib.metadata as metadata
import os
from pathlib import Path
import sys

sdk = metadata.distribution("rocm-sdk-core")
recorded = {Path(sdk.locate_file(path)) for path in sdk.files}
root = Path(sdk.locate_file("_rocm_sdk_core"))
assert (root / "__init__.py") in recorded
for path in root.rglob("*"):
    if path.is_file() and "__pycache__" not in path.parts and path not in recorded:
        path.unlink()
# Check installed-wheel import order without requiring GPU access during build.
os.chdir("/")
os.execv(sys.executable, [
    sys.executable, "-c", "import vllm; print(vllm.__version__)"
])
PY
LABEL org.opencontainers.image.source="https://github.com/vllm-project/vllm" \
      org.opencontainers.image.revision="${VLLM_REV}" \
      org.opencontainers.image.version="${VLLM_REV}" \
      io.onix.gpu-architecture="gfx1151"
WORKDIR /
CMD ["python3", "-m", "vllm.entrypoints.cli.main", "--help"]
