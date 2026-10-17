import XCTest

@testable import Kivra

final class GreetingTests: XCTestCase {
    func testKnownLanguagesUseGreeting() {
        XCTAssertEqual(Greeting.word(forLanguage: "en", layoutName: "ABC"), "Hello")
        XCTAssertEqual(Greeting.word(forLanguage: "ru", layoutName: "Russian"), "Привет")
    }

    func testRegionalCodesUseBaseLanguage() {
        XCTAssertEqual(Greeting.word(forLanguage: "pt-BR", layoutName: "Brazilian"), "Olá")
    }

    func testUnknownLanguageUsesItsOwnName() {
        XCTAssertEqual(Greeting.word(forLanguage: "is", layoutName: "Icelandic"), "íslenska")
    }

    func testMissingLanguageUsesLayoutName() {
        XCTAssertEqual(Greeting.word(forLanguage: nil, layoutName: "Dvorak"), "Dvorak")
    }
}
