# OASIS Development Environment
# Ubuntu 24.04 LTS with C++, CMake, Python, and scientific computing tools

FROM ubuntu:24.04

# Prevent interactive prompts during package installation
ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=UTC

# Set locale
ENV LANG=C.UTF-8
ENV LC_ALL=C.UTF-8

# Create a non-root user for development
ARG USERNAME=developer
ARG USER_UID=1000
ARG USER_GID=${USER_UID}

# Install system dependencies
RUN apt-get update && apt-get install -y \
    # Build essentials
    build-essential \
    cmake \
    ninja-build \
    pkg-config \
    autoconf \
    automake \
    libtool \
    # Version control and utilities
    git \
    wget \
    curl \
    unzip \
    tar \
    gzip \
    bzip2 \
    xz-utils \
    # Debugging and profiling tools
    gdb \
    valgrind \
    strace \
    # Python development
    python3 \
    python3-pip \
    python3-dev \
    python3-venv \
    # Testing frameworks
    libgtest-dev \
    # Additional development tools
    vim \
    nano \
    tree \
    htop \
    # Libraries that might be needed
    libssl-dev \
    libffi-dev \
    libbz2-dev \
    libreadline-dev \
    libsqlite3-dev \
    && rm -rf /var/lib/apt/lists/*

# Install Google Test (build from source for proper CMake integration)
RUN cd /opt && \
    git clone https://github.com/google/googletest.git && \
    cd googletest && \
    git checkout release-1.12.1 && \
    mkdir build && cd build && \
    cmake .. -DBUILD_GMOCK=ON -DCMAKE_INSTALL_PREFIX=/usr/local && \
    make -j$(nproc) && \
    make install && \
    cd /opt && rm -rf googletest

# Install pybind11 system-wide
RUN pip3 install --no-cache-dir pybind11[global]

# Install Python development dependencies
COPY requirements/python-requirements.txt /tmp/python-requirements.txt
RUN pip3 install --no-cache-dir -r /tmp/python-requirements.txt

# # Install NASA SPICE Toolkit
# RUN mkdir -p /opt/spice && \
#     cd /opt/spice && \
#     wget -q https://naif.jpl.nasa.gov/pub/naif/toolkit/C/PC_Linux_GCC_64bit/packages/cspice.tar.Z && \
#     gunzip cspice.tar.Z && \
#     tar -xf cspice.tar && \
#     cd cspice && \
#     ./makeall.csh && \
#     # Clean up installation files
#     rm -f /opt/spice/cspice.tar && \
#     # Create symbolic links for easier access
#     ln -s /opt/spice/cspice/lib/cspice.a /usr/local/lib/libcspice.a && \
#     ln -s /opt/spice/cspice/include/*.h /usr/local/include/

# # Set up environment variables for development
# ENV SPICE_ROOT=/opt/spice/cspice
# ENV CMAKE_PREFIX_PATH=/opt/spice/cspice:${CMAKE_PREFIX_PATH}
# ENV PKG_CONFIG_PATH=/opt/spice/cspice/lib/pkgconfig:${PKG_CONFIG_PATH}
# ENV LD_LIBRARY_PATH=/opt/spice/cspice/lib:${LD_LIBRARY_PATH}
# ENV PATH=/opt/spice/cspice/bin:${PATH}

# # Create SPICE pkg-config file for easier CMake integration
# RUN mkdir -p /opt/spice/cspice/lib/pkgconfig && \
#     cat > /opt/spice/cspice/lib/pkgconfig/cspice.pc << 'EOF'
# prefix=/opt/spice/cspice
# exec_prefix=${prefix}
# libdir=${exec_prefix}/lib
# includedir=${prefix}/include

# Name: CSPICE
# Description: NASA SPICE Toolkit
# Version: N0067
# Libs: -L${libdir} -lcspice
# Cflags: -I${includedir}
# EOF

# Create the developer user and group
RUN groupadd --gid ${USER_GID} ${USERNAME} && \
    useradd --uid ${USER_UID} --gid ${USER_GID} --shell /bin/bash --create-home ${USERNAME}

# Install additional development tools as developer user
USER ${USERNAME}

# Set up Python user environment
RUN python3 -m pip install --user --no-cache-dir \
    ipython \
    jupyter \
    black \
    flake8 \
    mypy

# Copy configuration files
COPY --chown=${USERNAME}:${USERNAME} config/ /home/${USERNAME}/.config/
COPY --chown=${USERNAME}:${USERNAME} scripts/ /home/${USERNAME}/scripts/

# Make scripts executable
USER root
RUN chmod +x /home/${USERNAME}/scripts/*.sh && \
    ln -s /home/${USERNAME}/scripts/* /usr/local/bin/

# Create workspace directory
RUN mkdir -p /workspace && \
    chown ${USERNAME}:${USERNAME} /workspace

# Set up development environment
USER ${USERNAME}
WORKDIR /workspace

# Configure git (will be overridden by user's git config)
RUN git config --global user.name "OASIS Developer" && \
    git config --global user.email "developer@oasis-sim.local" && \
    git config --global init.defaultBranch main

# Configure GDB for better debugging
RUN echo "set print pretty on" >> /home/${USERNAME}/.gdbinit && \
    echo "set print array on" >> /home/${USERNAME}/.gdbinit && \
    echo "set print array-indexes on" >> /home/${USERNAME}/.gdbinit

# Set default build environment variables
ENV CXX=g++
ENV CC=gcc
ENV CMAKE_BUILD_TYPE=Debug
ENV CMAKE_EXPORT_COMPILE_COMMANDS=ON

# Default command
CMD ["/bin/bash"]

# Labels for image identification
LABEL maintainer="OASIS Development Team"
LABEL version="1.0"
LABEL description="Development environment for OASIS multibody dynamics engine"
LABEL org.opencontainers.image.source="https://github.com/jwallace16/oasis-build-env"
