# Bazel Build Summary

## Current Status

The Dockerfile has been successfully converted to Bazel with support for pushing to Docker Hub and other registries.

## Key Components

1. **MODULE.bazel**: Dependencies and base image pull
   - rules_oci 1.7.5
   - rules_pkg 0.10.0
   - rules_python 0.31.0
   - platforms 0.0.10

2. **BUILD.bazel**: Container image definition
   - `wan2gp_image`: Main OCI image target
   - `wan2gp_tarball`: Optional tarball export
   - `push_dockerhub_latest`: Push to Docker Hub with latest tag
   - `push_dockerhub_tag`: Push to Docker Hub with custom version tag
   - `push_ghcr_latest`: Push to GitHub Container Registry
   - `push_custom`: Push to any OCI-compliant registry

3. **.bazelrc**: Build configuration with environment variables

## Build Targets

### Available Targets
- `//:wan2gp_image` - Build the container image
- `//:wan2gp_tarball` - Create tarball export
- `//:push_dockerhub_latest` - Push to docker.io/stabldiff/wan2gp:latest
- `//:push_dockerhub_tag` - Push to docker.io/stabldiff/wan2gp:$(VERSION)
- `//:push_ghcr_latest` - Push to ghcr.io/$(GHCR_USERNAME)/wan2gp:latest
- `//:push_ghcr_tag` - Push to ghcr.io/$(GHCR_USERNAME)/wan2gp:$(VERSION)
- `//:push_custom` - Push to $(CUSTOM_REGISTRY)/wan2gp:$(VERSION)

### Aliases
- `//:push` - Same as push_dockerhub_latest
- `//:push-latest` - Same as push_dockerhub_latest
- `//:push-version` - Same as push_dockerhub_tag

## Usage

```bash
# Build image
bazel build //:wan2gp_image

# Build and load to Docker
bazel run //:wan2gp_image

# Push to Docker Hub (pre-configured to stabldiff/wan2gp)
bazel run //:push_dockerhub_latest

# Push with version tag
bazel run //:push_dockerhub_tag --define=VERSION=v1.0.0
```

## Configuration

Edit `.bazelrc` to change:
- `DOCKERHUB_USERNAME`: Docker Hub username (default: stabldiff)
- `GHCR_USERNAME`: GitHub username
- `VERSION`: Default version tag

Edit `BUILD.bazel` to change the Wan2GP repository URL in the `clone_wan2gp` genrule.

## Architecture

1. **Base Layer**: Pulls docker.io/nvidia/cuda:12.8.0-cudnn-devel-ubuntu24.04
2. **Dependency Script**: Generated at build time to install system and Python packages
3. **Repository Clone**: Clones Wan2GP from GitHub via genrule at build time
4. **Patching**: Applies torch.cuda.amp.autocast patch via genrule
5. **Layer Assembly**: Creates tar layers for repo, scripts, and workspace directories
6. **Image Assembly**: Combines all layers into final OCI image with environment variables

## Notes

- Dependencies are installed at container startup via `/opt/install_deps.sh`
- This allows for faster builds and smaller base images
- The entrypoint first runs dependencies, then starts the application
