# Wan2GP — ProbeAI (A40 / RTX 5090)
# Base: CUDA 12.8 / cuDNN runtime with Python + PyTorch preinstalled (conda @ /opt/conda)
FROM pytorch/pytorch:2.8.0-cuda12.8-cudnn9-runtime

ARG CUDA_ARCHITECTURES="8.0;8.6;8.9;9.0;12.0"

# ---- Environment ----
ENV DEBIAN_FRONTEND=noninteractive \
    PYTHONUNBUFFERED=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1 \
    PIP_NO_CACHE_DIR=1 \
    PIP_NO_BUILD_ISOLATION=1 \
    WAN2GP_DIR=/opt/Wan2GP \
    WAN2GP_PORT=7862 \
    JUPYTER_PORT=8888 \
    WAN2GP_LOG=/workspace/wan2gp.log \
    HF_HOME=/workspace/hf-home \
    HUGGINGFACE_HUB_CACHE=/workspace/hf-cache \
    XDG_CACHE_HOME=/workspace/.cache \
    HF_HUB_ENABLE_HF_TRANSFER=1 \
    MKL_THREADING_LAYER=GNU \
    # ---- Gradio behind proxy hardening (baked in; no need to add in template) ----
    GRADIO_SERVER_NAME=0.0.0.0 \
    GRADIO_SERVER_PORT=7862 \
    GRADIO_ROOT_PATH=/ \
    GRADIO_ALLOW_FLAGGING=never \
    GRADIO_SHARE=False \
    GRADIO_USE_CDN=False

# Use the base image’s conda Python (Torch already present here)
ENV PATH="/opt/conda/bin:${PATH}"

# ---- System deps (toolchain + minimal X/GL for OpenCV/insightface) ----
RUN apt-get update -y && apt-get install -y --no-install-recommends \
    git git-lfs curl ca-certificates ffmpeg aria2 tini jq \
    build-essential python3-dev pkg-config \
    libgl1 libglib2.0-0 libsm6 libxrender1 libxext6 \
 && git lfs install \
 && rm -rf /var/lib/apt/lists/*

# ---- Clone Wan2GP (pin a commit via build arg; default to main) ----
ARG WAN2GP_REPO="https://github.com/deepbeepmeep/Wan2GP.git"
RUN git clone ${WAN2GP_REPO} ${WAN2GP_DIR}

# Patch the deprecated autocast once at build-time (prevents runtime warnings)
RUN sed -i "s/torch.cuda.amp.autocast(/torch.amp.autocast('cuda', /g" \
    ${WAN2GP_DIR}/models/wan/animate/motion_encoder.py || true

# ---- Python deps (compile-safe order) ----
# NOTE: Torch already exists in /opt/conda from the base image; do NOT reinstall it.
RUN python -V && \
    python -m pip install --upgrade pip wheel && \
    python -m pip install --no-deps "numpy<2.1" "cython<3.2" "setuptools<75" && \
    python -m pip install -r ${WAN2GP_DIR}/requirements.txt && \
    python - <<'PY'
import torch, transformers, diffusers, numpy, huggingface_hub, gradio
print("Sanity:", torch.__version__, transformers.__version__, diffusers.__version__, numpy.__version__, huggingface_hub.__version__, gradio.__version__)
PY

# Install SageAttention from git (patch GPU detection)
ENV TORCH_CUDA_ARCH_LIST="${CUDA_ARCHITECTURES}"
ENV FORCE_CUDA="1"
ENV MAX_JOBS="1"

COPY <<EOF /tmp/patch_setup.py
import os
with open('setup.py', 'r') as f:
    content = f.read()

# Get architectures from environment variable
arch_list = os.environ.get('TORCH_CUDA_ARCH_LIST')
arch_set = '{' + ', '.join([f'"{arch}"' for arch in arch_list.split(';')]) + '}'

# Replace the GPU detection section
old_section = '''compute_capabilities = set()
device_count = torch.cuda.device_count()
for i in range(device_count):
    major, minor = torch.cuda.get_device_capability(i)
    if major < 8:
        warnings.warn(f"skipping GPU {i} with compute capability {major}.{minor}")
        continue
    compute_capabilities.add(f"{major}.{minor}")'''

new_section = 'compute_capabilities = ' + arch_set + '''
print(f"Manually set compute capabilities: {compute_capabilities}")'''

content = content.replace(old_section, new_section)

with open('setup.py', 'w') as f:
    f.write(content)
EOF

RUN git clone https://github.com/thu-ml/SageAttention.git /tmp/sageattention && \
    cd /tmp/sageattention && \
    python /tmp/patch_setup.py && \
    python -m pip install --no-build-isolation .

# ---- Runtime entry assets ----
COPY start-wan2gp.sh /opt/start-wan2gp.sh
COPY restart-wan2gp.sh /usr/local/bin/restart-wan2gp.sh
RUN chmod +x /opt/start-wan2gp.sh /usr/local/bin/restart-wan2gp.sh

# ---- Prepare persistent caches (avoid permission issues at runtime) ----
RUN mkdir -p /workspace /workspace/outputs /workspace/models \
           /workspace/hf-home /workspace/hf-cache /workspace/.cache /workspace/.torchinductor

# ---- Container defaults ----
WORKDIR ${WAN2GP_DIR}
EXPOSE 7862 8888

ENTRYPOINT ["/usr/bin/tini","-g","--"]
CMD ["/opt/start-wan2gp.sh"]
