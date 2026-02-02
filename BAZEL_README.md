# Wan2GP Bazel Build

This is a Bazel-based build system for Wan2GP, replacing the original Dockerfile.

## Requirements

- Bazel 7.0+
- Docker (for running the built image)

## Build Commands

```bash
# Build the container image tarball
bazel build //:wan2gp_tarball

# Load into Docker
docker load -i bazel-bin/wan2gp_tarball/tar.tar

# Or directly build and load
bazel run //:wan2gp_image
```

## Push to Docker Hub

First, authenticate with Docker Hub:

```bash
docker login
```

Push to Docker Hub (replace `yourusername` with your Docker Hub username):

```bash
# Push with 'latest' tag
bazel run //:push_dockerhub_latest --define=DOCKERHUB_USERNAME=yourusername

# Push with custom version tag
bazel run //:push_dockerhub_tag --define=DOCKERHUB_USERNAME=yourusername --define=VERSION=v1.0.0

# Push multiple tags
bazel run //:push_dockerhub_latest --define=DOCKERHUB_USERNAME=yourusername && \
bazel run //:push_dockerhub_tag --define=DOCKERHUB_USERNAME=yourusername --define=VERSION=v1.0.0

# Using aliases (after setting defaults in .bazelrc)
bazel run //:push              # same as push_dockerhub_latest
bazel run //:push-latest
bazel run //:push-version
```

**Set defaults in `.bazelrc`:**

Edit `.bazelrc` to configure your Docker Hub username and default version:

```
build --define=DOCKERHUB_USERNAME=yourusername
build --define=VERSION=v1.0.0
```

Then you can simply run:

```bash
bazel run //:push_dockerhub_latest
bazel run //:push_dockerhub_tag
```

The image will be pushed to: `docker.io/yourusername/wan2gp:tag`

## Push to GitHub Container Registry (GHCR)

First, authenticate with GHCR:

```bash
echo "YOUR_GITHUB_TOKEN" | docker login ghcr.io -u USERNAME --password-stdin
```

Push to GHCR:

```bash
# Push with 'latest' tag
bazel run //:push_ghcr_latest --define=GHCR_USERNAME=yourusername

# Push with custom version tag
bazel run //:push_ghcr_tag --define=GHCR_USERNAME=yourusername --define=VERSION=v1.0.0
```

The image will be pushed to: `ghcr.io/yourusername/wan2gp:tag`

## Push to Custom Registry

Push to any OCI-compliant registry:

```bash
# Example: push to ECR
bazel run //:push_custom --define=CUSTOM_REGISTRY=123456789012.dkr.ecr.us-east-1.amazonaws.com/wan2gp --define=VERSION=v1.0.0

# Example: push to GCR
bazel run //:push_custom --define=CUSTOM_REGISTRY=gcr.io/yourproject/wan2gp --define=VERSION=v1.0.0

# Example: push to local registry
bazel run //:push_custom --define=CUSTOM_REGISTRY=localhost:5000/wan2gp --define=VERSION=v1.0.0
```

## Build with custom Wan2GP repo

```bash
# Build with custom repository
bazel build --action_env=WAN2GP_REPO=https://github.com/your/custom/repo.git //:wan2gp_image

# Push with custom repository
bazel run //:push_dockerhub_latest --action_env=WAN2GP_REPO=https://github.com/your/custom/repo.git
```

## Custom CUDA architectures

Edit `BUILD.bazel` to modify the `CUDA_ARCHITECTURES` environment variable:

```python
"CUDA_ARCHITECTURES": "8.0;8.6;8.9;9.0;12.0",  # Add your architectures
```

## Structure

- `MODULE.bazel`: Bazel module dependencies and OCI image pulls
- `BUILD.bazel`: Container image definition with genrules
- `.bazelrc`: Build configuration with environment variables

## Key Components

1. **Base Image**: Pulls `nvidia/cuda:12.8.0-cudnn-devel-ubuntu24.04` via rules_oci
2. **Repository Clone**: Clones Wan2GP from GitHub via genrule at build time
3. **Patching**: Applies torch.cuda.amp.autocast patch via genrule
4. **Dependency Installation**: Installs system and Python dependencies at container startup
5. **Layering**: Creates tar layers for repo, scripts, and workspace directories
6. **Image Assembly**: Combines all layers into final OCI image

## Dockerfile vs Bazel Equivalent

| Dockerfile | Bazel |
|------------|-------|
| `FROM nvidia/cuda:...` | `oci.pull()` in MODULE.bazel |
| `RUN git clone ...` | `genrule()` cloning at build time |
| `RUN sed -i ...` | `genrule()` for patching |
| `RUN apt-get install ...` | `genrule()` creating install script |
| `RUN pip install ...` | Included in install script, runs at container startup |
| `COPY file.sh /opt/` | `pkg_tar()` with srcs |
| `ENV VAR=value` | `oci_image(env={...})` |
| `ENTRYPOINT [...]` | `oci_image(entrypoint=[...])` |
| `EXPOSE 7862` | `oci_image(ports=["7862"])` |
