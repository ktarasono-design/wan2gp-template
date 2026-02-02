import os
with open('setup.py', 'r') as f:
    content = f.read()

# Get architectures from environment variable
arch_list = os.environ.get('TORCH_CUDA_ARCH_LIST')
arch_set = '{' + ', '.join([f'"{arch}"' for arch in arch_list.split(';')]) + '}'

# Replace the GPU detection section
old_section = '''compute_capabilities = set()
device_count = torch.cuda.device_count()
for i in range(device_count):
    major, minor = torch.cuda.get_device_capability(i)
    if major < 8:
        warnings.warn(f"skipping GPU {i} with compute capability {major}.{minor}")
        continue
    compute_capabilities.add(f"{major}.{minor}")'''

new_section = 'compute_capabilities = ' + arch_set + '''
print(f"Manually set compute capabilities: {compute_capabilities}")'''

content = content.replace(old_section, new_section)

with open('setup.py', 'w') as f:
    f.write(content)
