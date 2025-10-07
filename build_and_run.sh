#!/bin/bash

# SwiftProxy Build and Run Script
# This script builds and runs the SwiftProxy application

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Script directory
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  SwiftProxy Build and Run Script${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Function to print colored output
print_status() {
    echo -e "${GREEN}[✓]${NC} $1"
}

print_error() {
    echo -e "${RED}[✗]${NC} $1"
}

print_info() {
    echo -e "${YELLOW}[ℹ]${NC} $1"
}

# Check if Swift is installed
if ! command -v swift &> /dev/null; then
    print_error "Swift is not installed. Please install Xcode or Swift toolchain."
    exit 1
fi

print_status "Swift $(swift --version | head -n 1)"

# Navigate to project directory
cd "$SCRIPT_DIR"

# Parse command line arguments
BUILD_TYPE="debug"
RUN_AFTER_BUILD=true
CLEAN_BUILD=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --release)
            BUILD_TYPE="release"
            shift
            ;;
        --no-run)
            RUN_AFTER_BUILD=false
            shift
            ;;
        --clean)
            CLEAN_BUILD=true
            shift
            ;;
        --help)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --release     Build in release mode (default: debug)"
            echo "  --no-run      Build only, do not run"
            echo "  --clean       Clean build directory before building"
            echo "  --help        Show this help message"
            exit 0
            ;;
        *)
            print_error "Unknown option: $1"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

# Clean build if requested
if [ "$CLEAN_BUILD" = true ]; then
    print_info "Cleaning build directory..."
    swift package clean
    rm -rf .build
    print_status "Clean complete"
fi

# Build the project
echo ""
print_info "Building SwiftProxy in $BUILD_TYPE mode..."
echo ""

if [ "$BUILD_TYPE" = "release" ]; then
    swift build -c release
    BUILD_PATH=".build/release/SwiftProxy"
else
    swift build
    BUILD_PATH=".build/debug/SwiftProxy"
fi

if [ $? -eq 0 ]; then
    echo ""
    print_status "Build successful!"

    # Run if requested
    if [ "$RUN_AFTER_BUILD" = true ]; then
        echo ""
        print_info "Starting SwiftProxy..."
        echo -e "${BLUE}========================================${NC}"
        echo ""

        "$BUILD_PATH"
    else
        echo ""
        print_info "Build complete. To run the app, execute:"
        echo -e "  ${YELLOW}$BUILD_PATH${NC}"
    fi
else
    echo ""
    print_error "Build failed!"
    exit 1
fi
