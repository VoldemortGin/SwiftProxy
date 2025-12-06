# SwiftProxy UI Tests

This directory contains XCUITest-based UI tests for SwiftProxy.

## ⚠️ Important Note

**XCUITest requires an Xcode project to run properly.** While the test files are prepared here, they need to be integrated into an Xcode project for execution.

## Current Status

✅ **Created Test Files:**
- `ProxyToggleUITests.swift` - Tests for the main proxy toggle functionality
- `ConfigurationUITests.swift` - Tests for configuration management (create, edit, delete)
- `StatisticsUITests.swift` - Tests for statistics display and real-time updates

✅ **Added Accessibility Identifiers:**
- ProxyToggle component: `ProxyToggleButton`, `ProxyStatusText`
- Configuration view: `AddConfigurationButton`, `ConfigurationCard_*`
- Configuration editor: `ConfigNameField`, `ConfigHostField`, `ConfigPortField`, etc.
- Action buttons: `DeleteConfigButton`, `EditConfigButton`, `TestConfigButton`, `SelectConfigButton`

## Converting to Xcode Project

To enable these UI tests, you need to:

### Option 1: Generate Xcode Project from SwiftPM

```bash
swift package generate-xcodeproj
```

Then in Xcode:
1. Select the project in the navigator
2. Click "+" to add a new target
3. Choose "UI Testing Bundle"
4. Name it "SwiftProxyUITests"
5. Copy the test files into the new target
6. Build and run tests with ⌘U

### Option 2: Create New Xcode Project

1. Create a new macOS App project in Xcode
2. Choose "SwiftUI" interface and "Swift" language
3. Enable "Include Tests" during creation
4. Add a new "UI Testing Bundle" target
5. Copy test files from this directory
6. Ensure accessibility identifiers match the UI code

## Test Coverage

The current test suite provides:

### ProxyToggleUITests
- ✅ Basic toggle on/off functionality
- ✅ Toggle without configuration (error handling)
- ✅ Toggle animation verification
- ✅ Network status integration
- ✅ Accessibility features
- ✅ Performance metrics

### ConfigurationUITests
- ✅ Create HTTP proxy configuration
- ✅ Create SOCKS5 proxy with authentication
- ✅ Validation error handling
- ✅ Edit existing configuration
- ✅ Delete configuration
- ✅ Configuration list display
- ✅ Select active configuration

### StatisticsUITests
- ✅ Statistics view visibility
- ✅ Key metrics display
- ✅ Data formatting (bytes, percentages, durations)
- ✅ Real-time updates
- ✅ Statistics reset
- ✅ Chart rendering
- ✅ Time period selection
- ✅ Top domains/processes lists

## Running Tests in Xcode

Once integrated into an Xcode project:

```bash
# Run all UI tests
xcodebuild test -scheme SwiftProxy -destination 'platform=macOS'

# Run specific test class
xcodebuild test -scheme SwiftProxy -destination 'platform=macOS' -only-testing:SwiftProxyUITests/ProxyToggleUITests

# Run specific test method
xcodebuild test -scheme SwiftProxy -destination 'platform=macOS' -only-testing:SwiftProxyUITests/ProxyToggleUITests/testToggleProxyEnableDisable
```

Or use Xcode's Test Navigator (⌘6) to run tests interactively.

## Test Requirements

- macOS 13.0 or later
- Xcode 15.0 or later
- SwiftProxy app built and available
- UI testing enabled in target settings

## Accessibility Identifiers Reference

### ProxyToggle
- `ProxyToggleButton` - Main toggle button
- `ProxyStatusText` - "Proxy Enabled/Disabled" text
- `ProxyConfigurationName` - Configuration name display
- `ProxyToggleLoadingIndicator` - Loading spinner

### Configuration Management
- `AddConfigurationButton` - Add new configuration
- `ConfigurationCard_{name}` - Configuration card (dynamic name)
- `EditConfigButton` - Edit configuration
- `DeleteConfigButton` - Delete configuration
- `TestConfigButton` - Test connection
- `SelectConfigButton` - Activate configuration

### Configuration Editor
- `ConfigNameField` - Name text field
- `ConfigTypeButton` - Type picker
- `ConfigHostField` - Host text field
- `ConfigPortField` - Port text field
- `ConfigAuthToggle` - Authentication toggle
- `ConfigUsernameField` - Username text field (when auth enabled)
- `ConfigPasswordField` - Password secure field (when auth enabled)
- `ConfigValidationError` - Validation error message
- `SaveConfigurationButton` - Save button
- `CancelConfigButton` - Cancel button

## Best Practices

1. **Page Object Pattern**: Consider refactoring tests to use Page Object pattern for better maintainability
2. **Wait Strategies**: Tests use `waitForExistence(timeout:)` for async operations
3. **Accessibility**: All interactive elements have unique identifiers
4. **Test Isolation**: Each test is independent and can run in any order
5. **Error Handling**: Tests verify both success and failure scenarios

## Future Enhancements

- [ ] Add performance baseline tests
- [ ] Implement Page Object pattern for reusable components
- [ ] Add screenshot capture on test failures
- [ ] Create test data fixtures
- [ ] Add network mocking for offline testing
- [ ] Implement visual regression testing
- [ ] Add accessibility audit tests

## Related Documentation

- [UI_AND_TESTING_ANALYSIS.md](/UI_AND_TESTING_ANALYSIS.md) - Comprehensive UI and testing analysis
- [ROADMAP.md](/ROADMAP.md) - Project roadmap and testing priorities
- [ARCHITECTURE.md](/ARCHITECTURE.md) - System architecture overview
