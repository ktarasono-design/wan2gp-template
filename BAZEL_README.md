# Wan2GP Bazel Build

This is a Bazel-based build system for Wan2GP, replacing the original Dockerfile.

## Requirements

- Bazel 7.0+
- Docker (for running the built image)

## Build Commands

```bash
# Build the container image
bazel build //:wan2gp_image

# Or directly build and load to Docker (recommended)
bazel run //:wan2gp_image
```

## Push to Docker Hub

First, authenticate with Docker Hub:

```bash
docker login
```

Push to Docker Hub (default repository: `docker.io/stabldiff/wan2gp`):

```bash
# Push with 'latest' tag (using default username from .bazelrc)
bazel run //:push_dockerhub_latest

# Push with custom username
bazel run //:push_dockerhub_latest --define=DOCKERHUB_USERNAME=yourusername

# Push with custom version tag
bazel run //:push_dockerhub_tag --define=VERSION=v1.0.0

# Push multiple tags
bazel run //:push_dockerhub_latest && \
bazel run //:push_dockerhub_tag --define=VERSION=v1.0.0

# Using aliases
bazel run //:push              # same as push_dockerhub_latest
bazel run //:push-latest
bazel run //:push-version
```

**Configuration:**

Edit `.bazelrc` to configure your Docker Hub username and default version:

```
build --define=DOCKERHUB_USERNAME=yourusername
build --define=VERSION=v1.0.0
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

Edit the `clone_wan2gp` genrule in `BUILD.bazel` to change the repository URL:

```python
genrule(
    name = "clone_wan2gp",
    outs = ["wan2gp_clone"],
    cmd = "git clone https://github.com/your/custom/repo.git $@ || true",
)
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
| `EXPOSE 7862` | Handled via environment variables |
| `WORKDIR /opt/Wan2GP` | Included in entrypoint command |

## Notes

- Dependencies are installed at container startup via `/opt/install_deps.sh`
- This allows for faster builds and smaller base images
- The entrypoint changes to `/opt/Wan2GP`, runs dependencies, then starts the application
- Ports (7862, 8888) are exposed through the base CUDA image and configured via environment variables
- Working directory is set in the entrypoint command rather than as a separate attribute
