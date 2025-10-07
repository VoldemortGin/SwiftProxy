#!/bin/bash

# SwiftProxy Configuration Validation Script
# Validates all project configuration files and build setup

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd "$SCRIPT_DIR"

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  SwiftProxy Configuration Validator${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Track validation results
PASSED=0
FAILED=0
WARNINGS=0

# Function to print results
print_pass() {
    echo -e "${GREEN}[✓]${NC} $1"
    ((PASSED++))
}

print_fail() {
    echo -e "${RED}[✗]${NC} $1"
    ((FAILED++))
}

print_warn() {
    echo -e "${YELLOW}[⚠]${NC} $1"
    ((WARNINGS++))
}

print_info() {
    echo -e "${BLUE}[ℹ]${NC} $1"
}

# 1. Check required files
echo -e "${BLUE}1. Checking Required Configuration Files${NC}"
echo ""

FILES=(
    "Package.swift"
    "Info.plist"
    "SwiftProxy.entitlements"
    ".gitignore"
    "build_and_run.sh"
    "quick_start.sh"
    "Makefile"
    "README_RUN.md"
)

for file in "${FILES[@]}"; do
    if [ -f "$file" ]; then
        print_pass "$file exists"
    else
        print_fail "$file is missing"
    fi
done

echo ""

# 2. Check source directories
echo -e "${BLUE}2. Checking Source Directories${NC}"
echo ""

DIRS=(
    "SwiftProxy"
    "SwiftProxy/Core"
    "SwiftProxy/UI"
    "SwiftProxyTests"
)

for dir in "${DIRS[@]}"; do
    if [ -d "$dir" ]; then
        print_pass "$dir directory exists"
    else
        print_fail "$dir directory is missing"
    fi
done

echo ""

# 3. Validate Package.swift
echo -e "${BLUE}3. Validating Package.swift${NC}"
echo ""

if swift package dump-package > /dev/null 2>&1; then
    print_pass "Package.swift is valid"
else
    print_fail "Package.swift has errors"
fi

# Check package name
if grep -q 'name: "SwiftProxy"' Package.swift; then
    print_pass "Package name is correct"
else
    print_fail "Package name is incorrect"
fi

# Check platform
if grep -q 'macOS(.v13)' Package.swift; then
    print_pass "Platform requirement is correct (macOS 13.0+)"
else
    print_fail "Platform requirement is missing or incorrect"
fi

echo ""

# 4. Validate Info.plist
echo -e "${BLUE}4. Validating Info.plist${NC}"
echo ""

if [ -f "Info.plist" ]; then
    # Check if it's valid XML
    if plutil -lint Info.plist > /dev/null 2>&1; then
        print_pass "Info.plist is valid XML"
    else
        print_fail "Info.plist has XML errors"
    fi

    # Check Bundle ID
    if grep -q 'com.swiftproxy.app' Info.plist; then
        print_pass "Bundle ID is configured"
    else
        print_fail "Bundle ID is missing"
    fi

    # Check minimum system version
    if grep -q '13.0' Info.plist; then
        print_pass "Minimum system version is set"
    else
        print_warn "Minimum system version may not be set"
    fi
fi

echo ""

# 5. Validate Entitlements
echo -e "${BLUE}5. Validating SwiftProxy.entitlements${NC}"
echo ""

if [ -f "SwiftProxy.entitlements" ]; then
    # Check if it's valid XML
    if plutil -lint SwiftProxy.entitlements > /dev/null 2>&1; then
        print_pass "Entitlements file is valid XML"
    else
        print_fail "Entitlements file has XML errors"
    fi

    # Check for required entitlements
    REQUIRED_ENTITLEMENTS=(
        "com.apple.security.app-sandbox"
        "com.apple.security.network.client"
        "com.apple.security.network.server"
    )

    for entitlement in "${REQUIRED_ENTITLEMENTS[@]}"; do
        if grep -q "$entitlement" SwiftProxy.entitlements; then
            print_pass "Entitlement: $entitlement"
        else
            print_fail "Missing entitlement: $entitlement"
        fi
    done
fi

echo ""

# 6. Check executable permissions
echo -e "${BLUE}6. Checking Script Permissions${NC}"
echo ""

SCRIPTS=(
    "build_and_run.sh"
    "quick_start.sh"
    "run_tests.sh"
    "validate_config.sh"
)

for script in "${SCRIPTS[@]}"; do
    if [ -f "$script" ]; then
        if [ -x "$script" ]; then
            print_pass "$script is executable"
        else
            print_warn "$script is not executable (run: chmod +x $script)"
        fi
    fi
done

echo ""

# 7. Check Swift environment
echo -e "${BLUE}7. Checking Swift Environment${NC}"
echo ""

if command -v swift &> /dev/null; then
    SWIFT_VERSION=$(swift --version | head -n 1)
    print_pass "Swift is installed: $SWIFT_VERSION"

    # Check Swift version
    if swift --version | grep -q "version 5.9" || swift --version | grep -q "version 5.1"; then
        print_pass "Swift version is 5.9 or later"
    else
        print_warn "Swift version may be older than 5.9"
    fi
else
    print_fail "Swift is not installed"
fi

if command -v xcodebuild &> /dev/null; then
    XCODE_VERSION=$(xcodebuild -version | head -n 1)
    print_pass "Xcode is installed: $XCODE_VERSION"
else
    print_warn "Xcode is not installed (optional but recommended)"
fi

echo ""

# 8. Check project structure
echo -e "${BLUE}8. Checking Project Structure${NC}"
echo ""

# Check for main entry point
if [ -f "SwiftProxy/SwiftProxyApp.swift" ]; then
    print_pass "Main entry point exists (SwiftProxyApp.swift)"
else
    print_fail "Main entry point is missing"
fi

# Check for core modules
CORE_MODULES=(
    "SwiftProxy/Core/NetworkEngine"
    "SwiftProxy/Core/Models"
    "SwiftProxy/Core/Services"
    "SwiftProxy/Core/Utils"
)

for module in "${CORE_MODULES[@]}"; do
    if [ -d "$module" ]; then
        FILE_COUNT=$(find "$module" -name "*.swift" | wc -l)
        print_pass "$module exists ($FILE_COUNT Swift files)"
    else
        print_warn "$module directory not found"
    fi
done

echo ""

# 9. Try a test build (optional)
echo -e "${BLUE}9. Build Configuration Test${NC}"
echo ""

print_info "Testing Package resolution..."
if swift package resolve > /dev/null 2>&1; then
    print_pass "Package dependencies resolve successfully"
else
    print_fail "Package resolution failed"
fi

echo ""

# 10. Summary
echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  Validation Summary${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

echo -e "${GREEN}Passed:${NC}   $PASSED"
echo -e "${YELLOW}Warnings:${NC} $WARNINGS"
echo -e "${RED}Failed:${NC}   $FAILED"
echo ""

if [ $FAILED -eq 0 ]; then
    echo -e "${GREEN}✓ All critical validations passed!${NC}"
    echo ""
    echo "You can now:"
    echo "  1. Build and run:     ./build_and_run.sh"
    echo "  2. Quick start:       ./quick_start.sh"
    echo "  3. Use Make:          make run"
    echo "  4. Open in Xcode:     make xcode"
    echo ""
    exit 0
else
    echo -e "${RED}✗ Some validations failed. Please fix the issues above.${NC}"
    echo ""
    exit 1
fi
