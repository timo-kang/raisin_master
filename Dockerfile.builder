# RAISIN Build Environment
# Multi-stage build for efficient caching

# Stage 1: Base environment with system dependencies
FROM ubuntu:22.04 AS base

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y \
    build-essential \
    cmake \
    ninja-build \
    git \
    python3 \
    python3-pip \
    python3-dev \
    lsb-release \
    && rm -rf /var/lib/apt/lists/*

# Install Python dependencies
COPY requirements.txt .
RUN pip3 install -r requirements.txt

WORKDIR /workspace

# Stage 2: Dependency installation
FROM base AS dependencies

# Copy only files needed for dependency resolution
COPY raisin.py .
COPY commands/ ./commands/
COPY cmake/ ./cmake/
COPY templates/ ./templates/
COPY script/ ./script/

# Copy package.yaml files to determine dependencies
COPY src/ ./src/

# Install dependencies
COPY configuration_setting.docker.yaml configuration_setting.yaml
COPY repositories.yaml .
COPY install_dependencies.sh .

# RUN python3 raisin.py install-dependencies --config configuration_setting.yaml --repos repositories.yaml
RUN python3 raisin.py setup
RUN bash install_dependencies.sh
RUN python3 raisin.py install


# Stage 3: Full build
FROM dependencies AS builder

# Source code is already copied in previous stage
# Build everything
RUN python3 raisin.py build --type debug

# Stage 4: Release builder
FROM dependencies AS release-builder

RUN python3 raisin.py build --type release --install

# Stage 5: Runtime image (minimal, only runtime dependencies)
FROM ubuntu:22.04 AS runtime

RUN apt-get update && apt-get install -y \
    libboost-system1.74.0 \
    libboost-filesystem1.74.0 \
    libboost-thread1.74.0 \
    libssl3 \
    && rm -rf /var/lib/apt/lists/*

# Copy only built binaries
COPY --from=release-builder /workspace/install/ /opt/raisin/

ENV PATH="/opt/raisin/bin:${PATH}"
ENV LD_LIBRARY_PATH="/opt/raisin/lib:${LD_LIBRARY_PATH}"

WORKDIR /opt/raisin

# Default command (can be overridden)
CMD ["bash"]
