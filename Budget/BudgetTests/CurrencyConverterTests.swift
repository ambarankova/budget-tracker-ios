import XCTest

final class CurrencyConverterTests: XCTestCase {

    // USD→RUB: 90 RUB per 1 USD
    private let rates: [String: Double] = [
        "USD": 90.0,
        "EUR": 100.0,
    ]

    // MARK: - Same currency

    func test_convert_sameCurrency_returnsUnchanged() {
        let result = CurrencyConverter.convert(5000, from: "RUB", to: "RUB", rates: rates)
        XCTAssertEqual(result, 5000)
    }

    func test_convert_sameForeignCurrency_returnsUnchanged() {
        let result = CurrencyConverter.convert(200, from: "USD", to: "USD", rates: rates)
        XCTAssertEqual(result, 200)
    }

    // MARK: - Cross-currency

    func test_convert_usdToRub() {
        // 100 USD × 90 = 9000 RUB
        let result = CurrencyConverter.convert(100, from: "USD", to: "RUB", rates: rates)
        XCTAssertEqual(result, 9000)
    }

    func test_convert_rubToUsd() {
        // 9000 RUB / 90 = 100 USD
        let result = CurrencyConverter.convert(9000, from: "RUB", to: "USD", rates: rates)
        XCTAssertEqual(result, 100)
    }

    func test_convert_usdToEur() {
        // 100 USD × 90 / 100 = 90 EUR
        let result = CurrencyConverter.convert(100, from: "USD", to: "EUR", rates: rates)
        XCTAssertEqual(result, 90)
    }

    // MARK: - Missing rate

    func test_convert_missingRate_returnsAmountUnchanged() {
        let result = CurrencyConverter.convert(500, from: "GBP", to: "RUB", rates: rates)
        XCTAssertEqual(result, 500)
    }

    func test_convert_emptyRates_returnsAmountUnchanged() {
        let result = CurrencyConverter.convert(500, from: "USD", to: "RUB", rates: [:])
        XCTAssertEqual(result, 500)
    }

    // MARK: - toRUB

    func test_toRUB_fromUSD() {
        let result = CurrencyConverter.toRUB(50, from: "USD", rates: rates)
        XCTAssertEqual(result, 4500)
    }

    func test_toRUB_fromRUB_returnsUnchanged() {
        let result = CurrencyConverter.toRUB(300, from: "RUB", rates: rates)
        XCTAssertEqual(result, 300)
    }
}
