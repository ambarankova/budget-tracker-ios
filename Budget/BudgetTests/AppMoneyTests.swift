import XCTest

final class AppMoneyTests: XCTestCase {

    // MARK: - parseToCents

    func test_parseToCents_integerInput() {
        XCTAssertEqual(AppMoney.parseToCents("100"), 10000)
        XCTAssertEqual(AppMoney.parseToCents("0"), 0)
        XCTAssertEqual(AppMoney.parseToCents("1"), 100)
    }

    func test_parseToCents_decimalInput() {
        XCTAssertEqual(AppMoney.parseToCents("100,50"), 10050)
        XCTAssertEqual(AppMoney.parseToCents("99.9"),  9990)
        XCTAssertEqual(AppMoney.parseToCents("0,01"),  1)
    }

    func test_parseToCents_emptyOrInvalid_returnsNil() {
        XCTAssertNil(AppMoney.parseToCents(""))
        XCTAssertNil(AppMoney.parseToCents("abc"))
        XCTAssertNil(AppMoney.parseToCents("---"))
    }

    func test_parseToCents_trailingComma() {
        // "10," should parse as 10 whole units = 1000 cents
        XCTAssertEqual(AppMoney.parseToCents("10,"), 1000)
    }

    // MARK: - formatCentsForInput

    func test_formatCentsForInput_roundTrip() {
        XCTAssertEqual(AppMoney.formatCentsForInput(10000), "100")
        XCTAssertEqual(AppMoney.formatCentsForInput(10050), "100,5")
        XCTAssertEqual(AppMoney.formatCentsForInput(1),     "0,01")
        XCTAssertEqual(AppMoney.formatCentsForInput(0),     "0")
    }

    func test_formatCentsForInput_thousandsSeparator() {
        let result = AppMoney.formatCentsForInput(1_000_000_00)
        // 1 000 000,00 — should contain grouping separator
        XCTAssertTrue(result.contains(" "), "Expected thousands separator in '\(result)'")
    }

    // MARK: - normalizeInput

    func test_normalizeInput_stripSpacesAndConvertDot() {
        XCTAssertEqual(AppMoney.normalizeInput("1 000.50"), "1000,50")
    }

    func test_normalizeInput_limitsFractionDigits() {
        // More than 2 decimal places — only first 2 kept
        XCTAssertEqual(AppMoney.normalizeInput("1,999"), "1,99")
    }

    func test_normalizeInput_leadingSeparatorGetsPrefixedWithZero() {
        XCTAssertEqual(AppMoney.normalizeInput(",5"), "0,5")
    }
}
