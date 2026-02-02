# Final Bazel Configuration - Working Setup

## Configuration

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

### BUILD.bazel (Key Parts)
```python
oci_image(
    name = "wan2gp_image",
    base = "@cuda_base",  # Direct reference, NOT @cuda_base//image
    entrypoint = ["/usr/bin/tini", "-g", "--", "/bin/bash", "-c", "cd /opt/Wan2GP && /opt/install_deps.sh && /opt/start-wan2gp.sh"],
    env = { /* ... */ },
    tars = [":wan2gp_tar", ":install_deps_tar", ":start_scripts", ":workspace_dirs"],
)
```

## All Issues Resolved

1. ✅ **Invalid repository name error**
   - Used `platforms = ["linux/amd64"]` instead of Bazel targets

2. ✅ **oci_image attribute errors**
   - Removed `ports` (not supported)
   - Removed `working_directory` (moved to entrypoint)

3. ✅ **Genrule environment variable error**
   - Hardcoded repository URL directly in genrule

4. ✅ **Image pull DNS error**
   - Added `docker.io/` registry prefix

5. ✅ **Base image reference error**
   - Changed `base = "@cuda_base//image"` to `base = "@cuda_base"`

6. ✅ **Multi-architecture image error**
   - Added `platforms = ["linux/amd64"]` to `oci.pull()`

7. ✅ **Directory output declaration error**
   - Added trailing slashes to directory outputs: `"wan2gp_clone/"` instead of `"wan2gp_clone"`
   - Used `$(@D)` instead of `$@` for directory operations
   - Added cleanup: `rm -rf $(@D)` before operations

## Build Commands

```bash
# Build container image
fi

# Build and load to Docker
bazel run //:wan2gp_image

# Push to Docker Hub
bazel run //:push_dockerhub_latest

# Push with version tag
bazel run //:push_dockerhub_tag --define=VERSION=v1.0.0
```

## Key Takeaways for rules_oci

1. **Multi-architecture images require `platforms` parameter**
   ```python
   platforms = ["linux/amd64"]  # Use platform strings
   ```

2. **Don't use `//image` suffix on pulled images**
   ```python
   base = "@cuda_base"  # ✅ Correct
   base = "@cuda_base//image"  # ❌ Wrong
   ```

3. **Use platform strings, not Bazel targets**
   ```python
   platforms = ["linux/amd64"]  # ✅ Correct
   platforms = ["@platforms//os:linux", "@platforms//arch:x86_64"]  # ❌ Wrong
   ```

4. **oci_image doesn't support Dockerfile attributes**
   - No `ports` - use base image ports
   - No `working_directory` - use `cd` in entrypoint
   - No `expose` - handled by base image

## Specification

| Item | Value |
|-------|-------|
| Base Image | `docker.io/nvidia/cuda:12.8.0-cudnn-devel-ubuntu24.04` |
| Platform | `linux/amd64` |
| PyTorch | `torch==2.10.0+cu128` `torchvision==0.25.0+cu128` |
| CUDA Architectures | `8.0;8.6;8.9;9.0;12.0` |
| Docker Hub Repository | `docker.io/stabldiff/wan2gp` |
| WAN2GP Repository | `https://github.com/deepbeepmeep/Wan2GP.git` |

## Files

- **MODULE.bazel** - Bazel module and dependency configuration
- **BUILD.bazel** - Container image definition and targets
- **.bazelrc** - Build configuration and defaults
- **BAZEL_README.md** - User documentation
- **BAZEL_TROUBLESHOOTING.md** - Issue resolution guide
- **BAZEL_FINAL.md** - Complete reference
- **BAZEL_CONVERSION_SUMMARY.md** - Conversion details
- **BAZEL_STATUS.md** - Current status

This configuration is ready to build and push to Docker Hub.
