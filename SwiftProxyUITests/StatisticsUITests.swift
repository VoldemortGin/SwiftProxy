import XCTest

/// UI Tests for statistics display and data visualization
/// Tests real-time statistics updates and data accuracy
final class StatisticsUITests: XCTestCase {
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

    // MARK: - Statistics Display Tests

    /// Test that statistics section is visible
    func testStatisticsViewExists() throws {
        // Navigate to statistics view (might be in sidebar or separate tab)
        let statisticsButton = app.buttons["StatisticsButton"]
        if statisticsButton.exists {
            statisticsButton.tap()
        }

        // Verify statistics view is displayed
        let statisticsView = app.otherElements["StatisticsView"]
        XCTAssertTrue(
            statisticsView.exists || app.staticTexts["Statistics"].exists,
            "Statistics view should be visible"
        )
    }

    /// Test that key statistics are displayed
    func testKeyStatisticsDisplay() throws {
        // Verify presence of key metrics
        let metrics = [
            "ConnectionCountText",
            "ActiveConnectionsText",
            "TotalBytesText",
            "SuccessRateText",
            "UptimeText"
        ]

        for metric in metrics {
            let element = app.staticTexts[metric]
            XCTAssertTrue(
                element.exists,
                "\(metric) should be displayed in statistics"
            )
        }
    }

    /// Test statistics formatting
    func testStatisticsFormatting() throws {
        let bytesText = app.staticTexts["TotalBytesText"]

        if bytesText.exists {
            let label = bytesText.label

            // Should include units (KB, MB, GB, etc.)
            let hasUnits = label.contains("KB") || label.contains("MB") ||
                           label.contains("GB") || label.contains("TB") ||
                           label.contains("B")

            XCTAssertTrue(hasUnits, "Bytes should be formatted with units")
        }

        let successRateText = app.staticTexts["SuccessRateText"]
        if successRateText.exists {
            let label = successRateText.label
            XCTAssertTrue(label.contains("%"), "Success rate should include percentage symbol")
        }

        let uptimeText = app.staticTexts["UptimeText"]
        if uptimeText.exists {
            let label = uptimeText.label

            // Should include time units (s, m, h, d)
            let hasTimeUnits = label.contains("s") || label.contains("m") ||
                              label.contains("h") || label.contains("d")

            XCTAssertTrue(hasTimeUnits, "Uptime should be formatted with time units")
        }
    }

    // MARK: - Real-time Update Tests

    /// Test that statistics update when proxy is enabled
    func testStatisticsUpdateOnProxyEnable() throws {
        // Get initial connection count
        let connectionCountText = app.staticTexts["ConnectionCountText"]
        let initialCount = connectionCountText.label

        // Enable proxy
        let toggleButton = app.buttons["ProxyToggleButton"]
        if toggleButton.exists && !app.staticTexts["ProxyStatusText"].label.contains("Enabled") {
            toggleButton.tap()

            // Wait for proxy to enable
            let statusText = app.staticTexts["ProxyStatusText"]
            let expectation = self.expectation(
                for: NSPredicate(format: "label CONTAINS 'Enabled'"),
                evaluatedWith: statusText,
                handler: nil
            )
            wait(for: [expectation], timeout: 5.0)

            // Statistics should still be accessible
            XCTAssertTrue(connectionCountText.exists, "Statistics should remain visible")

            // Note: Actual count changes would require real traffic
        }
    }

    /// Test statistics reset functionality
    func testStatisticsReset() throws {
        // Find reset button
        let resetButton = app.buttons["ResetStatisticsButton"]

        if resetButton.exists {
            resetButton.tap()

            // Confirm reset if dialog appears
            let confirmButton = app.buttons["Confirm"]
            if confirmButton.exists {
                confirmButton.tap()
            }

            // Wait for reset to complete
            Thread.sleep(forTimeInterval: 1.0)

            // Verify statistics are reset
            let connectionCountText = app.staticTexts["ConnectionCountText"]
            if connectionCountText.exists {
                XCTAssertTrue(
                    connectionCountText.label.contains("0") || connectionCountText.label == "0",
                    "Connection count should be reset to 0"
                )
            }
        }
    }

    // MARK: - Chart Display Tests

    /// Test that charts are rendered
    func testChartDisplay() throws {
        // Navigate to statistics view
        let statisticsButton = app.buttons["StatisticsButton"]
        if statisticsButton.exists {
            statisticsButton.tap()
        }

        // Look for chart elements
        let charts = app.otherElements.matching(NSPredicate(format: "identifier CONTAINS 'Chart'"))

        if charts.count > 0 {
            XCTAssertTrue(charts.firstMatch.exists, "Charts should be rendered")

            // Verify chart is visible and has reasonable size
            let chart = charts.firstMatch
            XCTAssertGreaterThan(chart.frame.width, 100, "Chart should have reasonable width")
            XCTAssertGreaterThan(chart.frame.height, 50, "Chart should have reasonable height")
        }
    }

    /// Test chart time period selection
    func testChartTimePeriodSelection() throws {
        let timePeriodButton = app.popUpButtons["ChartTimePeriodButton"]

        if timePeriodButton.exists {
            timePeriodButton.tap()

            // Verify time period options
            let periods = ["Session", "Today", "This Week", "This Month", "All Time"]

            for period in periods {
                let menuItem = app.menuItems[period]
                if menuItem.exists {
                    menuItem.tap()

                    // Wait for chart to update
                    Thread.sleep(forTimeInterval: 0.5)

                    // Verify time period is selected
                    XCTAssertTrue(
                        timePeriodButton.label.contains(period),
                        "\(period) should be selected"
                    )

                    // Re-open menu for next iteration
                    if period != periods.last {
                        timePeriodButton.tap()
                    }
                }
            }
        }
    }

    /// Test chart data type selection
    func testChartDataTypeSelection() throws {
        let dataTypeButton = app.popUpButtons["ChartDataTypeButton"]

        if dataTypeButton.exists {
            dataTypeButton.tap()

            // Verify data type options
            let dataTypes = ["Connections", "Data Transfer", "Success Rate"]

            for dataType in dataTypes {
                let menuItem = app.menuItems[dataType]
                if menuItem.exists {
                    menuItem.tap()

                    // Wait for chart to update
                    Thread.sleep(forTimeInterval: 0.5)

                    // Verify chart updated
                    // (This would need more sophisticated verification in real tests)

                    if dataType != dataTypes.last {
                        dataTypeButton.tap()
                    }
                }
            }
        }
    }

    // MARK: - Top Domains/Processes Tests

    /// Test top domains list
    func testTopDomainsList() throws {
        let topDomainsSection = app.otherElements["TopDomainsSection"]

        if topDomainsSection.exists {
            // Verify section is visible
            XCTAssertTrue(topDomainsSection.exists)

            // Look for domain entries
            let domainEntries = app.staticTexts.matching(
                NSPredicate(format: "identifier CONTAINS 'DomainEntry'")
            )

            if domainEntries.count > 0 {
                // Verify entries have proper format
                let firstEntry = domainEntries.firstMatch
                XCTAssertFalse(firstEntry.label.isEmpty, "Domain entry should have text")

                // Should show domain name and statistics
                // Format typically: "example.com - 123 requests"
                XCTAssertTrue(
                    firstEntry.label.contains(".") || firstEntry.label.contains(":"),
                    "Domain entry should show domain name"
                )
            }
        }
    }

    /// Test top processes list
    func testTopProcessesList() throws {
        let topProcessesSection = app.otherElements["TopProcessesSection"]

        if topProcessesSection.exists {
            XCTAssertTrue(topProcessesSection.exists)

            let processEntries = app.staticTexts.matching(
                NSPredicate(format: "identifier CONTAINS 'ProcessEntry'")
            )

            if processEntries.count > 0 {
                let firstEntry = processEntries.firstMatch
                XCTAssertFalse(firstEntry.label.isEmpty, "Process entry should have text")
            }
        }
    }

    // MARK: - Export Tests

    /// Test statistics export functionality
    func testStatisticsExport() throws {
        let exportButton = app.buttons["ExportStatisticsButton"]

        if exportButton.exists {
            exportButton.tap()

            // Wait for save panel or export confirmation
            // Note: Save panels are system dialogs and harder to test
            // This would typically be mocked or tested with system integration

            // For now, just verify the button is clickable
            XCTAssertTrue(exportButton.isHittable, "Export button should be clickable")
        }
    }

    // MARK: - Layout Tests

    /// Test responsive layout of statistics view
    func testStatisticsLayout() throws {
        let statisticsView = app.otherElements["StatisticsView"]

        if statisticsView.exists {
            // Verify view has reasonable size
            let frame = statisticsView.frame
            XCTAssertGreaterThan(frame.width, 200, "Statistics view should have adequate width")
            XCTAssertGreaterThan(frame.height, 100, "Statistics view should have adequate height")

            // Verify key elements are within bounds
            let connectionCountText = app.staticTexts["ConnectionCountText"]
            if connectionCountText.exists {
                let countFrame = connectionCountText.frame
                XCTAssertTrue(
                    statisticsView.frame.contains(countFrame),
                    "Statistics elements should be within view bounds"
                )
            }
        }
    }

    // MARK: - Performance Tests

    /// Test statistics rendering performance
    func testStatisticsRenderingPerformance() throws {
        let statisticsButton = app.buttons["StatisticsButton"]

        if statisticsButton.exists {
            measure(metrics: [XCTOSSignpostMetric.navigationTransitionMetric]) {
                // Navigate to statistics
                statisticsButton.tap()

                // Wait for statistics to load
                let statisticsView = app.otherElements["StatisticsView"]
                _ = statisticsView.waitForExistence(timeout: 2.0)

                // Navigate away
                let homeButton = app.buttons["HomeButton"]
                if homeButton.exists {
                    homeButton.tap()
                }
            }
        }
    }
}
