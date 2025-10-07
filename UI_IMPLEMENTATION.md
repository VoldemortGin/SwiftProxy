# SwiftProxy UI Implementation

Complete UI implementation for the SwiftProxy macOS application using SwiftUI.

## Overview

This implementation provides a modern, responsive, and accessible user interface following Apple's Human Interface Guidelines. All components support both light and dark modes with smooth animations and transitions.

## Architecture

### Directory Structure

```
SwiftProxy/UI/
├── Components/          # Reusable UI components
│   ├── StatusIndicator.swift
│   ├── ProxyToggle.swift
│   ├── ConnectionRow.swift
│   ├── StatChart.swift
│   └── ViewExtensions.swift
├── Views/              # Main application views
│   ├── MainView.swift
│   ├── ProxyConfigView.swift
│   ├── ConnectionListView.swift
│   ├── StatisticsView.swift
│   └── SettingsView.swift
└── ViewModels/         # State management
    └── MainViewModel.swift
```

## Components

### 1. StatusIndicator
**Purpose**: Visual indicator for proxy connection status

**Features**:
- Animated status dot with color-coding
- Four states: connected, connecting, disconnected, error
- Optional label display
- Pulse animation for connecting state

**Usage**:
```swift
StatusIndicator(status: .connected, showLabel: true)
```

### 2. ProxyToggle
**Purpose**: Main control for enabling/disabling proxy

**Features**:
- Large, prominent button with gradient background
- Displays current configuration
- Processing state with loading indicator
- Smooth animations and visual feedback
- Disabled state when no configuration available

**Usage**:
```swift
ProxyToggle(
    isEnabled: $isEnabled,
    configuration: currentConfig,
    onToggle: { /* handle toggle */ }
)
```

### 3. ConnectionRow
**Purpose**: Display individual network requests in a list

**Features**:
- Method badge with color coding
- Status code indicator
- Latency and size metrics
- Host and path information
- Hover effects
- Status icons for different request states

**Usage**:
```swift
ConnectionRow(request: networkRequest) {
    // Handle selection
}
```

### 4. StatChart
**Purpose**: Interactive charts for traffic statistics

**Features**:
- Multiple chart types: line, bar, area
- Time range selection (hour, day, week, month)
- Interactive data point selection
- Summary statistics
- Responsive layout

**Usage**:
```swift
StatChart(
    data: chartDataPoints,
    chartType: .area,
    timeRange: .day
)
```

## Views

### 1. MainView
**Purpose**: Root view with navigation and layout

**Features**:
- Split view with sidebar navigation
- Tab-based content switching
- Status display in sidebar
- Toolbar with quick actions
- Error handling with alerts

**Tabs**:
- Proxy: Configuration management
- Connections: Live request monitoring
- Statistics: Traffic analytics
- Settings: App preferences

### 2. ProxyConfigView
**Purpose**: Manage proxy configurations

**Features**:
- Proxy toggle control
- Configuration list with cards
- Add/edit/delete configurations
- Test connection functionality
- Empty state for no configurations
- Configuration editor sheet

**Configuration Editor**:
- Basic information (name, type, host, port)
- Authentication settings
- Advanced options (bypass domains, DNS)
- Validation with error messages

### 3. ConnectionListView
**Purpose**: Monitor network connections in real-time

**Features**:
- Filterable and searchable list
- Sort by multiple criteria
- Status filtering
- Detailed request inspection
- Empty state handling
- Animated list updates

**Request Details**:
- Full request/response information
- Headers display
- Performance metrics
- Timestamp information

### 4. StatisticsView
**Purpose**: Analytics and insights dashboard

**Features**:
- Time range selector
- Multiple metric types
- Metrics grid with key statistics
- Top domains list
- HTTP method distribution chart
- Export functionality (CSV, JSON)

**Metrics**:
- Total requests
- Success rate
- Failed requests
- Data transfer (up/down)
- Average latency

### 5. SettingsView
**Purpose**: Application preferences and configuration

**Sections**:
1. **General**: App behavior, appearance
2. **Proxy**: Connection settings, DNS configuration
3. **Rules**: Routing rules management
4. **Network**: Traffic capture, bandwidth limiting
5. **Advanced**: Logging, data management
6. **About**: App information and links

## ViewModels

### MainViewModel
**Purpose**: Centralized state management

**Responsibilities**:
- Proxy service coordination
- Configuration management
- Network monitoring
- Statistics tracking
- Error handling

**Published Properties**:
- `isProxyEnabled`: Current proxy state
- `currentConfiguration`: Active configuration
- `proxyStatus`: Detailed proxy status
- `savedConfigurations`: All saved configs
- `recentRequests`: Network request history
- `statistics`: Aggregated traffic stats
- `errorMessage`: User-facing errors

**Key Methods**:
```swift
func enableProxy(configuration: ProxyConfiguration) async
func disableProxy() async
func toggleProxy() async
func saveConfiguration(_ config: ProxyConfiguration) async
func testConfiguration(_ config: ProxyConfiguration) async
func addRequest(_ request: NetworkRequest)
```

## Design Patterns

### 1. MVVM Architecture
- Clear separation of concerns
- Views observe ViewModels
- ViewModels coordinate business logic
- Models remain independent

### 2. Reactive Programming
- Combine framework for state updates
- Publisher/Subscriber pattern
- Automatic UI updates on state changes

### 3. Async/Await
- Modern concurrency for I/O operations
- Clean error handling
- No callback hell

### 4. SwiftUI Best Practices
- Composition over inheritance
- Extracted subviews for clarity
- Proper state management
- Performance optimization

## Accessibility Features

1. **VoiceOver Support**
   - Descriptive labels for all interactive elements
   - Proper accessibility hints

2. **Keyboard Navigation**
   - Full keyboard control
   - Keyboard shortcuts for common actions
   - Focus management

3. **Dynamic Type**
   - Respects system text size settings
   - Proper font scaling

4. **Color Contrast**
   - WCAG AA compliant
   - High contrast mode support

## Dark Mode Support

All components automatically adapt to system appearance:
- Appropriate color schemes
- Readable text in both modes
- Consistent visual hierarchy
- No hard-coded colors

## Performance Optimizations

1. **Lazy Loading**
   - LazyVStack/LazyVGrid for large lists
   - On-demand data loading

2. **Efficient Updates**
   - Minimal view re-renders
   - Proper use of @State, @Published
   - Debounced search

3. **Memory Management**
   - Limited history (100 requests)
   - Proper cleanup in deinit
   - Weak references where needed

## Animation Guidelines

### Durations
- Quick feedback: 0.2s
- Standard transitions: 0.3s
- Complex animations: 0.5s

### Curves
- `easeInOut`: Standard transitions
- `spring`: Interactive elements
- `linear`: Progress indicators

### Best Practices
- Subtle, purposeful animations
- Consistent timing across app
- Respect reduced motion preferences

## Previews

All components include comprehensive previews:
- Light and dark mode variants
- Different states (empty, loading, error)
- Various data scenarios
- Edge cases

**Example**:
```swift
#Preview("Light Mode") {
    MainView(viewModel: .preview)
}

#Preview("Dark Mode") {
    MainView(viewModel: .preview)
        .preferredColorScheme(.dark)
}
```

## Testing Considerations

### Unit Testing
- ViewModel business logic
- Data transformations
- Error handling

### UI Testing
- Navigation flows
- Form validation
- User interactions

### Preview Testing
- Visual regression testing
- Snapshot testing
- Accessibility audits

## Future Enhancements

1. **Additional Features**
   - Custom themes
   - Widget support
   - Shortcuts integration

2. **Performance**
   - Virtual scrolling for huge lists
   - Background data processing
   - Caching strategies

3. **Accessibility**
   - Additional voice control
   - Custom accessibility actions
   - Improved screen reader support

## Usage Example

```swift
import SwiftUI

@main
struct SwiftProxyApp: App {
    @StateObject private var viewModel: MainViewModel

    init() {
        let service = ProxyService()
        _viewModel = StateObject(wrappedValue: MainViewModel(proxyService: service))
    }

    var body: some Scene {
        WindowGroup {
            MainView(viewModel: viewModel)
                .frame(minWidth: 800, minHeight: 600)
        }
    }
}
```

## Dependencies

- SwiftUI (macOS 13.0+)
- Combine
- Charts (for statistics)
- OSLog (for logging)

## Resources

- [Apple Human Interface Guidelines](https://developer.apple.com/design/human-interface-guidelines/macos)
- [SwiftUI Documentation](https://developer.apple.com/documentation/swiftui)
- [Swift Concurrency](https://docs.swift.org/swift-book/LanguageGuide/Concurrency.html)

## License

Copyright © 2024 SwiftProxy. All rights reserved.
