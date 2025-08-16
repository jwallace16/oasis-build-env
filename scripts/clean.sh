# scripts/clean.sh - Cleanup script
#!/bin/bash
# OASIS Cleanup Script
# Cleans build artifacts, containers, and temporary files

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[CLEAN]${NC} $1"; }
log_success() { echo -e "${GREEN}[CLEAN]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[CLEAN]${NC} $1"; }
log_error() { echo -e "${RED}[CLEAN]${NC} $1"; }

show_help() {
    cat << EOF
OASIS Cleanup Script

Usage: $0 [OPTIONS]

OPTIONS:
    --build-dir     Clean build directories only
    --containers    Clean Docker containers and images
    --cache         Clean build cache and temporary files
    --all           Clean everything (build + containers + cache)
    --force         Don't ask for confirmation
    -h, --help      Show this help

Examples:
    $0 --build-dir      # Clean only build artifacts
    $0 --containers     # Clean only Docker resources
    $0 --all            # Clean everything
    $0 --all --force    # Clean everything without confirmation

EOF
}

# Configuration
CLEAN_BUILD=false
CLEAN_CONTAINERS=false
CLEAN_CACHE=false
FORCE=false

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --build-dir)
            CLEAN_BUILD=true
            shift
            ;;
        --containers)
            CLEAN_CONTAINERS=true
            shift
            ;;
        --cache)
            CLEAN_CACHE=true
            shift
            ;;
        --all)
            CLEAN_BUILD=true
            CLEAN_CONTAINERS=true
            CLEAN_CACHE=true
            shift
            ;;
        --force)
            FORCE=true
            shift
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

# If no options specified, default to build directory cleanup
if [ "$CLEAN_BUILD" = false ] && [ "$CLEAN_CONTAINERS" = false ] && [ "$CLEAN_CACHE" = false ]; then
    CLEAN_BUILD=true
fi

# Confirmation
if [ "$FORCE" = false ]; then
    log_warning "This will clean up OASIS development files:"
    [ "$CLEAN_BUILD" = true ] && log_warning "  - Build directories and artifacts"
    [ "$CLEAN_CONTAINERS" = true ] && log_warning "  - Docker containers and images"
    [ "$CLEAN_CACHE" = true ] && log_warning "  - Cache files and temporary data"
    
    read -p "Continue? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log_info "Cleanup cancelled"
        exit 0
    fi
fi

log_info "Starting cleanup..."

# Clean build directories
if [ "$CLEAN_BUILD" = true ]; then
    log_info "Cleaning build directories..."
    
    if [ -d "build" ]; then
        rm -rf build/
        log_success "Removed build/ directory"
    fi
    
    # Clean Python build artifacts
    find . -name "*.pyc" -delete 2>/dev/null || true
    find . -name "__pycache__" -type d -exec rm -rf {} + 2>/dev/null || true
    find . -name "*.egg-info" -type d -exec rm -rf {} + 2>/dev/null || true
    
    log_success "Build directories cleaned"
fi

# Clean Docker containers and images
if [ "$CLEAN_CONTAINERS" = true ]; then
    log_info "Cleaning Docker resources..."
    
    # Stop and remove OASIS containers
    docker-compose down 2>/dev/null || true
    
    # Remove OASIS images
    if docker images --format '{{.Repository}}:{{.Tag}}' | grep -q "^oasis-dev:"; then
        docker images --format '{{.Repository}}:{{.Tag}}' | grep "^oasis-dev:" | xargs docker rmi 2>/dev/null || true
        log_success "Removed OASIS Docker images"
    fi
    
    # Clean up dangling images and build cache
    docker system prune -f &>/dev/null || true
    
    log_success "Docker resources cleaned"
fi

# Clean cache and temporary files
if [ "$CLEAN_CACHE" = true ]; then
    log_info "Cleaning cache and temporary files..."
    
    # Clean Docker volume directories
    if [ -d ".docker-volumes" ]; then
        rm -rf .docker-volumes/
        log_success "Removed Docker volume cache"
    fi
    
    # Clean CMake cache
    find . -name "CMakeCache.txt" -delete 2>/dev/null || true
    find . -name "CMakeFiles" -type d -exec rm -rf {} + 2>/dev/null || true
    
    # Clean other temporary files
    find . -name "*.tmp" -delete 2>/dev/null || true
    find . -name "*.log" -delete 2>/dev/null || true
    find . -name ".DS_Store" -delete 2>/dev/null || true
    
    log_success "Cache and temporary files cleaned"
fi

log_success "Cleanup completed!"

if [ "$CLEAN_CONTAINERS" = true ]; then
    log_info "To rebuild the development environment, run: ./scripts/setup.sh"
fi