# docs/troubleshooting.md

# OASIS Build Environment Troubleshooting

This guide covers common issues you might encounter when setting up and using the OASIS build environment.

## Docker Issues

### Docker Daemon Not Running

**Symptoms:**
- `docker: Cannot connect to the Docker daemon`
- `docker-compose` commands fail with connection errors

**Solutions:**

**Linux:**
```bash
# Start Docker service
sudo systemctl start docker

# Enable Docker to start on boot
sudo systemctl enable docker

# Check Docker status
sudo systemctl status docker
```

**macOS/Windows:**
- Start Docker Desktop application
- Check system tray for Docker icon
- Restart Docker Desktop if necessary

### Permission Denied Errors (Linux)

**Symptoms:**
- `permission denied while trying to connect to the Docker daemon socket`

**Solution:**
```bash
# Add user to docker group
sudo usermod -aG docker $USER

# Log out and back in, or run:
newgrp docker

# Test Docker access
docker run hello-world
```

### Container Build Failures

**Symptoms:**
- `failed to solve: process "/bin/sh -c apt-get update" did not complete successfully`
- Network timeout errors during package installation

**Solutions:**

1. **Check internet connection:**
   ```bash
   ping google.com
   ```

2. **Clear Docker build cache:**
   ```bash
   docker builder prune -a
   ```

3. **Rebuild with no cache:**
   ```bash
   ./scripts/setup.sh --no-cache
   ```

4. **Check Docker DNS settings:**
   ```bash
   # Edit /etc/docker/daemon.json (Linux)
   {
     "dns": ["8.8.8.8", "8.8.4.4"]
   }
   
   # Restart Docker
   sudo systemctl restart docker
   ```

## Build Issues

### CMake Configuration Failures

**Symptoms:**
- `CMake Error: Could not find CMAKE_ROOT`
- `CMake Error: The source directory does not appear to contain CMakeLists.txt`

**Solutions:**

1. **Verify you're in the correct directory:**
   ```bash
   # Should be in OASIS project root
   ls -la CMakeLists.txt
   ```

2. **Check CMake installation in container:**
   ```bash
   docker-compose exec oasis-dev cmake --version
   ```

3. **Clear CMake cache:**
   ```bash
   rm -rf build/
   ./scripts/build.sh --clean
   ```

### Missing Dependencies

**Symptoms:**
- `fatal error: SpiceUsr.h: No such file or directory`
- `cannot find -lcspice`

**Solutions:**

1. **Verify SPICE installation:**
   ```bash
   docker-compose exec oasis-dev ls -la /opt/spice/cspice/
   docker-compose exec oasis-dev echo $SPICE_ROOT
   ```

2. **Rebuild container if SPICE is missing:**
   ```bash
   ./scripts/setup.sh --force-rebuild
   ```

3. **Check environment variables:**
   ```bash
   docker-compose exec oasis-dev env | grep SPICE
   ```

### Compilation Errors

**Symptoms:**
- `error: 'std::filesystem' has not been declared`
- C++17 feature compilation errors

**Solutions:**

1. **Verify compiler version:**
   ```bash
   docker-compose exec oasis-dev g++ --version
   ```

2. **Check CMake C++ standard setting:**
   ```bash
   # In CMakeLists.txt, ensure:
   set(CMAKE_CXX_STANDARD 17)
   set(CMAKE_CXX_STANDARD_REQUIRED ON)
   ```

## Python Issues

### Import Errors

**Symptoms:**
- `ModuleNotFoundError: No module named 'oasis'`
- Python binding import failures

**Solutions:**

1. **Check Python path:**
   ```bash
   docker-compose exec oasis-dev python3 -c "import sys; print(sys.path)"
   ```

2. **Verify PYTHONPATH:**
   ```bash
   docker-compose exec oasis-dev echo $PYTHONPATH
   ```

3. **Rebuild Python bindings:**
   ```bash
   ./scripts/build.sh --clean
   ```

### Pybind11 Issues

**Symptoms:**
- `pybind11/pybind11.h: No such file or directory`
- Python binding compilation failures

**Solutions:**

1. **Check pybind11 installation:**
   ```bash
   docker-compose exec oasis-dev python3 -c "import pybind11; print(pybind11.get_cmake_dir())"
   ```

2. **Verify pybind11 CMake configuration:**
   ```bash
   docker-compose exec oasis-dev find /usr -name "pybind11Config.cmake" 2>/dev/null
   ```

## VSCode Integration Issues

### Dev Container Not Starting

**Symptoms:**
- VSCode can't connect to container
- "Failed to connect" errors

**Solutions:**

1. **Ensure container is running:**
   ```bash
   docker-compose ps
   docker-compose up -d
   ```

2. **Check Dev Containers extension:**
   - Install "Dev Containers" extension
   - Reload VSCode window
   - Try "Remote-Containers: Rebuild Container"

3. **Verify VSCode settings:**
   ```bash
   # Copy VSCode settings
   cp config/vscode-settings.json .vscode/settings.json
   ```

### IntelliSense Not Working

**Symptoms:**
- No code completion
- Red squiggles under valid code
- "No compile commands found" errors

**Solutions:**

1. **Generate compile commands:**
   ```bash
   ./scripts/build.sh debug
   ```

2. **Check compile_commands.json:**
   ```bash
   ls -la build/compile_commands.json
   ```

3. **Reload VSCode window:**
   - `Ctrl+Shift+P` → "Developer: Reload Window"

4. **Reset C++ IntelliSense:**
   - `Ctrl+Shift+P` → "C/C++: Reset IntelliSense Database"

## Performance Issues

### Slow Build Times

**Symptoms:**
- Builds taking much longer than expected
- High CPU usage during compilation

**Solutions:**

1. **Increase parallel jobs:**
   ```bash
   # Set environment variable
   export CMAKE_BUILD_PARALLEL_LEVEL=8
   
   # Or use build script
   ./scripts/build.sh debug --jobs 8
   ```

2. **Allocate more resources to Docker:**
   - Docker Desktop → Settings → Resources
   - Increase CPU and memory allocation

3. **Use faster storage:**
   - Avoid building on network drives
   - Use SSD instead of HDD

### Container Startup Slow

**Symptoms:**
- Long delays when starting containers
- Timeout errors during startup

**Solutions:**

1. **Check available resources:**
   ```bash
   docker stats
   ```

2. **Reduce container resource limits:**
   ```yaml
   # In docker-compose.yml
   deploy:
     resources:
       limits:
         memory: 4G  # Reduce if needed
         cpus: '2.0'
   ```

3. **Clean up Docker system:**
   ```bash
   docker system prune -a
   ```

## Network Issues

### Package Download Failures

**Symptoms:**
- `Could not resolve 'archive.ubuntu.com'`
- Timeout during apt-get update

**Solutions:**

1. **Check host network connectivity:**
   ```bash
   ping 8.8.8.8
   ```

2. **Configure Docker DNS:**
   ```json
   // /etc/docker/daemon.json
   {
     "dns": ["8.8.8.8", "1.1.1.1"]
   }
   ```

3. **Use different package mirrors:**
   ```dockerfile
   # In Dockerfile, add before apt-get commands:
   RUN sed -i 's/archive.ubuntu.com/mirror.ubuntu.com/g' /etc/apt/sources.list
   ```

## File Permission Issues

### Volume Mount Permission Errors

**Symptoms:**
- Cannot write to mounted volumes
- Permission denied when accessing files

**Solutions:**

1. **Check user mapping:**
   ```bash
   # Verify USER_UID/GID in docker-compose.yml
   echo $USER_UID $USER_GID
   id
   ```

2. **Fix ownership (Linux):**
   ```bash
   sudo chown -R $USER:$USER .docker-volumes/
   ```

3. **Use correct user in container:**
   ```bash
   docker-compose exec --user developer oasis-dev bash
   ```

## Testing Issues

### Tests Not Running

**Symptoms:**
- `ctest` not found
- No tests discovered

**Solutions:**

1. **Verify test build:**
   ```bash
   ./scripts/build.sh debug
   ls build/debug/tests/
   ```

2. **Check CMake test configuration:**
   ```cmake
   # In CMakeLists.txt
   enable_testing()
   option(BUILD_TESTING "Build tests" ON)
   ```

3. **Run tests manually:**
   ```bash
   cd build/debug
   ctest --verbose
   ```

### Python Tests Failing

**Symptoms:**
- `pytest` command not found
- Import errors in test files

**Solutions:**

1. **Check pytest installation:**
   ```bash
   docker-compose exec oasis-dev python3 -m pytest --version
   ```

2. **Verify test directory structure:**
   ```bash
   ls -la tests/python/
   ```

3. **Run tests with full path:**
   ```bash
   docker-compose exec oasis-dev python3 -m pytest tests/python/ -v
   ```

## Getting Help

If you encounter issues not covered here:

1. **Check container logs:**
   ```bash
   docker-compose logs oasis-dev
   ```

2. **Verify system requirements:**
   - Docker 20.10+
   - Docker Compose 2.0+
   - 4GB+ free disk space
   - 8GB+ RAM recommended

3. **Search existing issues:**
   - Check GitHub issues for similar problems
   - Look for solutions in commit history

4. **Create detailed bug report:**
   - Include error messages
   - Provide system information
   - List reproduction steps
   - Attach relevant log files
