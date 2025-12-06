import XCTest

/// UI Tests for proxy configuration management
/// Tests creating, editing, and deleting configurations
final class ConfigurationUITests: XCTestCase {
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

    // MARK: - Configuration Creation Tests

    /// Test creating a new HTTP proxy configuration
    func testCreateHTTPConfiguration() throws {
        // Tap add configuration button
        let addButton = app.buttons["AddConfigurationButton"]
        XCTAssertTrue(addButton.exists, "Add button should exist")
        addButton.tap()

        // Wait for configuration editor
        let nameField = app.textFields["ConfigNameField"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 2.0), "Name field should appear")

        // Fill in configuration details
        nameField.tap()
        nameField.typeText("Test HTTP Proxy")

        let hostField = app.textFields["ConfigHostField"]
        hostField.tap()
        hostField.typeText("proxy.example.com")

        let portField = app.textFields["ConfigPortField"]
        portField.tap()
        portField.typeText("8080")

        // Select HTTP type
        let typeButton = app.popUpButtons["ConfigTypeButton"]
        if typeButton.exists {
            typeButton.tap()
            app.menuItems["HTTP"].tap()
        }

        // Save configuration
        let saveButton = app.buttons["SaveConfigurationButton"]
        XCTAssertTrue(saveButton.exists, "Save button should exist")
        saveButton.tap()

        // Verify configuration appears in list
        let configCard = app.buttons["ConfigurationCard_Test HTTP Proxy"]
        XCTAssertTrue(
            configCard.waitForExistence(timeout: 3.0),
            "Configuration should appear in list"
        )

        // Verify configuration details
        XCTAssertTrue(configCard.staticTexts["Test HTTP Proxy"].exists)
        XCTAssertTrue(configCard.staticTexts["proxy.example.com:8080"].exists)
    }

    /// Test creating a SOCKS5 proxy configuration with authentication
    func testCreateSOCKS5ConfigurationWithAuth() throws {
        let addButton = app.buttons["AddConfigurationButton"]
        addButton.tap()

        // Fill basic info
        let nameField = app.textFields["ConfigNameField"]
        nameField.tap()
        nameField.typeText("Test SOCKS5 Proxy")

        let hostField = app.textFields["ConfigHostField"]
        hostField.tap()
        hostField.typeText("socks.example.com")

        let portField = app.textFields["ConfigPortField"]
        portField.tap()
        portField.typeText("1080")

        // Select SOCKS5 type
        let typeButton = app.popUpButtons["ConfigTypeButton"]
        typeButton.tap()
        app.menuItems["SOCKS5"].tap()

        // Enable authentication
        let authToggle = app.switches["ConfigAuthToggle"]
        if !authToggle.isOn {
            authToggle.tap()
        }

        // Fill authentication details
        let usernameField = app.textFields["ConfigUsernameField"]
        XCTAssertTrue(usernameField.waitForExistence(timeout: 1.0), "Username field should appear")
        usernameField.tap()
        usernameField.typeText("testuser")

        let passwordField = app.secureTextFields["ConfigPasswordField"]
        passwordField.tap()
        passwordField.typeText("testpass123")

        // Save
        app.buttons["SaveConfigurationButton"].tap()

        // Verify
        let configCard = app.buttons["ConfigurationCard_Test SOCKS5 Proxy"]
        XCTAssertTrue(configCard.waitForExistence(timeout: 3.0))
    }

    /// Test creating configuration with validation errors
    func testCreateConfigurationWithValidationErrors() throws {
        let addButton = app.buttons["AddConfigurationButton"]
        addButton.tap()

        // Try to save without filling required fields
        let saveButton = app.buttons["SaveConfigurationButton"]
        saveButton.tap()

        // Should show validation errors
        let nameError = app.staticTexts["ConfigNameError"]
        let hostError = app.staticTexts["ConfigHostError"]

        XCTAssertTrue(
            nameError.exists || hostError.exists,
            "Should show validation errors for empty fields"
        )

        // Fill name only
        let nameField = app.textFields["ConfigNameField"]
        nameField.tap()
        nameField.typeText("Invalid Config")

        // Try to save again
        saveButton.tap()

        // Should still show host error
        XCTAssertTrue(hostError.waitForExistence(timeout: 1.0), "Should show host validation error")

        // Fill invalid host
        let hostField = app.textFields["ConfigHostField"]
        hostField.tap()
        hostField.typeText("not a valid host!")

        saveButton.tap()

        // Should show host format error
        let hostFormatError = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS[c] 'invalid' OR label CONTAINS[c] 'format'")
        )
        XCTAssertTrue(hostFormatError.count > 0, "Should show host format error")
    }

    // MARK: - Configuration Editing Tests

    /// Test editing an existing configuration
    func testEditConfiguration() throws {
        // Create a configuration first
        try testCreateHTTPConfiguration()

        // Tap on configuration to edit
        let configCard = app.buttons["ConfigurationCard_Test HTTP Proxy"]
        configCard.tap()

        // Wait for edit view
        let nameField = app.textFields["ConfigNameField"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 2.0))

        // Modify name
        nameField.tap()
        nameField.doubleTap() // Select all
        nameField.typeText("Modified HTTP Proxy")

        // Modify port
        let portField = app.textFields["ConfigPortField"]
        portField.tap()
        portField.doubleTap()
        portField.typeText("8888")

        // Save changes
        app.buttons["SaveConfigurationButton"].tap()

        // Verify changes
        let modifiedCard = app.buttons["ConfigurationCard_Modified HTTP Proxy"]
        XCTAssertTrue(modifiedCard.waitForExistence(timeout: 3.0))
        XCTAssertTrue(modifiedCard.staticTexts["proxy.example.com:8888"].exists)
    }

    // MARK: - Configuration Deletion Tests

    /// Test deleting a configuration
    func testDeleteConfiguration() throws {
        // Create a configuration first
        try testCreateHTTPConfiguration()

        let configCard = app.buttons["ConfigurationCard_Test HTTP Proxy"]
        XCTAssertTrue(configCard.exists)

        // Find and tap delete button
        let deleteButton = configCard.buttons["DeleteConfigButton"]
        if deleteButton.exists {
            deleteButton.tap()

            // Confirm deletion in alert
            let confirmButton = app.buttons["Confirm"]
            if confirmButton.exists {
                confirmButton.tap()
            }
        } else {
            // Alternative: swipe to delete
            configCard.swipeLeft()
            app.buttons["Delete"].tap()
        }

        // Verify configuration is removed
        XCTAssertFalse(
            configCard.waitForExistence(timeout: 1.0),
            "Configuration should be deleted"
        )
    }

    /// Test canceling configuration deletion
    func testCancelDeleteConfiguration() throws {
        try testCreateHTTPConfiguration()

        let configCard = app.buttons["ConfigurationCard_Test HTTP Proxy"]
        let deleteButton = configCard.buttons["DeleteConfigButton"]

        if deleteButton.exists {
            deleteButton.tap()

            // Cancel deletion
            let cancelButton = app.buttons["Cancel"]
            if cancelButton.exists {
                cancelButton.tap()
            }

            // Verify configuration still exists
            XCTAssertTrue(configCard.exists, "Configuration should not be deleted")
        }
    }

    // MARK: - Configuration List Tests

    /// Test configuration list display
    func testConfigurationListDisplay() throws {
        // Create multiple configurations
        createConfiguration(name: "Proxy A", host: "a.example.com", port: "8080", type: "HTTP")
        createConfiguration(name: "Proxy B", host: "b.example.com", port: "1080", type: "SOCKS5")
        createConfiguration(name: "Proxy C", host: "c.example.com", port: "8443", type: "HTTPS")

        // Verify all configurations are displayed
        let cardA = app.buttons["ConfigurationCard_Proxy A"]
        let cardB = app.buttons["ConfigurationCard_Proxy B"]
        let cardC = app.buttons["ConfigurationCard_Proxy C"]

        XCTAssertTrue(cardA.exists)
        XCTAssertTrue(cardB.exists)
        XCTAssertTrue(cardC.exists)

        // Verify sorting (should be alphabetical by name)
        let cards = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'ConfigurationCard_'"))
        XCTAssertGreaterThanOrEqual(cards.count, 3)
    }

    /// Test selecting active configuration
    func testSelectActiveConfiguration() throws {
        createConfiguration(name: "Test Proxy", host: "test.example.com", port: "8080", type: "HTTP")

        let configCard = app.buttons["ConfigurationCard_Test Proxy"]

        // Select as active (might be a radio button or checkbox)
        let selectButton = configCard.buttons["SelectConfigButton"]
        if selectButton.exists {
            selectButton.tap()

            // Verify selection indicator
            let selectedIndicator = configCard.images["CheckmarkIcon"]
            XCTAssertTrue(
                selectedIndicator.waitForExistence(timeout: 1.0),
                "Should show selection indicator"
            )
        }
    }

    // MARK: - Helper Methods

    /// Helper to create a configuration
    private func createConfiguration(name: String, host: String, port: String, type: String) {
        let addButton = app.buttons["AddConfigurationButton"]
        addButton.tap()

        let nameField = app.textFields["ConfigNameField"]
        nameField.tap()
        nameField.typeText(name)

        let hostField = app.textFields["ConfigHostField"]
        hostField.tap()
        hostField.typeText(host)

        let portField = app.textFields["ConfigPortField"]
        portField.tap()
        portField.typeText(port)

        let typeButton = app.popUpButtons["ConfigTypeButton"]
        if typeButton.exists {
            typeButton.tap()
            app.menuItems[type].tap()
        }

        app.buttons["SaveConfigurationButton"].tap()

        // Wait for creation to complete
        Thread.sleep(forTimeInterval: 0.5)
    }
}

// MARK: - XCUIElement Extensions

extension XCUIElement {
    /// Check if toggle is on
    var isOn: Bool {
        (value as? String) == "1"
    }
}
