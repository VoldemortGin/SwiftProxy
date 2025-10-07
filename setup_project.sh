#!/bin/bash

# SwiftProxy Project Setup Script
# This script creates the complete directory structure for SwiftProxy

set -e

PROJECT_ROOT="$(pwd)"
APP_NAME="SwiftProxy"

echo "=========================================="
echo "SwiftProxy Project Setup"
echo "=========================================="
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to create directory
create_dir() {
    if [ ! -d "$1" ]; then
        mkdir -p "$1"
        echo -e "${GREEN}✓${NC} Created: $1"
    else
        echo -e "${YELLOW}⚠${NC} Already exists: $1"
    fi
}

# Function to create file with content
create_file() {
    local file_path="$1"
    local content="$2"

    if [ ! -f "$file_path" ]; then
        echo "$content" > "$file_path"
        echo -e "${GREEN}✓${NC} Created: $file_path"
    else
        echo -e "${YELLOW}⚠${NC} Already exists: $file_path"
    fi
}

echo "Creating directory structure..."
echo ""

# Main App Structure
create_dir "$PROJECT_ROOT/$APP_NAME"
create_dir "$PROJECT_ROOT/$APP_NAME/App"
create_dir "$PROJECT_ROOT/$APP_NAME/Core/Extensions"
create_dir "$PROJECT_ROOT/$APP_NAME/Core/Protocols"
create_dir "$PROJECT_ROOT/$APP_NAME/Core/Utils"
create_dir "$PROJECT_ROOT/$APP_NAME/Core/Constants"

# Models
create_dir "$PROJECT_ROOT/$APP_NAME/Models/Domain"
create_dir "$PROJECT_ROOT/$APP_NAME/Models/DTO"
create_dir "$PROJECT_ROOT/$APP_NAME/Models/Enums"

# Services
create_dir "$PROJECT_ROOT/$APP_NAME/Services/ProxyService"
create_dir "$PROJECT_ROOT/$APP_NAME/Services/NetworkMonitor"
create_dir "$PROJECT_ROOT/$APP_NAME/Services/RuleEngine"
create_dir "$PROJECT_ROOT/$APP_NAME/Services/TrafficAnalyzer"
create_dir "$PROJECT_ROOT/$APP_NAME/Services/Storage"

# ViewModels
create_dir "$PROJECT_ROOT/$APP_NAME/ViewModels"

# Views
create_dir "$PROJECT_ROOT/$APP_NAME/Views/Dashboard"
create_dir "$PROJECT_ROOT/$APP_NAME/Views/Dashboard/Components"
create_dir "$PROJECT_ROOT/$APP_NAME/Views/ProxyControl"
create_dir "$PROJECT_ROOT/$APP_NAME/Views/ProxyControl/Components"
create_dir "$PROJECT_ROOT/$APP_NAME/Views/Monitor"
create_dir "$PROJECT_ROOT/$APP_NAME/Views/Monitor/Components"
create_dir "$PROJECT_ROOT/$APP_NAME/Views/Rules"
create_dir "$PROJECT_ROOT/$APP_NAME/Views/Rules/Components"
create_dir "$PROJECT_ROOT/$APP_NAME/Views/Statistics"
create_dir "$PROJECT_ROOT/$APP_NAME/Views/Statistics/Components"
create_dir "$PROJECT_ROOT/$APP_NAME/Views/Common"

# Resources
create_dir "$PROJECT_ROOT/$APP_NAME/Resources"
create_dir "$PROJECT_ROOT/$APP_NAME/Resources/Assets.xcassets"
create_dir "$PROJECT_ROOT/$APP_NAME/Supporting Files"

# Network Extension
create_dir "$PROJECT_ROOT/SwiftProxyExtension"

# Shared Core
create_dir "$PROJECT_ROOT/SwiftProxyCore/SharedModels"
create_dir "$PROJECT_ROOT/SwiftProxyCore/SharedProtocols"
create_dir "$PROJECT_ROOT/SwiftProxyCore/SharedUtils"

# Tests
create_dir "$PROJECT_ROOT/SwiftProxyTests/ServiceTests"
create_dir "$PROJECT_ROOT/SwiftProxyTests/ViewModelTests"
create_dir "$PROJECT_ROOT/SwiftProxyTests/ModelTests"

# UI Tests
create_dir "$PROJECT_ROOT/SwiftProxyUITests"

echo ""
echo "Creating placeholder files..."
echo ""

# Create .gitkeep files to preserve empty directories
find "$PROJECT_ROOT/$APP_NAME" -type d -empty -exec touch {}/.gitkeep \;
find "$PROJECT_ROOT/SwiftProxyExtension" -type d -empty -exec touch {}/.gitkeep \;
find "$PROJECT_ROOT/SwiftProxyCore" -type d -empty -exec touch {}/.gitkeep \;
find "$PROJECT_ROOT/SwiftProxyTests" -type d -empty -exec touch {}/.gitkeep \;

# Create .gitignore
create_file "$PROJECT_ROOT/.gitignore" "# Xcode
#
# gitignore contributors: remember to update Global/Xcode.gitignore, Objective-C.gitignore & Swift.gitignore

## User settings
xcuserdata/

## compatibility with Xcode 8 and earlier (ignoring not required starting Xcode 9)
*.xcscmblueprint
*.xccheckout

## compatibility with Xcode 3 and earlier (ignoring not required starting Xcode 4)
build/
DerivedData/
*.moved-aside
*.pbxuser
!default.pbxuser
*.mode1v3
!default.mode1v3
*.mode2v3
!default.mode2v3
*.perspectivev3
!default.perspectivev3

## Obj-C/Swift specific
*.hmap

## App packaging
*.ipa
*.dSYM.zip
*.dSYM

## Playgrounds
timeline.xctimeline
playground.xcworkspace

# Swift Package Manager
.build/
.swiftpm/

# CocoaPods
Pods/

# Carthage
Carthage/Build/

# Accio dependency management
Dependencies/
.accio/

# fastlane
fastlane/report.xml
fastlane/Preview.html
fastlane/screenshots/**/*.png
fastlane/test_output

# Code Injection
iOSInjectionProject/

# macOS
.DS_Store
.AppleDouble
.LSOverride

# Thumbnails
._*

# Files that might appear in the root of a volume
.DocumentRevisions-V100
.fseventsd
.Spotlight-V100
.TemporaryItems
.Trashes
.VolumeIcon.icns
.com.apple.timemachine.donotpresent

# Directories potentially created on remote AFP share
.AppleDB
.AppleDesktop
Network Trash Folder
Temporary Items
.apdisk
"

# Create README.md
create_file "$PROJECT_ROOT/README.md" "# SwiftProxy

A modern macOS native network proxy management application built with Swift and SwiftUI.

## Features

- System proxy control (HTTP, HTTPS, SOCKS5)
- Real-time network traffic monitoring
- Flexible proxy rules engine
- Traffic statistics and visualization
- Network Extension for advanced traffic interception

## Requirements

- macOS 14.0+
- Xcode 15.0+
- Swift 5.9+

## Architecture

SwiftProxy follows MVVM architecture pattern with clear separation of concerns:

- **Models**: Domain models and data structures
- **ViewModels**: Business logic and state management
- **Views**: SwiftUI views and components
- **Services**: Core business services (Proxy, Network Monitor, Rule Engine, etc.)
- **Network Extension**: Traffic interception and processing

## Setup

1. Open \`SwiftProxy.xcodeproj\` in Xcode
2. Configure your development team in project settings
3. Update App Group identifier in both main app and extension targets
4. Build and run

## Documentation

- [Architecture Design](ARCHITECTURE.md) - Complete architecture overview
- [Code Structure](CODE_STRUCTURE.md) - Core code implementations
- [Implementation Guide](IMPLEMENTATION_GUIDE.md) - Step-by-step implementation guide

## Testing

Run tests using:
\`\`\`bash
xcodebuild test -scheme SwiftProxy -destination 'platform=macOS'
\`\`\`

## License

Copyright © 2025. All rights reserved.

## Contributing

Contributions are welcome! Please read our contributing guidelines before submitting PRs.
"

# Create SwiftLint configuration
create_file "$PROJECT_ROOT/.swiftlint.yml" "disabled_rules:
  - trailing_whitespace
  - line_length

opt_in_rules:
  - empty_count
  - closure_spacing
  - force_unwrapping
  - explicit_init
  - explicit_type_interface

excluded:
  - Pods
  - SwiftProxyTests
  - SwiftProxyUITests
  - DerivedData

line_length:
  warning: 120
  error: 200

identifier_name:
  min_length:
    warning: 2
  max_length:
    warning: 40
    error: 50

type_name:
  min_length: 3
  max_length: 40

function_parameter_count:
  warning: 6
  error: 8

large_tuple:
  warning: 3
  error: 4

cyclomatic_complexity:
  warning: 10
  error: 20

file_length:
  warning: 500
  error: 1000

type_body_length:
  warning: 300
  error: 500

function_body_length:
  warning: 50
  error: 100
"

# Create Package.swift for dependencies
create_file "$PROJECT_ROOT/Package.swift" "// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: \"SwiftProxy\",
    platforms: [
        .macOS(.v14)
    ],
    dependencies: [
        // Add your dependencies here
        // Example:
        // .package(url: \"https://github.com/Alamofire/Alamofire.git\", from: \"5.8.0\")
    ],
    targets: [
        .target(
            name: \"SwiftProxy\",
            dependencies: []
        ),
        .testTarget(
            name: \"SwiftProxyTests\",
            dependencies: [\"SwiftProxy\"]
        )
    ]
)
"

# Create CHANGELOG.md
create_file "$PROJECT_ROOT/CHANGELOG.md" "# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- Initial project structure
- Core architecture design
- MVVM pattern implementation
- Network Extension support

### Changed

### Deprecated

### Removed

### Fixed

### Security

## [0.1.0] - $(date +%Y-%m-%d)

### Added
- Project initialization
- Basic directory structure
- Architecture documentation
"

# Create placeholder Info.plist files
create_file "$PROJECT_ROOT/$APP_NAME/Resources/Info.plist" "<?xml version=\"1.0\" encoding=\"UTF-8\"?>
<!DOCTYPE plist PUBLIC \"-//Apple//DTD PLIST 1.0//EN\" \"http://www.apple.com/DTDs/PropertyList-1.0.dtd\">
<plist version=\"1.0\">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>\$(DEVELOPMENT_LANGUAGE)</string>
    <key>CFBundleExecutable</key>
    <string>\$(EXECUTABLE_NAME)</string>
    <key>CFBundleIdentifier</key>
    <string>\$(PRODUCT_BUNDLE_IDENTIFIER)</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>\$(PRODUCT_NAME)</string>
    <key>CFBundlePackageType</key>
    <string>\$(PRODUCT_BUNDLE_PACKAGE_TYPE)</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>\$(MACOSX_DEPLOYMENT_TARGET)</string>
    <key>NSHumanReadableCopyright</key>
    <string>Copyright © 2025. All rights reserved.</string>
    <key>NSMainStoryboardFile</key>
    <string>Main</string>
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
</dict>
</plist>
"

# Create placeholder entitlements
create_file "$PROJECT_ROOT/$APP_NAME/Supporting Files/$APP_NAME.entitlements" "<?xml version=\"1.0\" encoding=\"UTF-8\"?>
<!DOCTYPE plist PUBLIC \"-//Apple//DTD PLIST 1.0//EN\" \"http://www.apple.com/DTDs/PropertyList-1.0.dtd\">
<plist version=\"1.0\">
<dict>
    <key>com.apple.security.app-sandbox</key>
    <true/>
    <key>com.apple.security.network.client</key>
    <true/>
    <key>com.apple.security.network.server</key>
    <true/>
    <key>com.apple.security.application-groups</key>
    <array>
        <string>group.com.yourcompany.swiftproxy</string>
    </array>
    <key>com.apple.security.files.user-selected.read-write</key>
    <true/>
</dict>
</plist>
"

echo ""
echo "=========================================="
echo -e "${GREEN}Project structure created successfully!${NC}"
echo "=========================================="
echo ""
echo "Next steps:"
echo "1. Create Xcode project:"
echo "   - Open Xcode"
echo "   - File -> New -> Project -> macOS -> App"
echo "   - Use existing project directory"
echo ""
echo "2. Configure targets:"
echo "   - Add Network Extension target"
echo "   - Set up signing & capabilities"
echo "   - Configure App Groups"
echo ""
echo "3. Start development:"
echo "   - Review ARCHITECTURE.md for design overview"
echo "   - Check CODE_STRUCTURE.md for implementation details"
echo "   - Follow IMPLEMENTATION_GUIDE.md for step-by-step guide"
echo ""
echo "=========================================="
echo ""

# Create a quick reference file
create_file "$PROJECT_ROOT/QUICK_START.md" "# Quick Start Guide

## Initial Setup

1. **Create Xcode Project**
   \`\`\`bash
   # The directory structure is already created
   # Now create the Xcode project in this directory
   # File -> New -> Project -> macOS -> App
   # Choose 'SwiftProxy' as the product name
   \`\`\`

2. **Add Network Extension Target**
   \`\`\`
   File -> New -> Target -> Network Extension
   Product Name: SwiftProxyExtension
   Type: Packet Tunnel
   \`\`\`

3. **Configure Capabilities**

   **Main App:**
   - App Sandbox ✓
   - Network (Client) ✓
   - Network (Server) ✓
   - App Groups ✓ (group.com.yourcompany.swiftproxy)

   **Extension:**
   - App Sandbox ✓
   - Network Extension ✓
   - App Groups ✓ (group.com.yourcompany.swiftproxy)

4. **Set Deployment Target**
   - macOS 14.0 or later
   - Swift 5.9 or later

## Development Phases

### Phase 1: Core Infrastructure (Week 1-2)
- [ ] Set up project structure
- [ ] Implement DependencyContainer
- [ ] Create core protocols
- [ ] Implement data models
- [ ] Set up StorageService
- [ ] Add logging system

### Phase 2: Proxy Service (Week 3-4)
- [ ] Implement ProxyService
- [ ] System proxy configuration
- [ ] Connection testing
- [ ] Configuration management
- [ ] Create ProxyControlView

### Phase 3: Network Monitoring (Week 5-6)
- [ ] Implement NetworkMonitorService
- [ ] Set up Network Extension
- [ ] Packet interception
- [ ] Real-time monitoring
- [ ] Create MonitorView

### Phase 4: Rule Engine (Week 7-8)
- [ ] Implement RuleEngineService
- [ ] Rule matching algorithm
- [ ] Import/Export functionality
- [ ] Preset rules
- [ ] Create RulesView

### Phase 5: Statistics (Week 9-10)
- [ ] Implement TrafficAnalyzerService
- [ ] Real-time statistics
- [ ] Historical analysis
- [ ] Chart generation
- [ ] Create StatisticsView

### Phase 6: Dashboard (Week 11-12)
- [ ] Implement DashboardViewModel
- [ ] Create Dashboard UI
- [ ] Module integration
- [ ] Menu bar icon
- [ ] System tray

### Phase 7: Testing (Week 13-14)
- [ ] Unit tests (80%+ coverage)
- [ ] UI tests
- [ ] Performance optimization
- [ ] Bug fixes

### Phase 8: Release (Week 15-16)
- [ ] Code signing
- [ ] Notarization
- [ ] Documentation
- [ ] Beta testing
- [ ] Official release

## Useful Commands

### Build and Run
\`\`\`bash
xcodebuild -scheme SwiftProxy -configuration Debug
\`\`\`

### Run Tests
\`\`\`bash
xcodebuild test -scheme SwiftProxy -destination 'platform=macOS'
\`\`\`

### SwiftLint
\`\`\`bash
swiftlint
\`\`\`

### Clean Build
\`\`\`bash
xcodebuild clean -scheme SwiftProxy
\`\`\`

## Resources

- **Architecture**: See \`ARCHITECTURE.md\`
- **Code Examples**: See \`CODE_STRUCTURE.md\`
- **Implementation Guide**: See \`IMPLEMENTATION_GUIDE.md\`

## Support

For questions or issues, please check the documentation files or create an issue in the repository.
"

echo -e "${GREEN}Setup complete! Check QUICK_START.md for next steps.${NC}"
echo ""
