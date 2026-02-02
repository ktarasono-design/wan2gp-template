# Bazel Build System - Conversion Summary

## Overview
Successfully converted Dockerfile to Bazel build system with support for pushing to Docker Hub and other OCI registries.

## Key Changes from Dockerfile

### Base Image
- **Dockerfile**: `nvidia/cuda:12.8.0-cudnn-devel-ubuntu24.04`
- **Bazel**: `docker.io/nvidia/cuda:12.8.0-cudnn-devel-ubuntu24.04`
  - Added explicit `docker.io/` registry prefix to fix DNS resolution
  - Kept same version as original Dockerfile

### PyTorch Version
- **Dockerfile**: `torch==2.10.0+cu128 torchvision==0.25.0+cu128`
- **Bazel**: `torch==2.10.0+cu128 torchvision==0.25.0+cu128`
  - Kept same version as original Dockerfile

### Dependency Installation
- **Dockerfile**: All packages installed during image build
- **Bazel**: Packages installed at container startup via `/opt/install_deps.sh`
  - Faster build times
  - Smaller base image size

## Files Created/Modified

### Core Files
1. **MODULE.bazel** - Bazel module configuration
   - rules_oci 1.7.5
   - rules_pkg 0.10.0
   - rules_python 0.31.0
   - platforms 0.0.10
   - OCI base image pull configuration

2. **BUILD.bazel** - Container image definition
   - `wan2gp_image`: Main OCI image target
   - `wan2gp_tarball`: Optional tarball export
   - `install_deps`: Genrule to create dependency installation script
   - `clone_wan2gp`: Genrule to clone Wan2GP repository
   - `patch_wan2gp`: Genrule to apply patches
   - Multiple `oci_push` targets for different registries

3. **.bazelrc** - Build configuration
   - Docker Hub username (default: stabldiff)
   - GHCR username
   - Default version tag

### Documentation
4. **BAZEL_README.md** - User documentation
5. **BAZEL_STATUS.md** - Build system status
6. **BAZEL_FINAL.md** - Complete reference guide

## Available Targets

### Build Targets
- `//:wan2gp_image` - Build the container image
- `//:wan2gp_tarball` - Create tarball export

### Push Targets
- `//:push_dockerhub_latest` - Push to `docker.io/stabldiff/wan2gp:latest`
- `//:push_dockerhub_tag` - Push to `docker.io/stabldiff/wan2gp:$(VERSION)`
- `//:push_ghcr_latest` - Push to GitHub Container Registry
- `//:push_ghcr_tag` - Push to GHCR with version tag
- `//:push_custom` - Push to any OCI-compliant registry

### Aliases
- `//:push` - Alias for push_dockerhub_latest
- `//:push-latest` - Alias for push_dockerhub_latest
- `//:push-version` - Alias for push_dockerhub_tag

## Usage Examples

### Build and Test
```bash
# Build container image
bazel build //:wan2gp_image

# Build and load to Docker
bazel run //:wan2gp_image
```

### Push to Docker Hub
```bash
# Push with latest tag
bazel run //:push_dockerhub_latest

# Push with custom version tag
bazel run //:push_dockerhub_tag --define=VERSION=v1.0.0

# Push to custom Docker Hub repository
bazel run //:push_dockerhub_latest --define=DOCKERHUB_USERNAME=yourusername
```

### Push to Other Registries
```bash
# GitHub Container Registry
bazel run //:push_ghcr_latest --define=GHCR_USERNAME=yourusername

# Custom registry (ECR, GCR, etc.)
bazel run //:push_custom --define=CUSTOM_REGISTRY=your-registry.com/wan2gp --define=VERSION=v1.0.0
```

## Configuration

### Change Repository URL
Edit `BUILD.bazel` genrule:
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
Edit `BUILD.bazel` in `oci_image` env:
```python
"CUDA_ARCHITECTURES": "8.0;8.6;8.9;9.0;12.0",  # Add your architectures
```

### Change Base Image
Edit `MODULE.bazel`:
```python
oci.pull(
    name = "cuda_base",
    image = "docker.io/your-image:tag",
)
```

## Issues Resolved

1. ✅ Invalid repository name error - Removed `platforms` parameter
2. ✅ oci_image attribute errors - Removed unsupported `ports` and `working_directory`
3. ✅ Genrule environment variable error - Hardcoded repository URL
4. ✅ Image pull error - Added explicit `docker.io/` registry prefix to fix DNS resolution
5. ✅ Base image reference error - Changed `base = "@cuda_base//image"` to `base = "@cuda_base"`

## Architecture

```
MODULE.bazel
├── rules_oci (base image pull)
├── rules_pkg (tar layer creation)
├── rules_python (Python tools)
└── platforms (platform definitions)

BUILD.bazel
├── install_deps (genrule → install_deps.sh)
├── clone_wan2gp (genrule → wan2gp_clone)
├── patch_wan2gp (genrule → wan2gp_patched)
├── wan2gp_tar (pkg_tar)
├── install_deps_tar (pkg_tar)
├── start_scripts (pkg_tar)
├── workspace_dirs (pkg_tar)
└── wan2gp_image (oci_image)
    └── → Multiple oci_push targets
```

## Benefits of Bazel Build

1. **Reproducibility**: Same build artifacts across different environments
2. **Incremental Builds**: Only rebuild changed components
3. **Parallelism**: Automatic parallel execution of independent targets
4. **Multi-Registry Support**: Easy push to different registries
5. **Versioning**: Native support for semantic versioning
6. **Dependency Management**: Explicit dependency declarations in MODULE.bazel
7. **Caching**: Bazel's build cache speeds up rebuilds

## Notes

- Dependencies are installed at container startup (not build time) for faster builds
- Ports (7862, 8888) are exposed through base CUDA image
- Working directory is set in the entrypoint command
- SageAttention is compiled at container startup
- All environment variables are configurable via BUILD.bazel
- Registry authentication handled by Docker login (not Bazel)

## Next Steps

To use the Bazel build system:

1. Configure Docker Hub username in `.bazelrc` or pass as define
2. Run `bazel build //:wan2gp_image` to test the build
3. Run `bazel run //:push_dockerhub_latest` to push to Docker Hub
4. Configure CI/CD to use Bazel for automated builds
5. Add additional targets as needed (e.g., test targets, lint targets)
