FROM nvidia/cuda:12.8.0-cudnn-devel-ubuntu24.04

RUN apt-get update -y && apt-get install -y --no-install-recommends \
    git git-lfs curl ca-certificates ffmpeg aria2 tini jq \
    build-essential python3-dev pkg-config \
    libgl1 libglib2.0-0 libsm6 libxrender1 libxext6 \
    python3 python3-pip wget curl cmake ninja-build

RUN git lfs install

RUN python3 -m pip install --break-system-packages \
    --extra-index-url https://download.pytorch.org/whl/cu128 \
    torch==2.10.0+cu128 torchvision==0.25.0+cu128

RUN python3 -m pip install --break-system-packages \
    --no-deps "numpy<2.1" "cython<3.2" "setuptools<75"

RUN git clone https://github.com/thu-ml/SageAttention.git /tmp/sageattention && \
    cd /tmp/sageattention && \
    export TORCH_CUDA_ARCH_LIST='8.0;8.6;8.9;9.0;12.0' FORCE_CUDA='1' MAX_JOBS='1' && \
    python3 -m pip install --break-system-packages --no-build-isolation . && \
    rm -rf /tmp/sageattention

RUN apt-get clean && rm -rf /var/lib/apt/lists/*
