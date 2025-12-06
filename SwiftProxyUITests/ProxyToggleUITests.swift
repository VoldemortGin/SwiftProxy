import XCTest

/// UI Tests for the main ProxyToggle component
/// Tests the core proxy enable/disable functionality
final class ProxyToggleUITests: XCTestCase {
    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false

        app = XCUIApplication()
        app.launchArguments = ["--uitesting"]
        app.launch()
    }

    override func tearDownWithError() throws {
        app = nil
    }

    // MARK: - Toggle Functionality Tests

    /// Test basic proxy toggle on/off
    func testToggleProxyEnableDisable() throws {
        // Find the proxy toggle button
        let toggleButton = app.buttons["ProxyToggleButton"]
        XCTAssertTrue(toggleButton.exists, "ProxyToggle button should exist")

        // Verify initial state is disabled
        let statusText = app.staticTexts["ProxyStatusText"]
        XCTAssertTrue(statusText.label.contains("Disabled"), "Proxy should start disabled")

        // Enable proxy
        toggleButton.tap()

        // Wait for state to update
        let enabledExpectation = expectation(
            for: NSPredicate(format: "label CONTAINS 'Enabled'"),
            evaluatedWith: statusText,
            handler: nil
        )
        wait(for: [enabledExpectation], timeout: 3.0)

        // Verify enabled state
        XCTAssertTrue(statusText.label.contains("Enabled"), "Proxy should be enabled")

        // Disable proxy
        toggleButton.tap()

        // Wait for state to update
        let disabledExpectation = expectation(
            for: NSPredicate(format: "label CONTAINS 'Disabled'"),
            evaluatedWith: statusText,
            handler: nil
        )
        wait(for: [disabledExpectation], timeout: 3.0)

        // Verify disabled state
        XCTAssertTrue(statusText.label.contains("Disabled"), "Proxy should be disabled")
    }

    /// Test toggle with no configuration
    func testToggleWithoutConfiguration() throws {
        let toggleButton = app.buttons["ProxyToggleButton"]

        // Ensure no configurations exist
        if app.buttons["ConfigurationCardButton"].exists {
            // Delete all configurations first
            while app.buttons["DeleteConfigButton"].exists {
                app.buttons["DeleteConfigButton"].firstMatch.tap()

                // Confirm deletion if dialog appears
                if app.buttons["Confirm"].exists {
                    app.buttons["Confirm"].tap()
                }
            }
        }

        // Try to enable proxy without configuration
        toggleButton.tap()

        // Should show error or remain disabled
        let errorAlert = app.alerts.firstMatch
        if errorAlert.exists {
            XCTAssertTrue(
                errorAlert.staticTexts["No configuration available"].exists ||
                errorAlert.staticTexts["No Configuration"].exists,
                "Should show no configuration error"
            )

            // Dismiss error
            app.buttons["OK"].tap()
        }

        // Verify still disabled
        let statusText = app.staticTexts["ProxyStatusText"]
        XCTAssertTrue(statusText.label.contains("Disabled"), "Proxy should remain disabled")
    }

    /// Test toggle animation
    func testToggleAnimation() throws {
        let toggleButton = app.buttons["ProxyToggleButton"]

        // Get initial frame
        let initialFrame = toggleButton.frame

        // Tap to enable
        toggleButton.tap()

        // Small delay for animation
        Thread.sleep(forTimeInterval: 0.3)

        // Button should still exist and be tappable (animation shouldn't break interaction)
        XCTAssertTrue(toggleButton.exists)
        XCTAssertTrue(toggleButton.isHittable)

        // Frame should remain similar (no drastic layout changes)
        let finalFrame = toggleButton.frame
        XCTAssertEqual(initialFrame.width, finalFrame.width, accuracy: 10.0)
        XCTAssertEqual(initialFrame.height, finalFrame.height, accuracy: 10.0)
    }

    // MARK: - Network Status Tests

    /// Test proxy behavior when network is unavailable
    func testToggleWithoutNetwork() throws {
        // Note: This test would require mocking network state
        // For now, we just verify the UI responds appropriately

        let toggleButton = app.buttons["ProxyToggleButton"]
        let networkStatus = app.staticTexts["NetworkStatusText"]

        // Verify network status is displayed
        if networkStatus.exists {
            // If network is available, toggle should work
            if networkStatus.label.contains("Connected") {
                toggleButton.tap()

                let statusText = app.staticTexts["ProxyStatusText"]
                let expectation = self.expectation(
                    for: NSPredicate(format: "label CONTAINS[c] 'Enabled' OR label CONTAINS[c] 'Error'"),
                    evaluatedWith: statusText,
                    handler: nil
                )
                wait(for: [expectation], timeout: 5.0)
            }
        }
    }

    // MARK: - Accessibility Tests

    /// Test accessibility features
    func testAccessibility() throws {
        let toggleButton = app.buttons["ProxyToggleButton"]

        // Verify accessibility identifier
        XCTAssertTrue(toggleButton.exists)

        // Verify button is enabled
        XCTAssertTrue(toggleButton.isEnabled)

        // Verify button has label
        XCTAssertFalse(toggleButton.label.isEmpty, "Button should have accessible label")

        // Test VoiceOver hint (if available)
        if !toggleButton.value(forKey: "accessibilityHint") is NSNull {
            let hint = toggleButton.value(forKey: "accessibilityHint") as? String
            XCTAssertNotNil(hint, "Button should have accessibility hint")
        }
    }

    // MARK: - Performance Tests

    /// Test toggle response time
    func testTogglePerformance() throws {
        let toggleButton = app.buttons["ProxyToggleButton"]

        measure(metrics: [XCTApplicationLaunchMetric(), XCTOSSignpostMetric.navigationTransitionMetric]) {
            // Enable
            toggleButton.tap()

            // Wait for state update
            let statusText = app.staticTexts["ProxyStatusText"]
            _ = statusText.waitForExistence(timeout: 2.0)

            // Disable
            toggleButton.tap()
            _ = statusText.waitForExistence(timeout: 2.0)
        }
    }
}

// MARK: - Helper Extensions

extension XCUIElement {
    /// Wait for element to exist with custom timeout
    func waitForExistence(timeout: TimeInterval) -> Bool {
        let predicate = NSPredicate(format: "exists == true")
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: self)
        let result = XCTWaiter().wait(for: [expectation], timeout: timeout)
        return result == .completed
    }
}
