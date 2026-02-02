# Wan2GP — ProbeAI (A40 / RTX 5090)
# Base: CUDA 12.8 / cuDNN runtime with Python + PyTorch preinstalled (conda @ /opt/conda)
FROM nvidia/cuda:12.8.0-cudnn-devel-ubuntu24.04

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

# ---- System deps (toolchain + minimal X/GL for OpenCV/insightface) ----
RUN apt-get update -y && apt-get install -y --no-install-recommends \
    git git-lfs curl ca-certificates ffmpeg aria2 tini jq \
    build-essential python3-dev pkg-config \
    libgl1 libglib2.0-0 libsm6 libxrender1 libxext6 \
 && git lfs install \
 && rm -rf /var/lib/apt/lists/*

RUN apt update && \
    apt install -y \
    python3 python3-pip git wget curl cmake ninja-build \
    libgl1 libglib2.0-0 ffmpeg && \
    apt clean

# ---- Clone Wan2GP (pin a commit via build arg; default to main) ----
ARG WAN2GP_REPO="https://github.com/deepbeepmeep/Wan2GP.git"
RUN git clone ${WAN2GP_REPO} ${WAN2GP_DIR}

# Patch the deprecated autocast once at build-time (prevents runtime warnings)
RUN sed -i "s/torch.cuda.amp.autocast(/torch.amp.autocast('cuda', /g" \
    ${WAN2GP_DIR}/models/wan/animate/motion_encoder.py || true

RUN pip install --break-system-packages --extra-index-url https://download.pytorch.org/whl/cu128 \
    torch>=2.6.0+cu128 torchvision>=0.21.0+cu128

# ---- Python deps (compile-safe order) ----
# NOTE: Torch already exists in /opt/conda from the base image; do NOT reinstall it.
RUN python3 -V && \
    python3 -m pip install --break-system-packages --no-deps "numpy<2.1" "cython<3.2" "setuptools<75" && \
    python3 -m pip install --break-system-packages -r ${WAN2GP_DIR}/requirements.txt

# Install SageAttention from git (patch GPU detection)
ENV TORCH_CUDA_ARCH_LIST="${CUDA_ARCHITECTURES}"
ENV FORCE_CUDA="1"
ENV MAX_JOBS="1"

COPY patch_setup.py /tmp/patch_setup.py

RUN git clone https://github.com/thu-ml/SageAttention.git /tmp/sageattention && \
    cd /tmp/sageattention && \
    python3 /tmp/patch_setup.py && \
    python3 -m pip install --no-build-isolation .

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
