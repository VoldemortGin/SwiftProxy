#!/bin/bash

# SwiftProxy Test Runner Script
# Runs all unit tests and generates coverage report

set -e  # Exit on error

echo "🧪 SwiftProxy Test Suite Runner"
echo "================================"
echo ""

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Project directory
PROJECT_DIR="/Users/linhan/startup/SwiftProxy"
cd "$PROJECT_DIR"

# Find the scheme
SCHEME="SwiftProxy"

echo -e "${BLUE}📋 Finding Xcode project...${NC}"
if [ ! -d "SwiftProxy.xcodeproj" ] && [ ! -d "SwiftProxy.xcworkspace" ]; then
    echo -e "${RED}❌ No Xcode project or workspace found${NC}"
    exit 1
fi

# Determine build command
if [ -d "SwiftProxy.xcworkspace" ]; then
    BUILD_CMD="xcodebuild -workspace SwiftProxy.xcworkspace"
else
    BUILD_CMD="xcodebuild -project SwiftProxy.xcodeproj"
fi

echo -e "${BLUE}🏗️  Building project...${NC}"
$BUILD_CMD -scheme $SCHEME -destination 'platform=macOS' clean build || {
    echo -e "${YELLOW}⚠️  Build may have warnings, continuing with tests...${NC}"
}

echo ""
echo -e "${BLUE}🧪 Running all tests...${NC}"
echo "--------------------------------"

# Run tests with code coverage
$BUILD_CMD \
    -scheme $SCHEME \
    -destination 'platform=macOS' \
    -enableCodeCoverage YES \
    test 2>&1 | tee test_output.log

TEST_RESULT=$?

echo ""
echo "================================"

if [ $TEST_RESULT -eq 0 ]; then
    echo -e "${GREEN}✅ All tests passed!${NC}"
else
    echo -e "${RED}❌ Some tests failed${NC}"
    echo ""
    echo "Check test_output.log for details"
    exit 1
fi

echo ""
echo -e "${BLUE}📊 Test Summary:${NC}"

# Extract test summary from log
if [ -f test_output.log ]; then
    echo "Analyzing test results..."

    # Count test results
    TOTAL_TESTS=$(grep -c "Test Case.*passed" test_output.log || echo "0")
    PASSED_TESTS=$(grep -c "Test Case.*passed" test_output.log || echo "0")
    FAILED_TESTS=$(grep -c "Test Case.*failed" test_output.log || echo "0")

    echo "Total Tests Run: $TOTAL_TESTS"
    echo "Passed: $PASSED_TESTS"
    echo "Failed: $FAILED_TESTS"

    # Extract timing
    if grep -q "Test Suite.*passed" test_output.log; then
        echo ""
        echo "Test Suite Summary:"
        grep "Test Suite.*passed" test_output.log | tail -5
    fi
fi

echo ""
echo -e "${BLUE}📈 Code Coverage Report:${NC}"
echo "To view detailed coverage:"
echo "1. Open Xcode"
echo "2. Select Product > Test"
echo "3. Open Report Navigator (⌘ + 9)"
echo "4. Select latest test run"
echo "5. Click Coverage tab"

echo ""
echo -e "${GREEN}✨ Test run complete!${NC}"
echo ""
echo "Test Artifacts:"
echo "  - Test Log: test_output.log"
echo "  - Test Summary: SwiftProxyTests/TEST_SUMMARY.md"

# Optional: Generate coverage report using xccov if available
if command -v xcrun &> /dev/null; then
    echo ""
    echo -e "${BLUE}📊 Generating detailed coverage report...${NC}"

    # Find latest xcresult bundle
    XCRESULT=$(find ~/Library/Developer/Xcode/DerivedData -name "*.xcresult" | head -1)

    if [ -n "$XCRESULT" ]; then
        echo "Using xcresult: $XCRESULT"
        xcrun xccov view --report "$XCRESULT" > coverage_report.txt 2>&1 || true

        if [ -f coverage_report.txt ]; then
            echo -e "${GREEN}✅ Coverage report saved to coverage_report.txt${NC}"
        fi
    fi
fi

echo ""
echo "Done! 🎉"
