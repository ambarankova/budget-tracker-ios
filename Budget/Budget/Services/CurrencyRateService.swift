import Foundation

protocol CurrencyRateService: AnyObject {
    // Returns RUB-per-unit rates for each supported currency on the given date.
    func rates(for date: Date) async throws -> [String: Double]
}

// Thread-safe implementation backed by the CBR XML API.
// Using `actor` eliminates the isRatesLoading bool flag and its race condition.
actor CBRCurrencyRateService: CurrencyRateService {

    static let shared = CBRCurrencyRateService()

    private var cache: [String: [String: Double]] = [:]

    nonisolated func rates(for date: Date) async throws -> [String: Double] {
        try await _rates(for: date)
    }

    private func _rates(for date: Date) async throws -> [String: Double] {
        let key = CurrencyConverter.dateKey(for: date)
        if let cached = cache[key] { return cached }

        let cbrDate = Self.cbrDateString(date)
        guard let url = URL(string: "https://www.cbr.ru/scripts/XML_daily.asp?date_req=\(cbrDate)") else {
            throw URLError(.badURL)
        }

        let (data, _) = try await URLSession.shared.data(from: url)
        let allRates = XMLRatesParser().parse(data: data)

        var filtered: [String: Double] = [AppCurrency.RUB.rawValue: 1.0]
        for currency in AppCurrency.mainCurrencies where currency != .RUB {
            if let rate = allRates[currency.rawValue] {
                filtered[currency.rawValue] = rate
            }
        }

        cache[key] = filtered
        return filtered
    }

    private static func cbrDateString(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "dd/MM/yyyy"
        return f.string(from: date)
    }
}

// MARK: - XML Parser

private final class XMLRatesParser: NSObject, XMLParserDelegate {
    private var buffer = ""
    private var currentCharCode: String?
    private var currentNominal: Int?
    private var currentValue: Double?
    private(set) var result: [String: Double] = [:]

    func parse(data: Data) -> [String: Double] {
        let parser = XMLParser(data: data)
        parser.delegate = self
        _ = parser.parse()
        return result
    }

    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName: String?, attributes: [String: String] = [:]) {
        buffer = ""
        if elementName == "Valute" {
            currentCharCode = nil
            currentNominal  = nil
            currentValue    = nil
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        buffer += string
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName: String?) {
        let trimmed = buffer.trimmingCharacters(in: .whitespacesAndNewlines)
        switch elementName {
        case "CharCode":
            currentCharCode = trimmed
        case "Nominal":
            currentNominal = Int(trimmed.replacingOccurrences(of: ",", with: "."))
        case "Value":
            currentValue = Double(trimmed.replacingOccurrences(of: ",", with: "."))
        case "Valute":
            if let code = currentCharCode,
               let nominal = currentNominal,
               let value = currentValue,
               nominal != 0 {
                result[code] = value / Double(nominal)
            }
        default:
            break
        }
    }
}
