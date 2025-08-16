# Customizing the OASIS Build Environment

This guide explains how to customize the build environment for specific needs and preferences.

## Adding New Dependencies

### System Packages

To add new Ubuntu packages to the development environment:

1. **Edit requirements file:**
   ```bash
   # Add to requirements/system-packages.txt
   echo "libeigen3-dev" >> requirements/system-packages.txt
   ```

2. **Update Dockerfile:**
   ```dockerfile
   # Add to the apt-get install command in Dockerfile
   RUN apt-get update && apt-get install -y \
       # ... existing packages ...
       libeigen3-dev \
       && rm -rf /var/lib/apt/lists/*
   ```

3. **Rebuild container:**
   ```bash
   ./scripts/setup.sh --force-rebuild
   ```

### Python Packages

To add new Python packages:

1. **Edit requirements file:**
   ```bash
   # Add to requirements/python-requirements.txt
   echo "plotly>=5.0.0" >> requirements/python-requirements.txt
   ```

2. **Update Dockerfile:**
   ```dockerfile
   # Python packages are automatically installed from requirements file
   COPY requirements/python-requirements.txt /tmp/python-requirements.txt
   RUN pip3 install --no-cache-dir -r /tmp/python-requirements.txt
   ```

3. **Rebuild container:**
   ```bash
   ./scripts/setup.sh --force-rebuild
   ```

### C++ Libraries

For header-only libraries:

1. **Add as git submodule in third_party:**
   ```bash
   # In OASIS repository
   git submodule add https://github.com/fmtlib/fmt.git third_party/fmt
   ```

2. **Update CMakeLists.txt:**
   ```cmake
   # In third_party/CMakeLists.txt
   add_subdirectory(fmt)
   ```

For compiled libraries:

1. **Add installation to Dockerfile:**
   ```dockerfile
   # Install library from source
   RUN cd /opt && \
       git clone https://github.com/library/repo.git && \
       cd repo && \
       mkdir build && cd build && \
       cmake .. -DCMAKE_INSTALL_PREFIX=/usr/local && \
       make -j$(nproc) && \
       make install
   ```

## Compiler Configuration

### Changing Compiler

To use Clang instead of GCC:

1. **Update Dockerfile:**
   ```dockerfile
   # Install Clang
   RUN apt-get update && apt-get install -y \
       clang \
       clang-format \
       clang-tidy \
       libc++-dev \
       libc++abi-dev
   
   # Set default compiler
   ENV CXX=clang++
   ENV CC=clang
   ```

2. **Update CMake presets:**
   ```json
   {
     "configurePresets": [
       {
         "name": "clang-debug",
         "inherits": "base",
         "cacheVariables": {
           "CMAKE_CXX_COMPILER": "clang++",
           "CMAKE_C_COMPILER": "clang"
         }
       }
     ]
   }
   ```

### Custom Compiler Flags

To add project-specific compiler flags:

1. **Update cmake-presets.json:**
   ```json
   {
     "configurePresets": [
       {
         "name": "custom-debug",
         "inherits": "debug",
         "cacheVariables": {
           "CMAKE_CXX_FLAGS_DEBUG": "-g -O0 -Wall -Wextra -Werror -pedantic"
         }
       }
     ]
   }
   ```

2. **Or set in CMakeLists.txt:**
   ```cmake
   # Add custom flags
   if(CMAKE_CXX_COMPILER_ID STREQUAL "GNU")
       add_compile_options(-Wall -Wextra -Werror)
   endif()
   ```

## Development Tools

### Adding Static Analysis Tools

1. **Update Dockerfile:**
   ```dockerfile
   # Install analysis tools
   RUN apt-get update && apt-get install -y \
       cppcheck \
       clang-tidy \
       iwyu \
       && rm -rf /var/lib/apt/lists/*
   ```

2. **Create analysis script:**
   ```bash
   # scripts/analyze.sh
   #!/bin/bash
   
   echo "Running static analysis..."
   
   # Cppcheck
   cppcheck --enable=all --inconclusive src/
   
   # Clang-tidy
   find src/ -name "*.cpp" | xargs clang-tidy
   ```

### Custom Debugging Tools

1. **Add debugging tools to Dockerfile:**
   ```dockerfile
   # Install debugging tools
   RUN apt-get update && apt-get install -y \
       gdb \
       valgrind \
       strace \
       ltrace \
       perf-tools-unstable \
       && rm -rf /var/lib/apt/lists/*
   ```

2. **Configure GDB with custom commands:**
   ```bash
   # Add to config/gdb-init
   define debug_oasis_vector
       printf "Vector: [%f, %f, %f]\n", $arg0.x, $arg0.y, $arg0.z
   end
   ```

## VSCode Customization

### Adding Extensions

1. **Update vscode-settings.json:**
   ```json
   {
     "extensions.recommendations": [
       "ms-vscode.cpptools",
       "ms-vscode.cmake-tools",
       "ms-python.python",
       "cschlosser.doxdocgen",
       "austin.code-gnu-global"
     ]
   }
   ```

### Custom Tasks

1. **Create .vscode/tasks.json:**
   ```json
   {
     "version": "2.0.0",
     "tasks": [
       {
         "label": "OASIS: Full Build",
         "type": "shell",
         "command": "./scripts/build.sh",
         "args": ["debug"],
         "group": "build"
       },
       {
         "label": "OASIS: Run Tests",
         "type": "shell",
         "command": "./scripts/test.sh",
         "group": "test"
       }
     ]
   }
   ```

### Custom Keybindings

1. **Create .vscode/keybindings.json:**
   ```json
   [
     {
       "key": "ctrl+shift+b",
       "command": "workbench.action.tasks.runTask",
       "args": "OASIS: Full Build"
     },
     {
       "key": "ctrl+shift+t",
       "command": "workbench.action.tasks.runTask", 
       "args": "OASIS: Run Tests"
     }
   ]
   ```

## Docker Configuration

### Resource Limits

Adjust container resources in docker-compose.yml:

```yaml
services:
  oasis-dev:
    deploy:
      resources:
        limits:
          memory: 16G      # Increase for large builds
          cpus: '8.0'      # Use more CPU cores
        reservations:
          memory: 4G
          cpus: '2.0'
```

### Additional Volumes

Mount additional directories:

```yaml
services:
  oasis-dev:
    volumes:
      # Existing volumes...
      - /path/to/reference/data:/data:ro  # Read-only data
      - /path/to/shared/libs:/shared:ro   # Shared libraries
```

### Environment Variables

Add project-specific environment variables:

```yaml
services:
  oasis-dev:
    environment:
      # Existing variables...
      - OASIS_DATA_PATH=/data
      - OASIS_CONFIG_PATH=/workspace/config
      - CUDA_VISIBLE_DEVICES=0,1  # For GPU support
```

## Performance Optimization

### Build Cache Optimization

1. **Use ccache for faster rebuilds:**
   ```dockerfile
   # Add to Dockerfile
   RUN apt-get update && apt-get install -y ccache
   ENV PATH="/usr/lib/ccache:${PATH}"
   ```

2. **Configure ccache volume:**
   ```yaml
   # Add to docker-compose.yml volumes
   ccache-cache:
     driver: local
   ```

### Parallel Build Optimization

1. **Set optimal parallel jobs:**
   ```bash
   # In .bashrc or environment
   export CMAKE_BUILD_PARALLEL_LEVEL=$(nproc)
   export MAKEFLAGS=-j$(nproc)
   ```

2. **Use Ninja generator:**
   ```json
   // cmake-presets.json
   {
     "configurePresets": [
       {
         "generator": "Ninja"  // Faster than Make
       }
     ]
   }
   ```

## Integration with External Tools

### Continuous Integration

1. **GitHub Actions example:**
   ```yaml
   # .github/workflows/ci.yml
   name: CI
   on: [push, pull_request]
   
   jobs:
     build:
       runs-on: ubuntu-latest
       steps:
         - uses: actions/checkout@v3
         - name: Build environment
           run: |
             git clone https://github.com/your-org/oasis-build-env.git
             cd oasis-build-env && ./scripts/setup.sh
         - name: Build and test
           run: |
             docker-compose run --rm oasis-dev ./scripts/build.sh
             docker-compose run --rm oasis-dev ./scripts/test.sh
   ```

### Documentation Generation

1. **Add Doxygen support:**
   ```dockerfile
   # Install documentation tools
   RUN apt-get update && apt-get install -y \
       doxygen \
       graphviz \
       texlive-latex-base \
       && rm -rf /var/lib/apt/lists/*
   ```

2. **Create documentation script:**
   ```bash
   # scripts/docs.sh
   #!/bin/bash
   cd build
   cmake .. -DBUILD_DOCS=ON
   make docs
   ```

## Troubleshooting Custom Configurations

### Validation Script

Create a validation script to test customizations:

```bash
# scripts/validate.sh
#!/bin/bash

echo "Validating OASIS build environment..."

# Test compiler
docker-compose exec oasis-dev $CXX --version
docker-compose exec oasis-dev $CC --version

# Test Python
docker-compose exec oasis-dev python3 -c "import numpy, scipy, matplotlib"

# Test CMake
docker-compose exec oasis-dev cmake --version

# Test custom tools
docker-compose exec oasis-dev which cppcheck
docker-compose exec oasis-dev which valgrind

echo "Validation complete!"
```

### Common Issues

1. **Library conflicts:** Check LD_LIBRARY_PATH and library versions
2. **Path issues:** Verify all tools are in PATH
3. **Permission problems:** Ensure proper user mapping
4. **Resource constraints:** Monitor container resource usage

Remember to rebuild the container after making changes to the Dockerfile or requirements files using `./scripts/setup.sh --force-rebuild`.