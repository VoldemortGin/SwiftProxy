# SwiftProxy - Build and Run Guide

This document provides instructions for building and running the SwiftProxy application.

## System Requirements

- **macOS**: 13.0 (Ventura) or later
- **Xcode**: 15.0 or later (includes Swift 5.9+)
- **Swift**: 5.9 or later
- **Architecture**: Apple Silicon (ARM64) or Intel (x86_64)

## Project Structure

```
SwiftProxy/
├── Package.swift                    # Swift Package Manager configuration
├── Info.plist                       # Application information
├── SwiftProxy.entitlements          # Application entitlements
├── build_and_run.sh                 # Build and run script
├── SwiftProxy/                      # Main source code
│   ├── SwiftProxyApp.swift         # Application entry point
│   ├── Core/                       # Core functionality
│   │   ├── NetworkEngine/          # Network engine
│   │   ├── Models/                 # Data models
│   │   ├── Services/               # Services
│   │   ├── Protocols/              # Protocols
│   │   ├── Errors/                 # Error types
│   │   └── Utils/                  # Utilities
│   ├── UI/                         # User interface
│   │   ├── Views/                  # SwiftUI views
│   │   ├── Components/             # Reusable components
│   │   └── ViewModels/             # View models
│   └── ViewModels/                 # Additional view models
├── SwiftProxyTests/                # Unit tests
└── SwiftProxyIntegrationTests/     # Integration tests
```

## Build Methods

### Method 1: Using Xcode (Recommended for Development)

1. **Open the Project**
   ```bash
   cd /path/to/SwiftProxy
   open Package.swift
   ```
   This will open the project in Xcode.

2. **Select Target and Scheme**
   - In Xcode, select the **SwiftProxy** scheme
   - Choose your Mac as the destination

3. **Build and Run**
   - Press `⌘ + R` to build and run
   - Or use the Product menu: `Product > Run`

4. **Build Only**
   - Press `⌘ + B` to build without running
   - Or use: `Product > Build`

### Method 2: Using Command Line (Quick Build)

#### Using the Build Script

```bash
# Navigate to project directory
cd /path/to/SwiftProxy

# Build and run in debug mode
./build_and_run.sh

# Build and run in release mode
./build_and_run.sh --release

# Build only (don't run)
./build_and_run.sh --no-run

# Clean build
./build_and_run.sh --clean

# Show help
./build_and_run.sh --help
```

#### Using Swift Package Manager Directly

```bash
# Debug build
swift build

# Release build
swift build -c release

# Run debug build
swift run

# Run release build
swift run -c release

# Clean build artifacts
swift package clean
```

### Method 3: Manual Build and Run

```bash
# Build
swift build -c release

# Run the executable
./.build/release/SwiftProxy
```

## Running Tests

### All Tests
```bash
swift test
```

### Specific Test Target
```bash
# Unit tests only
swift test --filter SwiftProxyTests

# Integration tests only
swift test --filter SwiftProxyIntegrationTests
```

### Using Test Script
```bash
./run_tests.sh
```

## Build Configurations

### Debug Build
- **Purpose**: Development and debugging
- **Optimizations**: Disabled
- **Debug Symbols**: Included
- **Assertions**: Enabled
- **Command**: `swift build` or `./build_and_run.sh`

### Release Build
- **Purpose**: Production deployment
- **Optimizations**: Enabled
- **Debug Symbols**: Minimal
- **Assertions**: Disabled
- **Command**: `swift build -c release` or `./build_and_run.sh --release`

## Application Features

### Network Proxy Server
- HTTP/HTTPS proxy support
- Request/response interception
- Traffic monitoring and logging
- Connection management

### User Interface
- SwiftUI-based modern macOS interface
- Real-time statistics dashboard
- Connection list view
- Proxy configuration management
- Settings panel

### Menu Bar Integration
- Status bar icon
- Quick access menu
- Enable/disable proxy toggle
- System-wide availability

## Configuration

### Proxy Settings
The application stores configurations in the user's preferences. Default settings:
- **Host**: localhost
- **Port**: 8080
- **Protocol**: HTTP/HTTPS

### Network Permissions
The app requires the following network permissions (configured in entitlements):
- Network client access
- Network server access
- Incoming/outgoing connections
- Local network access

## Troubleshooting

### Build Fails
1. **Check Swift Version**
   ```bash
   swift --version
   ```
   Ensure you have Swift 5.9 or later.

2. **Clean Build**
   ```bash
   swift package clean
   rm -rf .build
   swift build
   ```

3. **Update Dependencies**
   ```bash
   swift package update
   ```

### Runtime Issues

1. **Permission Denied**
   - Check that the app has network permissions
   - Verify entitlements are properly configured
   - Check macOS Security & Privacy settings

2. **Port Already in Use**
   - Change the proxy port in settings
   - Check for conflicting applications
   - Kill processes using the port:
     ```bash
     lsof -ti:8080 | xargs kill -9
     ```

3. **Network Not Accessible**
   - Verify firewall settings
   - Check macOS network preferences
   - Ensure no VPN conflicts

### Logging and Debugging

View application logs:
```bash
# macOS Unified Logging
log stream --predicate 'subsystem == "com.swiftproxy.app"' --level debug

# Specific categories
log stream --predicate 'subsystem == "com.swiftproxy.app" AND category == "proxy"'
log stream --predicate 'subsystem == "com.swiftproxy.app" AND category == "network"'
```

## Development Workflow

### Quick Iteration
```bash
# 1. Make code changes
# 2. Build and test
swift build && swift test

# 3. Run
swift run
```

### Code Formatting
```bash
# Format code (if using swift-format)
swift-format -i -r SwiftProxy/
```

### Performance Profiling
1. Build in release mode with debug symbols
2. Open in Instruments: `Xcode > Open Developer Tool > Instruments`
3. Profile the release build

## Deployment

### Creating Distribution Build
```bash
# Build optimized release
swift build -c release --arch arm64 --arch x86_64

# Create app bundle (if needed)
# This requires additional packaging steps
```

### Code Signing
For distribution, configure code signing in Xcode:
1. Open `Package.swift` in Xcode
2. Select the SwiftProxy target
3. Configure Signing & Capabilities
4. Add appropriate Team and Bundle Identifier

## Additional Resources

- **Swift Documentation**: https://swift.org/documentation/
- **SwiftUI Documentation**: https://developer.apple.com/documentation/swiftui/
- **Network Framework**: https://developer.apple.com/documentation/network/

## Support

For issues or questions:
1. Check the troubleshooting section above
2. Review application logs
3. Verify system requirements
4. Check project documentation

---

**Version**: 1.0.0
**Last Updated**: 2024-10-06
**Platform**: macOS 13.0+
