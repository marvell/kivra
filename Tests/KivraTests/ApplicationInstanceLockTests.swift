import Foundation
import XCTest

@testable import Kivra

final class ApplicationInstanceLockTests: XCTestCase {
    func testOnlyOneInstanceCanHoldLock() {
        let testDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("kivra-test-\(UUID().uuidString)", isDirectory: true)
        let lockURL =
            testDirectory
            .appendingPathComponent("nested", isDirectory: true)
            .appendingPathComponent("instance.lock")
        var firstLock = try? ApplicationInstanceLock(fileURL: lockURL)

        XCTAssertNotNil(firstLock)
        XCTAssertTrue(FileManager.default.fileExists(atPath: lockURL.path))
        XCTAssertThrowsError(try ApplicationInstanceLock(fileURL: lockURL)) { error in
            guard case ApplicationInstanceLock.LockError.alreadyHeld = error else {
                return XCTFail("Expected alreadyHeld, got \(error)")
            }
        }

        firstLock = nil
        XCTAssertNoThrow(try ApplicationInstanceLock(fileURL: lockURL))
        try? FileManager.default.removeItem(at: testDirectory)
    }
}
