# Bazel Build - Troubleshooting Guide

## Issue Resolution Log

### 1. Invalid Repository Name Error
**Error:**
```
invalid user-provided repo name 'cuda_base_@platforms__os:linux': valid names may contain only A-Z, a-z, 0-9, '-', '_', '.', and must start with a letter
```

**Solution:** Removed `platforms` parameter from `oci.pull()` in MODULE.bazel

### 2. oci_image Attribute Errors
**Error:**
```
no such attribute 'ports' in 'oci_image' rule
no such attribute 'working_directory' in 'oci_image' rule
```

**Solution:** Removed unsupported attributes from `oci_image` in BUILD.bazel:
- Removed `ports` attribute (ports handled by base image)
- Removed `working_directory` attribute (moved to entrypoint command with `cd`)

### 3. Genrule Environment Variable Error
**Error:**
```
$(WAN2GP_REPO) not defined
```

**Solution:** Hardcoded repository URL directly in genrule command instead of using environment variable

### 4. Image Pull DNS Resolution Error
**Error:**
```
curl: (6) Could not resolve host: nvidia
```

**Solution:** Added explicit `docker.io/` registry prefix to image reference:
- Before: `image = "nvidia/cuda:12.8.0-cudnn-devel-ubuntu24.04"`
- After: `image = "docker.io/nvidia/cuda:12.8.0-cudnn-devel-ubuntu24.04"`

### 5. Base Image Reference Error
**Error:**
```
BUILD file not found in directory 'image' of external repository @@rules_oci++oci+cuda_base
```

**Solution:** Changed base reference in `oci_image`:
- Before: `base = "@cuda_base//image"`
- After: `base = "@cuda_base"`

## rules_oci Usage Notes

### Pulling an Image
```python
oci = use_extension("@rules_oci//oci:extensions.bzl", "oci")
oci.pull(
    name = "my_base",
    image = "docker.io/library/ubuntu:22.04",
)
use_repo(oci, "my_base")
```

### Using as Base in oci_image
```python
oci_image(
    name = "my_image",
    base = "@my_base",  # Reference the pulled image by name
    # ...
)
```

### Important: Do NOT use `//image` suffix
The `oci.pull()` extension creates a repository that can be referenced directly, not with a `//image` suffix.

## Common patterns to avoid

### ❌ Incorrect
```python
# Using platforms with Bazel targets
oci.pull(
    name = "my_base",
    image = "ubuntu:22.04",
    platforms = ["@platforms//os:linux"],  # Wrong
)

# Using //image suffix
oci_image(
    name = "my_image",
    base = "@my_base//image",  # Wrong
)

# Using unsupported attributes
oci_image(
    name = "my_image",
    base = "@my_base",
    ports = ["8080"],  # Not supported
    working_directory = "/app",  # Not supported
)
```

### ✅ Correct
```python
# Simple pull without platforms
oci.pull(
    name = "my_base",
    image = "docker.io/library/ubuntu:22.04",
)

# Direct reference
oci_image(
    name = "my_image",
    base = "@my_base",
    entrypoint = ["/bin/bash", "-c", "cd /app && ./run.sh"],
    env = {
        "PORT": "8080",
        "WORKDIR": "/app",
    },
)
```

## Debugging Tips

1. **Check external repository structure:**
```bash
bazel query --output=build @cuda_base//...
```

2. **Verify module dependencies:**
```bash
bazel mod graph
```

3. **Clean and rebuild:**
```bash
bazel clean --expunge
rm -rf ~/.cache/bazel
bazel build //:wan2gp_image
```

4. **Enable verbose output:**
```bash
bazel build --verbose_failures //:wan2gp_image
```

5. **Check rules_oci version compatibility:**
```bash
bazel mod deps | grep rules_oci
```

## Version Compatibility

- **rules_oci**: 1.7.5
- **rules_pkg**: 0.10.0
- **rules_python**: 0.31.0
- **platforms**: 0.0.10
- **Bazel**: 7.0+

## Reference Documentation

- [rules_oci GitHub](https://github.com/bazelbuild/rules_oci)
- [rules_pkg GitHub](https://github.com/bazelbuild/rules_pkg)
- [Bazel Modules](https://bazel.build/concepts/bazel-modules)
