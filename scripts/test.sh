# scripts/test.sh - Test runner script
#!/bin/bash
# OASIS Test Runner
# Runs C++ and Python tests with coverage reporting

set -e

# Configuration
BUILD_TYPE=${1:-Debug}
RUN_CPP_TESTS=true
RUN_PYTHON_TESTS=true
GENERATE_COVERAGE=false
VERBOSE=false

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[TEST]${NC} $1"; }
log_success() { echo -e "${GREEN}[TEST]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[TEST]${NC} $1"; }
log_error() { echo -e "${RED}[TEST]${NC} $1"; }

show_help() {
    cat << EOF
OASIS Test Runner

Usage: $0 [BUILD_TYPE] [OPTIONS]

BUILD_TYPE:
    debug       Run tests from debug build (default)
    release     Run tests from release build

OPTIONS:
    --cpp-only      Run only C++ tests
    --python-only   Run only Python tests
    --coverage      Generate coverage reports
    --verbose       Verbose test output
    -h, --help      Show this help

Examples:
    $0                      # Run all tests (debug)
    $0 release              # Run all tests (release)
    $0 --cpp-only           # Run only C++ tests
    $0 --coverage           # Run tests with coverage

EOF
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        debug|release|relwithdebinfo|minsizerel)
            BUILD_TYPE=$1
            shift
            ;;
        --cpp-only)
            RUN_PYTHON_TESTS=false
            shift
            ;;
        --python-only)
            RUN_CPP_TESTS=false
            shift
            ;;
        --coverage)
            GENERATE_COVERAGE=true
            shift
            ;;
        --verbose)
            VERBOSE=true
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

# Normalize build type
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
esac

BUILD_DIR="build/${CMAKE_BUILD_TYPE,,}"

log_info "Running OASIS tests..."
log_info "Build type: $CMAKE_BUILD_TYPE"
log_info "Build directory: $BUILD_DIR"

# Check if build directory exists
if [ ! -d "$BUILD_DIR" ]; then
    log_error "Build directory $BUILD_DIR does not exist. Run build.sh first."
    exit 1
fi

# Test results tracking
CPP_TEST_RESULT=0
PYTHON_TEST_RESULT=0

# Run C++ tests
if [ "$RUN_CPP_TESTS" = true ]; then
    log_info "Running C++ tests..."
    
    cd "$BUILD_DIR"
    
    if [ "$VERBOSE" = true ]; then
        CTEST_ARGS="--verbose --output-on-failure"
    else
        CTEST_ARGS="--output-on-failure"
    fi
    
    if ctest $CTEST_ARGS; then
        log_success "C++ tests passed"
    else
        CPP_TEST_RESULT=1
        log_error "C++ tests failed"
    fi
    
    cd - > /dev/null
fi

# Run Python tests
if [ "$RUN_PYTHON_TESTS" = true ]; then
    log_info "Running Python tests..."
    
    # Check if Python tests exist
    if [ -d "tests/python" ]; then
        PYTEST_ARGS=""
        
        if [ "$VERBOSE" = true ]; then
            PYTEST_ARGS="$PYTEST_ARGS -v"
        fi
        
        if [ "$GENERATE_COVERAGE" = true ]; then
            PYTEST_ARGS="$PYTEST_ARGS --cov=oasis --cov-report=html --cov-report=term"
        fi
        
        cd tests/python
        
        if python -m pytest $PYTEST_ARGS; then
            log_success "Python tests passed"
        else
            PYTHON_TEST_RESULT=1
            log_error "Python tests failed"
        fi
        
        cd - > /dev/null
    else
        log_warning "Python tests directory not found, skipping Python tests"
    fi
fi

# Generate coverage report for C++
if [ "$GENERATE_COVERAGE" = true ] && [ "$RUN_CPP_TESTS" = true ]; then
    log_info "Generating C++ coverage report..."
    
    if command -v gcov &> /dev/null && command -v lcov &> /dev/null; then
        cd "$BUILD_DIR"
        
        # Generate coverage data
        lcov --capture --directory . --output-file coverage.info
        lcov --remove coverage.info '/usr/*' '*/third_party/*' '*/tests/*' --output-file coverage_filtered.info
        
        # Generate HTML report
        genhtml coverage_filtered.info --output-directory coverage_html
        
        log_success "C++ coverage report generated in $BUILD_DIR/coverage_html"
        cd - > /dev/null
    else
        log_warning "lcov/gcov not available, skipping C++ coverage report"
    fi
fi

# Summary
log_info "Test summary:"
if [ "$RUN_CPP_TESTS" = true ]; then
    if [ $CPP_TEST_RESULT -eq 0 ]; then
        log_success "  C++ tests: PASSED"
    else
        log_error "  C++ tests: FAILED"
    fi
fi

if [ "$RUN_PYTHON_TESTS" = true ]; then
    if [ $PYTHON_TEST_RESULT -eq 0 ]; then
        log_success "  Python tests: PASSED"
    else
        log_error "  Python tests: FAILED"
    fi
fi

# Exit with error if any tests failed
OVERALL_RESULT=$((CPP_TEST_RESULT + PYTHON_TEST_RESULT))
if [ $OVERALL_RESULT -eq 0 ]; then
    log_success "All tests passed!"
    exit 0
else
    log_error "Some tests failed!"
    exit 1
fi