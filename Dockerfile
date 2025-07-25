FROM ubuntu:25.04

# Install essential dev tools
RUN apt-get update && apt-get install -y \
    build-essential \
    cmake \
    git
    wget \
    curl \
    g++-12 \
    python3 \
    python3-pip \
    python3-dev \
    libgtest-dev \
    && rm -rf /var/lib/apt/lists/*

# Optional: Set default compiler to g++-12
RUN update-alternatives --install /usr/bin/g++ g++ /usr/bin/g++-12 100 \
    && update-alternatives --install /usr/bin/gcc gcc /usr/bin/gcc-12 100

# Install Gtest
RUN cd /usr/src/gtest && cmake . && make && cp lib/*.a /usr/lib

# Set work directory (used during build)
WORKDIR /build

CMD ["/bin/bash"]
