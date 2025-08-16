# scripts/build.sh - Build automation script
#!/bin/bash
# OASIS Build Script
# Automates the build process for different configurations

set -e

# Configuration
BUILD_TYPE=${1:-Debug}
CLEAN_BUILD=false
BUILD_TESTS=true
PARALLEL_JOBS=${CMAKE_BUILD_PARALLEL_LEVEL:-$(nproc)}

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[BUILD]${NC} $1"; }
log_success() { echo -e "${GREEN}[BUILD]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[BUILD]${NC} $1"; }
log_error() { echo -e "${RED}[BUILD]${NC} $1"; }

show_help() {
    cat << EOF
OASIS Build Script

Usage: $0 [BUILD_TYPE] [OPTIONS]

BUILD_TYPE:
    debug       Debug build with symbols (default)
    release     Optimized release build
    relwithdebinfo Release with debug symbols
    minsizerel  Minimum size release

OPTIONS:
    --clean     Clean build directory before building
    --no-tests  Skip building tests
    --jobs N    Number of parallel build jobs (default: $(nproc))
    -h, --help  Show this help

Examples:
    $0                    # Debug build
    $0 release            # Release build
    $0 debug --clean      # Clean debug build
    $0 release --no-tests # Release without tests

EOF
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        debug|release|relwithdebinfo|minsizerel)
            BUILD_TYPE=$1
            shift
            ;;
        --clean)
            CLEAN_BUILD=true
            shift
            ;;
        --no-tests)
            BUILD_TESTS=false
            shift
            ;;
        --jobs)
            PARALLEL_JOBS="$2"
            shift 2
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        *)
            log_error "Unknown option: $1"
            show_help
            exit 1
            ;;
    esac
done

# Validate build type
case $BUILD_TYPE in
    debug|Debug)
        CMAKE_BUILD_TYPE=Debug
        ;;
    release|Release)
        CMAKE_BUILD_TYPE=Release
        ;;
    relwithdebinfo|RelWithDebInfo)
        CMAKE_BUILD_TYPE=RelWithDebInfo
        ;;
    minsizerel|MinSizeRel)
        CMAKE_BUILD_TYPE=MinSizeRel
        ;;
    *)
        log_error "Invalid build type: $BUILD_TYPE"
        exit 1
        ;;
esac

BUILD_DIR="build/${CMAKE_BUILD_TYPE,,}"

log_info "Starting OASIS build..."
log_info "Build type: $CMAKE_BUILD_TYPE"
log_info "Build directory: $BUILD_DIR"
log_info "Parallel jobs: $PARALLEL_JOBS"

# Clean build directory if requested
if [ "$CLEAN_BUILD" = true ]; then
    log_info "Cleaning build directory..."
    rm -rf "$BUILD_DIR"
fi

# Create build directory
mkdir -p "$BUILD_DIR"
cd "$BUILD_DIR"

# Configure with CMake
log_info "Configuring with CMake..."
cmake ../.. \
    -DCMAKE_BUILD_TYPE="$CMAKE_BUILD_TYPE" \
    -DCMAKE_EXPORT_COMPILE_COMMANDS=ON \
    -DBUILD_PYTHON_BINDINGS=ON \
    -DBUILD_TESTS="$BUILD_TESTS" \
    -DBUILD_EXAMPLES=ON \
    -GNinja

# Build
log_info "Building OASIS..."
cmake --build . --parallel "$PARALLEL_JOBS"

log_success "Build completed successfully!"
log_info "Build artifacts are in: $BUILD_DIR"

if [ "$BUILD_TESTS" = true ]; then
    log_info "Tests built. Run './scripts/test.sh' to execute them."
fi