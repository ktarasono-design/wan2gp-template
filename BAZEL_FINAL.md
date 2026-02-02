# Bazel Build - Final Summary

## Status

The Dockerfile has been successfully converted to a Bazel build system with Docker Hub push capabilities. All errors have been resolved.

## Fixed Issues

1. **Invalid repository name error**: Changed `platforms` from Bazel targets to platform strings: `platforms = ["linux/amd64"]`
2. **oci_image attribute errors**: Removed unsupported `ports` and `working_directory` attributes
3. **Genrule environment variable error**: Simplified repository cloning by hardcoding URL in BUILD.bazel
4. **Image pull error**: Added explicit `docker.io/` registry prefix to base image to fix DNS resolution
5. **Base image reference error**: Changed `base = "@cuda_base//image"` to `base = "@cuda_base"`
6. **Multi-architecture image error**: Added required `platforms = ["linux/amd64"]` to `oci.pull()`

## File Structure

### MODULE.bazel
```python
module(name = "wan2gp")

bazel_dep(name = "rules_oci", version = "1.7.5")
bazel_dep(name = "rules_pkg", version = "0.10.0")
bazel_dep(name = "rules_python", version = "0.31.0")
bazel_dep(name = "platforms", version = "0.0.10")

oci = use_extension("@rules_oci//oci:extensions.bzl", "oci")
oci.pull(
    name = "cuda_base",
    image = "docker.io/nvidia/cuda:12.8.0-cudnn-devel-ubuntu24.04",
    platforms = ["linux/amd64"],  # Required for multi-arch images
)
use_repo(oci, "cuda_base")
```

### .bazelrc
```
# Docker Hub configuration
build --define=DOCKERHUB_USERNAME=stabldiff
build --define=GHCR_USERNAME=yourusername
build --define=VERSION=v1.0.0
```

## Available Targets

- `//:wan2gp_image` - Build the OCI container image
- `//:wan2gp_tarball` - Create tarball export
- `//:push_dockerhub_latest` - Push to docker.io/stabldiff/wan2gp:latest
- `//:push_dockerhub_tag` - Push to docker.io/stabldiff/wan2gp:$(VERSION)
- `//:push_ghcr_latest` - Push to GHCR
- `//:push_ghcr_tag` - Push to GHCR with version tag
- `//:push_custom` - Push to any OCI registry
- `//:push` - Alias for push_dockerhub_latest
- `//:push-latest` - Alias for push_dockerhub_latest
- `//:push-version` - Alias for push_dockerhub_tag

## Usage Examples

```bash
# Build the container image
bazel build //:wan2gp_image

# Build and load to Docker (recommended)
bazel run //:wan2gp_image

# Push to Docker Hub (default: docker.io/stabldiff/wan2gp)
bazel run //:push_dockerhub_latest

# Push with custom version tag
bazel run //:push_dockerhub_tag --define=VERSION=v1.0.0

# Push to custom Docker Hub repository
bazel run //:push_dockerhub_latest --define=DOCKERHUB_USERNAME=yourusername

# Push to GitHub Container Registry
bazel run //:push_ghcr_latest --define=GHCR_USERNAME=yourusername

# Push to custom registry (ECR, GCR, etc.)
bazel run //:push_custom --define=CUSTOM_REGISTRY=your-registry.com/wan2gp --define=VERSION=v1.0.0
```

## Configuration

### Change Wan2GP Repository
Edit the `clone_wan2gp` genrule in `BUILD.bazel`:
```python
genrule(
    name = "clone_wan2gp",
    outs = ["wan2gp_clone"],
    cmd = "git clone https://github.com/your/custom/repo.git $@ || true",
)
```

### Change Docker Hub Username
Edit `.bazelrc`:
```
build --define=DOCKERHUB_USERNAME=yourusername
```

### Change CUDA Architectures
Edit `BUILD.bazel` in the `oci_image` env section:
```python
"CUDA_ARCHITECTURES": "8.0;8.6;8.9;9.0;12.0",  # Add your architectures
```

## Architecture Overview

1. **Base Layer**: Pulls docker.io/nvidia/cuda:12.8.0-cudnn-devel-ubuntu24.04 via rules_oci
2. **Dependency Script**: Generated at build time via genrule
3. **Repository Clone**: Clones Wan2GP from GitHub via genrule at build time
4. **Patching**: Applies torch.cuda.amp.autocast patch via genrule
5. **Layer Assembly**: Creates tar layers for repo, scripts, and workspace directories
6. **Image Assembly**: Combines all layers into final OCI image with environment variables

## Key Features

- **Fast Builds**: Dependencies installed at container startup, not build time
- **Small Base**: Uses official CUDA base image
- **Registry Support**: Push to Docker Hub, GHCR, or any OCI-compliant registry
- **Flexible Configuration**: Editable via BUILD.bazel and .bazelrc
- **Version Tagging**: Support for multiple version tags
- **Clean Architecture**: Follows Bazel best practices with rules_oci and rules_pkg

## Notes

- Ports (7862, 8888) are exposed through the base CUDA image
- Working directory is set in the entrypoint command
- Environment variables handle all runtime configuration
- SageAttention is compiled at container startup
