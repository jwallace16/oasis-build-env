# OASIS Build Environment

A containerized development environment for the OASIS multibody dynamics engine, ensuring consistent builds and dependencies across all development machines.

## Purpose

This repository provides a standardized Docker-based build environment for OASIS development. By containerizing the build tools, compilers, and dependencies, we eliminate "works on my machine" issues and ensure reproducible builds across different development setups.

## Repository Contents

```
oasis-build-env/
├── README.md                    # This file
├── LICENSE                      # Project license
├── Dockerfile                   # Main development environment
├── docker-compose.yml           # Container orchestration
├── scripts/
│   ├── setup.sh                # Environment setup script
│   ├── build.sh                # Build automation script
│   ├── test.sh                 # Test runner script
│   └── clean.sh                # Cleanup utilities
├── config/
│   ├── cmake-presets.json      # CMake configuration presets
│   ├── vscode-settings.json    # VSCode development settings
│   └── gdb-init                # GDB debugger configuration
├── requirements/
│   ├── system-packages.txt     # Ubuntu system packages
│   ├── python-requirements.txt # Python dependencies
│   └── build-tools.txt         # Development tool versions
└── docs/
    ├── troubleshooting.md      # Common issues and solutions
    └── customization.md        # Customizing the environment
```

## Prerequisites

- Docker Engine (version 20.10 or later)
- Docker Compose (version 2.0 or later)
- Git (for repository cloning)
- Minimum 4GB free disk space for the container image

### System Requirements

**Linux (Recommended):**
- Ubuntu 20.04 LTS or later
- Any modern Linux distribution with Docker support

**macOS:**
- macOS 10.15 (Catalina) or later
- Docker Desktop for Mac

**Windows:**
- Windows 10 (version 2004) or later
- Docker Desktop for Windows with WSL2 backend
- WSL2 with Ubuntu distribution (recommended for best performance)

## Quick Start

### 1. Clone This Repository

```bash
git clone https://github.com/your-username/oasis-build-env.git
cd oasis-build-env
```

### 2. Build the Development Environment

```bash
# Build the Docker image
docker build -t oasis-dev:latest .

# Or use the provided script
./scripts/setup.sh
```

### 3. Clone and Set Up OASIS

```bash
# Clone the main OASIS repository (adjust URL as needed)
git clone https://github.com/your-username/oasis.git
cd oasis

# Copy the docker-compose configuration
cp ../oasis-build-env/docker-compose.yml .

# Start the development container
docker-compose up -d
```

### 4. Enter the Development Environment

```bash
# Connect to the running container
docker-compose exec oasis-dev bash

# You're now inside the containerized build environment
# The OASIS source code is mounted at /workspace
```

## Development Workflow

### Building OASIS

Inside the container:

```bash
# Configure the build
cmake -S . -B build -DCMAKE_BUILD_TYPE=Debug

# Build the project
cmake --build build --parallel $(nproc)

# Or use the convenience script
/scripts/build.sh
```

### Running Tests

```bash
# Run C++ tests
cd build && ctest --verbose

# Run Python tests (once Python bindings are implemented)
cd python && python -m pytest

# Or use the test script
/scripts/test.sh
```

### Development with VSCode

1. **Install the Dev Containers extension** in VSCode
2. **Copy VSCode settings:**
   ```bash
   cp config/vscode-settings.json /workspace/.vscode/settings.json
   ```
3. **Open the project:** Use "Remote-Containers: Open Folder in Container"
4. **IntelliSense will work automatically** with the configured compiler paths

### Using Other IDEs

The build environment works with any IDE that can work with CMake projects:

- **CLion:** Open the CMakeLists.txt file directly
- **Qt Creator:** Import the CMake project
- **Command Line:** Use cmake and make commands directly
- **Vim/Neovim:** Use with cmake-tools or similar plugins

## Container Details

### Base Image
- **Ubuntu 22.04 LTS** - Long-term support and stability
- **GCC 11** - Modern C++17/20 support with excellent optimization
- **CMake 3.22+** - Latest build system features
- **Python 3.10** - For bindings and scripting

### Installed Dependencies

**System Tools:**
- build-essential (GCC, G++, Make)
- cmake, ninja-build
- git, wget, curl
- gdb, valgrind (debugging tools)
- pkg-config

**Scientific Computing:**
- NASA SPICE Toolkit (ephemeris and coordinate transformations)
- Google Test framework
- pybind11 (Python bindings)

**Python Environment:**
- numpy, scipy (numerical computing)
- matplotlib (plotting and visualization)
- pytest (testing framework)
- pybind11[global] (C++ binding utilities)

### Environment Variables

The container sets up several environment variables for development:

```bash
SPICE_ROOT=/opt/spice/cspice          # NASA SPICE installation
CMAKE_PREFIX_PATH=/opt/spice/cspice   # Help CMake find SPICE
PYTHONPATH=/workspace/python          # Python module path
CXX=g++                              # Default C++ compiler
CC=gcc                               # Default C compiler
```

## Customization

### Adding New Dependencies

1. **System packages:** Add to `requirements/system-packages.txt`
2. **Python packages:** Add to `requirements/python-requirements.txt`
3. **Rebuild the image:** Run `./scripts/setup.sh`

### Compiler Configuration

Edit `config/cmake-presets.json` to modify:
- Compiler flags
- Build types (Debug, Release, RelWithDebInfo)
- Generator preferences (Make vs Ninja)

### Development Tools

The environment includes several pre-configured development tools:

- **GDB:** Configured with pretty printers for STL containers
- **Valgrind:** Memory debugging and profiling
- **AddressSanitizer:** Compile-time memory error detection
- **Clang-Format:** Code formatting (LLVM style)

## Troubleshooting

### Common Issues

**Container won't start:**
```bash
# Check Docker daemon status
sudo systemctl status docker

# Verify Docker installation
docker --version
docker-compose --version
```

**Permission issues on Linux:**
```bash
# Add user to docker group
sudo usermod -aG docker $USER
# Log out and back in, or run:
newgrp docker
```

**Out of disk space:**
```bash
# Clean up Docker system
docker system prune -a

# Remove unused containers and images
docker container prune
docker image prune
```

**CMake can't find dependencies:**
```bash
# Verify environment variables
echo $SPICE_ROOT
echo $CMAKE_PREFIX_PATH

# Rebuild container if needed
./scripts/setup.sh --force-rebuild
```

### Performance Optimization

**For better build performance:**
- Increase Docker memory allocation (8GB+ recommended)
- Use Ninja instead of Make: `cmake -GNinja`
- Enable parallel builds: `cmake --build build --parallel $(nproc)`

**For debugging performance:**
- Use Debug builds for development: `-DCMAKE_BUILD_TYPE=Debug`
- Use RelWithDebInfo for performance testing: `-DCMAKE_BUILD_TYPE=RelWithDebInfo`
- Profile with Valgrind: `valgrind --tool=callgrind ./your_program`

## Scripts Reference

### setup.sh
Builds the Docker image and performs initial setup:
```bash
./scripts/setup.sh [--force-rebuild] [--no-cache]
```

### build.sh
Automated build script with common configurations:
```bash
./scripts/build.sh [debug|release|relwithdebinfo] [--clean] [--tests]
```

### test.sh
Comprehensive test runner:
```bash
./scripts/test.sh [--cpp-only] [--python-only] [--coverage]
```

### clean.sh
Cleanup utilities:
```bash
./scripts/clean.sh [--build-dir] [--containers] [--all]
```

## Contributing to the Build Environment

If you need to modify the build environment:

1. **Test changes locally** before committing
2. **Update documentation** if adding new tools or dependencies
3. **Verify cross-platform compatibility** when possible
4. **Update version numbers** in requirements files
5. **Test with a clean container** to ensure reproducibility

## Security Considerations

- The container runs with your user ID to avoid permission issues
- Network access is limited to necessary package downloads
- No sensitive data should be stored in the container image
- Use volume mounts for persistent data and source code

## License

This build environment is licensed under the same terms as the main OASIS project. See LICENSE file for details.

## Support

For issues with the build environment:
1. Check the [troubleshooting guide](docs/troubleshooting.md)
2. Search existing GitHub issues
3. Create a new issue with:
   - Your operating system and Docker version
   - Complete error messages
   - Steps to reproduce the problem

---

**Note:** This build environment is specifically designed for OASIS development. While the tools and configuration may be useful for other projects, it's optimized for the specific needs of multibody dynamics simulation development.