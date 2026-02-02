# Genrule Directory Output Fix

## Issue
```
output 'wan2gp_clone' of //:clone_wan2gp is a directory but was not declared as such
```

## Problem
When using `git clone` in a genrule, it creates a directory. Bazel requires directory outputs to be explicitly declared with a trailing slash.

## Solution

### Clone genrule (clone_wan2gp)
```python
# Before (incorrect)
genrule(
    name = "clone_wan2gp",
    outs = ["wan2gp_clone"],  # ❌ No trailing slash
    cmd = "git clone https://github.com/repo.git $@ || true",
)

# After (correct)
genrule(
    name = "clone_wan2gp",
    outs = ["wan2gp_clone/"],  # ✅ Trailing slash indicates directory
    cmd = "rm -rf $(@D) && git clone https://github.com/repo.git $(@D) || true",
)
```

### Patch genrule (patch_wan2gp)
```python
# Before (incorrect)
genrule(
    name = "patch_wan2gp",
    srcs = [":clone_wan2gp"],
    outs = ["wan2gp_patched"],  # ❌ No trailing slash
    cmd = "cp -r $(SRCS) $@ && find $@ -name 'file.py' -exec sed ...",
)

# After (correct)
genrule(
    name = "patch_wan2gp",
    srcs = [":clone_wan2gp"],
    outs = ["wan2gp_patched/"],  # ✅ Trailing slash indicates directory
    cmd = "rm -rf $(@D) && cp -r $(SRCS) $(@D) && find $(@D) -name 'file.py' -exec sed ...",
)
```

## Key Changes

1. **Trailing slash in `outs`**: `"wan2gp_clone/"` instead of `"wan2gp_clone"`
2. **Use `$(@D)` instead of `$@`**: For directory operations
3. **Add cleanup**: `rm -rf $(@D)` before creating output to avoid conflicts

## Directory Output Rules

| Output Type | Declaration | Reference |
|-------------|--------------|------------|
| File | `outs = ["file.txt"]` | `$@` or `$(@D)/file.txt` |
| Directory | `outs = ["dir/"]` | `$(@D)` (directory path only) |

## pkg_tar with Directory Outputs

```python
pkg_tar(
    name = "my_tar",
    srcs = [":my_dir_genrule"],  # Directory output
    package_dir = "/app",  # Destination in tar
    strip_prefix = "",  # Don't strip any prefixes
)
```

## Updated Files

### BUILD.bazel
```python
genrule(
    name = "clone_wan2gp",
    outs = ["wan2gp_clone/"],  # Directory output
    cmd = "rm -rf $(@D) && git clone https://github.com/deepbeepmeep/Wan2GP.git $(@D) || true",
)

genrule(
    name = "patch_wan2gp",
    srcs = [":clone_wan2gp"],
    outs = ["wan2gp_patched/"],  # Directory output
    cmd = "rm -rf $(@D) && cp -r $(SRCS) $(@D) && " +
          "find $(@D) -name 'motion_encoder.py' -exec sed -i 's/torch.cuda.amp.autocast(/torch.amp.autocast('cuda', /g' {} + 2>/dev/null || true",
)

pkg_tar(
    name = "wan2gp_tar",
    srcs = [":patch_wan2gp"],
    package_dir = "/opt/Wan2GP",
    strip_prefix = "",  # Keep directory structure
)
```

## Error Resolution

Issue 7: ✅ **Directory output declaration error**
- Added trailing slashes to directory outputs
- Used `$(@D)` for directory operations
- Added cleanup commands

This completes all error fixes for the Bazel build system.
