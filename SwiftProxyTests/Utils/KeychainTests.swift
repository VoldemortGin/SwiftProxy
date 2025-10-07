import XCTest
@testable import SwiftProxy

/// Unit tests for Keychain utility
final class KeychainTests: XCTestCase {

    // MARK: - Properties

    var sut: Keychain!
    let testServiceName = "com.swiftproxy.test"

    // MARK: - Test Lifecycle

    override func setUpWithError() throws {
        try super.setUpWithError()

        sut = Keychain(serviceName: testServiceName)

        // Clean up any existing test data
        try? sut.deleteAll()
    }

    override func tearDownWithError() throws {
        // Clean up test data
        try? sut.deleteAll()

        sut = nil

        try super.tearDownWithError()
    }

    // MARK: - String Operations Tests

    func testSetAndGetString() throws {
        // Given
        let key = "testKey"
        let value = "testValue"

        // When
        try sut.setString(value, forKey: key)

        // Then
        let retrieved = try sut.getString(forKey: key)
        XCTAssertEqual(retrieved, value)
    }

    func testGetNonexistentString() throws {
        // Given
        let key = "nonexistent"

        // When
        let retrieved = try sut.getString(forKey: key)

        // Then
        XCTAssertNil(retrieved)
    }

    func testOverwriteString() throws {
        // Given
        let key = "testKey"
        let value1 = "value1"
        let value2 = "value2"

        // When
        try sut.setString(value1, forKey: key)
        try sut.setString(value2, forKey: key)

        // Then
        let retrieved = try sut.getString(forKey: key)
        XCTAssertEqual(retrieved, value2)
    }

    // MARK: - Data Operations Tests

    func testSetAndGetData() throws {
        // Given
        let key = "testDataKey"
        let value = "test data".data(using: .utf8)!

        // When
        try sut.setData(value, forKey: key)

        // Then
        let retrieved = try sut.getData(forKey: key)
        XCTAssertEqual(retrieved, value)
    }

    // MARK: - Codable Operations Tests

    func testSetAndGetCodable() throws {
        // Given
        struct TestStruct: Codable, Equatable {
            let name: String
            let value: Int
        }

        let key = "testCodableKey"
        let testStruct = TestStruct(name: "Test", value: 42)

        // When
        try sut.setCodable(testStruct, forKey: key)

        // Then
        let retrieved = try sut.getCodable(forKey: key, as: TestStruct.self)
        XCTAssertEqual(retrieved, testStruct)
    }

    func testGetNonexistentCodable() throws {
        // Given
        struct TestStruct: Codable {
            let name: String
        }

        let key = "nonexistent"

        // When
        let retrieved = try sut.getCodable(forKey: key, as: TestStruct.self)

        // Then
        XCTAssertNil(retrieved)
    }

    // MARK: - Delete Operations Tests

    func testDeleteItem() throws {
        // Given
        let key = "testKey"
        let value = "testValue"

        try sut.setString(value, forKey: key)
        XCTAssertNotNil(try sut.getString(forKey: key))

        // When
        try sut.delete(forKey: key)

        // Then
        let retrieved = try sut.getString(forKey: key)
        XCTAssertNil(retrieved)
    }

    func testDeleteNonexistentItem() throws {
        // Given
        let key = "nonexistent"

        // When/Then - should not throw
        XCTAssertNoThrow(try sut.delete(forKey: key))
    }

    func testDeleteAll() throws {
        // Given
        try sut.setString("value1", forKey: "key1")
        try sut.setString("value2", forKey: "key2")
        try sut.setString("value3", forKey: "key3")

        // When
        try sut.deleteAll()

        // Then
        XCTAssertNil(try sut.getString(forKey: "key1"))
        XCTAssertNil(try sut.getString(forKey: "key2"))
        XCTAssertNil(try sut.getString(forKey: "key3"))
    }

    // MARK: - Query Operations Tests

    func testItemExists() throws {
        // Given
        let key = "testKey"
        let value = "testValue"

        // When/Then - initially doesn't exist
        XCTAssertFalse(sut.exists(forKey: key))

        // When - save item
        try sut.setString(value, forKey: key)

        // Then
        XCTAssertTrue(sut.exists(forKey: key))
    }

    func testAllKeys() throws {
        // Given
        try sut.setString("value1", forKey: "key1")
        try sut.setString("value2", forKey: "key2")
        try sut.setString("value3", forKey: "key3")

        // When
        let keys = try sut.allKeys()

        // Then
        XCTAssertEqual(Set(keys), Set(["key1", "key2", "key3"]))
    }

    func testAllKeysEmpty() throws {
        // Given - empty keychain

        // When
        let keys = try sut.allKeys()

        // Then
        XCTAssertTrue(keys.isEmpty)
    }

    // MARK: - Bulk Operations Tests

    func testSetBulk() throws {
        // Given
        let items: [String: Data] = [
            "key1": "value1".data(using: .utf8)!,
            "key2": "value2".data(using: .utf8)!,
            "key3": "value3".data(using: .utf8)!
        ]

        // When
        try sut.setBulk(items)

        // Then
        for (key, expectedValue) in items {
            let retrievedValue = try sut.getData(forKey: key)
            XCTAssertEqual(retrievedValue, expectedValue)
        }
    }

    func testGetBulk() throws {
        // Given
        try sut.setString("value1", forKey: "key1")
        try sut.setString("value2", forKey: "key2")
        try sut.setString("value3", forKey: "key3")

        // When
        let keys = ["key1", "key2", "key3"]
        let results = try sut.getBulk(forKeys: keys)

        // Then
        XCTAssertEqual(results.count, 3)
        XCTAssertEqual(results["key1"], "value1".data(using: .utf8))
        XCTAssertEqual(results["key2"], "value2".data(using: .utf8))
        XCTAssertEqual(results["key3"], "value3".data(using: .utf8))
    }

    // MARK: - Password Helper Tests

    func testPasswordHelper() throws {
        // Given
        let identifier = "user@example.com"
        let password = "securePassword123"

        // When
        try sut.passwords.set(password, for: identifier)

        // Then
        let retrieved = try sut.passwords.get(for: identifier)
        XCTAssertEqual(retrieved, password)

        // When - delete
        try sut.passwords.delete(for: identifier)

        // Then
        let afterDelete = try sut.passwords.get(for: identifier)
        XCTAssertNil(afterDelete)
    }

    // MARK: - Async Operations Tests

    func testAsyncStringOperations() async throws {
        // Given
        let key = "asyncKey"
        let value = "asyncValue"

        // When
        try await sut.setStringAsync(value, forKey: key)

        // Then
        let retrieved = try await sut.getStringAsync(forKey: key)
        XCTAssertEqual(retrieved, value)

        // When - delete
        try await sut.deleteAsync(forKey: key)

        // Then
        let afterDelete = try await sut.getStringAsync(forKey: key)
        XCTAssertNil(afterDelete)
    }

    // MARK: - Edge Cases Tests

    func testEmptyString() throws {
        // Given
        let key = "emptyKey"
        let value = ""

        // When
        try sut.setString(value, forKey: key)

        // Then
        let retrieved = try sut.getString(forKey: key)
        XCTAssertEqual(retrieved, value)
    }

    func testLargeData() throws {
        // Given
        let key = "largeDataKey"
        let largeString = String(repeating: "A", count: 100000) // 100KB
        let largeData = largeString.data(using: .utf8)!

        // When
        try sut.setData(largeData, forKey: key)

        // Then
        let retrieved = try sut.getData(forKey: key)
        XCTAssertEqual(retrieved, largeData)
    }

    func testUnicodeString() throws {
        // Given
        let key = "unicodeKey"
        let value = "Hello 世界 🌍 مرحبا"

        // When
        try sut.setString(value, forKey: key)

        // Then
        let retrieved = try sut.getString(forKey: key)
        XCTAssertEqual(retrieved, value)
    }

    // MARK: - Thread Safety Tests

    func testConcurrentAccess() throws {
        let expectation = XCTestExpectation(description: "Concurrent operations complete")
        expectation.expectedFulfillmentCount = 100

        let queue = DispatchQueue(label: "test.concurrent", attributes: .concurrent)

        // When - perform 100 concurrent operations
        for i in 0..<100 {
            queue.async {
                do {
                    try self.sut.setString("value\(i)", forKey: "key\(i)")
                    expectation.fulfill()
                } catch {
                    XCTFail("Concurrent operation failed: \(error)")
                }
            }
        }

        // Then
        wait(for: [expectation], timeout: 10.0)

        // Verify all items were saved
        let keys = try sut.allKeys()
        XCTAssertEqual(keys.count, 100)
    }
}
