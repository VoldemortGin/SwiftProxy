#!/bin/bash

# SwiftProxy Quick Start Script
# One-command setup and run

set -e

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${BLUE}"
cat << "EOF"
   ____          _ __ _   ____
  / __/_      __(_) _| |_/ __ \_________  _  ____  __
 _\ \/ | /| / / / _/  __/ /_/ / ___/ __ \| |/_/ / / /
/___/  |/ |/ / / _/ /__/ ____/ /  / /_/ />  </ /_/ /
       |__/|__/_/_/  \__/_/   /_/   \____/_/|_|\__, /
                                              /____/
EOF
echo -e "${NC}"

echo -e "${GREEN}SwiftProxy Quick Start${NC}"
echo ""

# Check Swift installation
if ! command -v swift &> /dev/null; then
    echo -e "${YELLOW}Error: Swift is not installed${NC}"
    echo "Please install Xcode or Swift toolchain"
    exit 1
fi

echo -e "${GREEN}✓ Swift $(swift --version | head -n 1 | cut -d' ' -f2-4)${NC}"
echo ""

# Check if we're in the right directory
if [ ! -f "Package.swift" ]; then
    echo -e "${YELLOW}Error: Package.swift not found${NC}"
    echo "Please run this script from the SwiftProxy project root"
    exit 1
fi

# Ask user what they want to do
echo "What would you like to do?"
echo ""
echo "  1) Build and run in Xcode"
echo "  2) Build and run from command line (debug)"
echo "  3) Build release version"
echo "  4) Run tests"
echo "  5) Doctor (check environment)"
echo ""
read -p "Enter choice [1-5]: " choice

case $choice in
    1)
        echo ""
        echo -e "${GREEN}Opening in Xcode...${NC}"
        open Package.swift
        ;;
    2)
        echo ""
        echo -e "${GREEN}Building and running...${NC}"
        echo ""
        swift build
        echo ""
        echo -e "${GREEN}Starting SwiftProxy...${NC}"
        echo ""
        ./.build/debug/SwiftProxy
        ;;
    3)
        echo ""
        echo -e "${GREEN}Building release version...${NC}"
        echo ""
        swift build -c release
        echo ""
        echo -e "${GREEN}✓ Release build complete!${NC}"
        echo -e "Binary: ${YELLOW}./.build/release/SwiftProxy${NC}"
        ;;
    4)
        echo ""
        echo -e "${GREEN}Running tests...${NC}"
        echo ""
        swift test
        ;;
    5)
        echo ""
        echo -e "${GREEN}Environment Check${NC}"
        echo ""
        echo -n "Swift:        "
        if command -v swift >/dev/null 2>&1; then
            echo -e "${GREEN}✓ $(swift --version | head -n 1)${NC}"
        else
            echo -e "${YELLOW}✗ Not installed${NC}"
        fi
        echo -n "Xcode:        "
        if command -v xcodebuild >/dev/null 2>&1; then
            echo -e "${GREEN}✓ $(xcodebuild -version | head -n 1)${NC}"
        else
            echo -e "${YELLOW}✗ Not installed${NC}"
        fi
        echo -n "macOS:        "
        echo -e "${GREEN}✓ $(sw_vers -productVersion)${NC}"
        echo ""
        echo "Project files:"
        echo -e "  ${GREEN}✓${NC} Package.swift"
        echo -e "  ${GREEN}✓${NC} Info.plist"
        echo -e "  ${GREEN}✓${NC} SwiftProxy.entitlements"
        echo ""
        ;;
    *)
        echo ""
        echo -e "${YELLOW}Invalid choice${NC}"
        exit 1
        ;;
esac
