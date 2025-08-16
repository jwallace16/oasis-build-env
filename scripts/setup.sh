#!/bin/bash
# OASIS Build Environment Setup Script
# Sets up the Docker development environment for OASIS

set -e  # Exit on any error

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
IMAGE_NAME="oasis-dev"
IMAGE_TAG="latest"
CONTAINER_NAME="oasis-dev"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Help function
show_help() {
    cat << EOF
OASIS Build Environment Setup

Usage: $0 [OPTIONS]

OPTIONS:
    -h, --help              Show this help message
    --force-rebuild         Force rebuild of Docker image
    --no-cache              Build without Docker cache
    --clean                 Clean up existing containers and volumes
    --check-only           Only check prerequisites without building
    --user-uid UID         Set user UID (default: current user's UID)
    --user-gid GID         Set user GID (default: current user's GID)

Examples:
    $0                      # Standard setup
    $0 --force-rebuild      # Rebuild image from scratch
    $0 --clean              # Clean up and rebuild
    $0 --check-only         # Just check if Docker is working

EOF
}

# Check prerequisites
check_prerequisites() {
    log_info "Checking prerequisites..."
    
    # Check if Docker is installed and running
    if ! command -v docker &> /dev/null; then
        log_error "Docker is not installed. Please install Docker first."
        exit 1
    fi
    
    if ! docker info &> /dev/null; then
        log_error "Docker daemon is not running. Please start Docker."
        exit 1
    fi
    
    # Check Docker version
    DOCKER_VERSION=$(docker --version | grep -oP '\d+\.\d+')
    REQUIRED_VERSION="20.10"
    if ! awk "BEGIN {exit !($DOCKER_VERSION >= $REQUIRED_VERSION)}"; then
        log_warning "Docker version $DOCKER_VERSION detected. Version $REQUIRED_VERSION or later is recommended."
    fi
    
    # Check if docker-compose is available
    if command -v docker-compose &> /dev/null; then
        COMPOSE_CMD="docker-compose"
        COMPOSE_VERSION=$(docker-compose --version | grep -oP '\d+\.\d+')
    elif docker compose version &> /dev/null; then
        COMPOSE_CMD="docker compose"
        COMPOSE_VERSION=$(docker compose version --short | grep -oP '\d+\.\d+')
    else
        log_error "Neither docker-compose nor 'docker compose' is available."
        exit 1
    fi
    
    log_success "Docker $DOCKER_VERSION and Compose $COMPOSE_VERSION detected"
    
    # Check available disk space (minimum 4GB)
    AVAILABLE_SPACE=$(df / | awk 'NR==2 {print $4}')
    REQUIRED_SPACE=4194304  # 4GB in KB
    if [ "$AVAILABLE_SPACE" -lt "$REQUIRED_SPACE" ]; then
        log_warning "Only $(($AVAILABLE_SPACE / 1024 / 1024))GB free space available. At least 4GB recommended."
    fi
    
    log_success "Prerequisites check completed"
}

# Create necessary directories
create_directories() {
    log_info "Creating directory structure..."
    
    # Create Docker volume directories
    mkdir -p "$PROJECT_ROOT/.docker-volumes"/{build-cache,pip-cache,cmake-cache,vscode-extensions,vscode-data}
    
    # Create config directories if they don't exist
    mkdir -p "$PROJECT_ROOT/config"
    
    # Set appropriate permissions
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        USER_UID=${USER_UID:-$(id -u)}
        USER_GID=${USER_GID:-$(id -g)}
        chown -R "$USER_UID:$USER_GID" "$PROJECT_ROOT/.docker-volumes" 2>/dev/null || true
    fi
    
    log_success "Directories created"
}

# Clean up existing containers and images
cleanup() {
    log_info "Cleaning up existing containers and images..."
    
    # Stop and remove container if it exists
    if docker ps -a --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
        log_info "Stopping and removing existing container..."
        docker stop "$CONTAINER_NAME" 2>/dev/null || true
        docker rm "$CONTAINER_NAME" 2>/dev/null || true
    fi
    
    # Remove image if force rebuild is requested
    if [ "$FORCE_REBUILD" = "true" ]; then
        if docker images --format '{{.Repository}}:{{.Tag}}' | grep -q "^${IMAGE_NAME}:${IMAGE_TAG}$"; then
            log_info "Removing existing image..."
            docker rmi "${IMAGE_NAME}:${IMAGE_TAG}" 2>/dev/null || true
        fi
    fi
    
    # Clean up dangling images and build cache
    log_info "Cleaning up Docker build cache..."
    docker builder prune -f &>/dev/null || true
    
    log_success "Cleanup completed"
}

# Build Docker image
build_image() {
    log_info "Building OASIS development environment..."
    
    cd "$PROJECT_ROOT"
    
    # Prepare build arguments
    BUILD_ARGS=""
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        USER_UID=${USER_UID:-$(id -u)}
        USER_GID=${USER_GID:-$(id -g)}
        BUILD_ARGS="--build-arg USER_UID=$USER_UID --build-arg USER_GID=$USER_GID"
    fi
    
    # Add no-cache flag if requested
    if [ "$NO_CACHE" = "true" ]; then
        BUILD_ARGS="$BUILD_ARGS --no-cache"
    fi
    
    # Build the image
    log_info "Running docker build (this may take several minutes)..."
    if docker build $BUILD_ARGS -t "${IMAGE_NAME}:${IMAGE_TAG}" -f Dockerfile . ; then
        log_success "Docker image built successfully"
    else
        log_error "Failed to build Docker image"
        exit 1
    fi
}

# Verify the installation
verify_installation() {
    log_info "Verifying installation..."
    
    # Test that the image exists and can run
    if docker run --rm "${IMAGE_NAME}:${IMAGE_TAG}" python3 --version > /dev/null; then
        log_success "Python installation verified"
    else
        log_error "Python verification failed"
        return 1
    fi
    
    # Test CMake
    if docker run --rm "${IMAGE_NAME}:${IMAGE_TAG}" cmake --version > /dev/null; then
        log_success "CMake installation verified"
    else
        log_error "CMake verification failed"
        return 1
    fi
    
    # Test SPICE installation
    if docker run --rm "${IMAGE_NAME}:${IMAGE_TAG}" test -f /opt/spice/cspice/lib/cspice.a; then
        log_success "NASA SPICE installation verified"
    else
        log_error "NASA SPICE verification failed"
        return 1
    fi
    
    log_success "Installation verification completed"
}

# Create sample configuration files
create_sample_configs() {
    log_info "Creating sample configuration files..."
    
    # VSCode settings
    if [ ! -f "$PROJECT_ROOT/config/vscode-settings.json" ]; then
        cat > "$PROJECT_ROOT/config/vscode-settings.json" << 'EOF'
{
    "cmake.configureOnOpen": true,
    "cmake.buildDirectory": "${workspaceFolder}/build",
    "cmake.generator": "Ninja",
    "cmake.buildTask": true,
    "C_Cpp.default.compileCommands": "${workspaceFolder}/build/compile_commands.json",
    "C_Cpp.default.cppStandard": "c++17",
    "python.defaultInterpreterPath": "/usr/bin/python3",
    "python.linting.enabled": true,
    "python.linting.pylintEnabled": false,
    "python.linting.flake8Enabled": true,
    "python.formatting.provider": "black",
    "files.associations": {
        "*.hpp": "cpp",
        "*.tpp": "cpp"
    }
}
EOF
        log_success "Created VSCode settings template"
    fi
    
    # CMake presets
    if [ ! -f "$PROJECT_ROOT/config/cmake-presets.json" ]; then
        cat > "$PROJECT_ROOT/config/cmake-presets.json" << 'EOF'
{
    "version": 3,
    "configurePresets": [
        {
            "name": "debug",
            "displayName": "Debug Configuration",
            "generator": "Ninja",
            "binaryDir": "${sourceDir}/build/debug",
            "cacheVariables": {
                "CMAKE_BUILD_TYPE": "Debug",
                "CMAKE_EXPORT_COMPILE_COMMANDS": "ON",
                "BUILD_TESTING": "ON"
            }
        },
        {
            "name": "release",
            "displayName": "Release Configuration",
            "generator": "Ninja",
            "binaryDir": "${sourceDir}/build/release",
            "cacheVariables": {
                "CMAKE_BUILD_TYPE": "Release",
                "CMAKE_EXPORT_COMPILE_COMMANDS": "ON",
                "BUILD_TESTING": "OFF"
            }
        }
    ],
    "buildPresets": [
        {
            "name": "debug",
            "configurePreset": "debug"
        },
        {
            "name": "release",
            "configurePreset": "release"
        }
    ]
}
EOF
        log_success "Created CMake presets template"
    fi
}

# Main execution
main() {
    # Parse command line arguments
    FORCE_REBUILD=false
    NO_CACHE=false
    CLEAN=false
    CHECK_ONLY=false
    USER_UID=""
    USER_GID=""
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_help
                exit 0
                ;;
            --force-rebuild)
                FORCE_REBUILD=true
                shift
                ;;
            --no-cache)
                NO_CACHE=true
                shift
                ;;
            --clean)
                CLEAN=true
                shift
                ;;
            --check-only)
                CHECK_ONLY=true
                shift
                ;;
            --user-uid)
                USER_UID="$2"
                shift 2
                ;;
            --user-gid)
                USER_GID="$2"
                shift 2
                ;;
            *)
                log_error "Unknown option: $1"
                show_help
                exit 1
                ;;
        esac
    done
    
    # Export user IDs for docker-compose
    export USER_UID USER_GID
    
    log_info "Starting OASIS build environment setup..."
    
    # Always check prerequisites
    check_prerequisites
    
    if [ "$CHECK_ONLY" = "true" ]; then
        log_success "Prerequisites check completed successfully"
        exit 0
    fi
    
    # Clean up if requested
    if [ "$CLEAN" = "true" ] || [ "$FORCE_REBUILD" = "true" ]; then
        cleanup
    fi
    
    # Create necessary directories
    create_directories
    
    # Build the Docker image
    build_image
    
    # Verify installation
    verify_installation
    
    # Create sample configuration files
    create_sample_configs
    
    log_success "OASIS build environment setup completed successfully!"
    log_info ""
    log_info "Next steps:"
    log_info "1. Clone the OASIS repository: git clone <oasis-repo-url>"
    log_info "2. Copy docker-compose.yml to your OASIS project directory"
    log_info "3. Run: docker-compose up -d"
    log_info "4. Connect to the container: docker-compose exec oasis-dev bash"
    log_info ""
    log_info "For development with VSCode:"
    log_info "1. Install the Dev Containers extension"
    log_info "2. Copy config/vscode-settings.json to your project's .vscode/ directory"
    log_info "3. Use 'Remote-Containers: Open Folder in Container'"
}

# Run main function
main "$@"