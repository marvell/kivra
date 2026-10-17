import XCTest

@testable import Kivra

final class ApplicationIdentityTests: XCTestCase {
    func testStableIdentityUsesProductionConfiguration() {
        let identity = ApplicationIdentity(infoDictionary: [
            "CFBundleDisplayName": "Kivra",
            "KivraBuildVariant": "stable",
            "CFBundleShortVersionString": "0.6.0",
        ])

        XCTAssertEqual(identity.displayName, "Kivra")
        XCTAssertEqual(identity.variant, .stable)
        XCTAssertEqual(identity.version, "0.6.0")
        XCTAssertFalse(identity.isDevelopment)
    }

    func testDevelopmentIdentityIsSeparateAndVisible() {
        let identity = ApplicationIdentity(infoDictionary: [
            "CFBundleDisplayName": "Kivra Dev",
            "KivraBuildVariant": "dev",
        ])

        XCTAssertEqual(identity.displayName, "Kivra Dev")
        XCTAssertEqual(identity.variant, .dev)
        XCTAssertTrue(identity.isDevelopment)
    }

    func testMissingVariantFallsBackToStable() {
        let identity = ApplicationIdentity(infoDictionary: [:])

        XCTAssertEqual(identity.displayName, "Kivra")
        XCTAssertEqual(identity.variant, .stable)
        XCTAssertNil(identity.version)
    }
}
