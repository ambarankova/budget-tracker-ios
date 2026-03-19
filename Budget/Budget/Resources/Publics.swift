import Foundation
import SwiftUI

enum AppLayout {
    static let screenHorizontalPadding: CGFloat = 16
}

enum AppCurrency: String, CaseIterable, Identifiable {
    case RUB
    case USD
    case EUR
    case GBP
    case CNY

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .RUB: return "Рубль"
        case .USD: return "Доллар"
        case .EUR: return "Евро"
        case .GBP: return "Фунт"
        case .CNY: return "Юань"
        }
    }

    var symbol: String {
        switch self {
        case .RUB: return "₽"
        case .USD: return "$"
        case .EUR: return "€"
        case .GBP: return "£"
        case .CNY: return "¥"
        }
    }

    static var mainCurrencies: [AppCurrency] { [.RUB, .USD, .EUR, .GBP, .CNY] }

    static func normalize(_ raw: String) -> String {
        // Legacy: previously currency was stored as Russian "Рубль"
        if raw == "Рубль" { return AppCurrency.RUB.rawValue }
        return raw
    }

    static func displayName(for code: String) -> String {
        guard let currency = AppCurrency(rawValue: code) else { return code }
        return currency.displayName
    }

    static func symbol(for code: String) -> String {
        guard let currency = AppCurrency(rawValue: code) else { return "₽" }
        return currency.symbol
    }
}

enum AppSettingsCurrency {
    private static let currencyStorageKey = "budget.settings.currency.v1"

    static func loadBaseCurrencyCode() -> String {
        UserDefaults.standard.string(forKey: currencyStorageKey) ?? AppCurrency.RUB.rawValue
    }

    static func saveBaseCurrencyCode(_ code: String) {
        UserDefaults.standard.set(code, forKey: currencyStorageKey)
    }
}

enum CBRCurrencyRates {
    // Cache: dateKey -> (currencyCode -> rubPerUnit)
    private static var cache: [String: [String: Double]] = [:]

    private final class Parser: NSObject, XMLParserDelegate {
        private var buffer: String = ""
        private var currentCharCode: String?
        private var currentNominal: Int?
        private var currentValue: Double?
        private var result: [String: Double] = [:]

        func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes: [String: String] = [:]) {
            buffer = ""
            if elementName == "Valute" {
                currentCharCode = nil
                currentNominal = nil
                currentValue = nil
            }
        }

        func parser(_ parser: XMLParser, foundCharacters string: String) {
            buffer += string
        }

        func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
            let trimmed = buffer.trimmingCharacters(in: .whitespacesAndNewlines)
            switch elementName {
            case "CharCode":
                currentCharCode = trimmed
            case "Nominal":
                currentNominal = Int(trimmed.replacingOccurrences(of: ",", with: "."))
            case "Value":
                let normalized = trimmed.replacingOccurrences(of: ",", with: ".")
                currentValue = Double(normalized)
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

        func parse(data: Data) -> [String: Double] {
            let parser = XMLParser(data: data)
            parser.delegate = self
            _ = parser.parse()
            return result
        }
    }

    private static func dateKey(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar.current
        formatter.timeZone = TimeZone.current
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    private static func cbrDateString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar.current
        formatter.timeZone = TimeZone.current
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "dd/MM/yyyy"
        return formatter.string(from: date)
    }

    // 1 unit of currencyCode equals `rubPerUnit` RUB on the given date.
    static func fetchRubPerUnitByDate(_ date: Date) async throws -> [String: Double] {
        let key = dateKey(date)
        if let cached = cache[key] { return cached }

        let cbrDate = cbrDateString(date) // dd/MM/yyyy
        guard let url = URL(string: "https://www.cbr.ru/scripts/XML_daily.asp?date_req=\(cbrDate)") else {
            throw URLError(.badURL)
        }

        let (data, _) = try await URLSession.shared.data(from: url)
        let parser = Parser()
        let allRates = parser.parse(data: data)

        var filtered: [String: Double] = [:]
        for currency in AppCurrency.mainCurrencies {
            let code = currency.rawValue
            if code == AppCurrency.RUB.rawValue {
                filtered[code] = 1.0
            } else if let rate = allRates[code] {
                filtered[code] = rate
            }
        }

        cache[key] = filtered
        return filtered
    }
}

enum AppMoney {
    // Money is stored in cents (minor units).
    private static let fractionDigits = 2

    static func normalizeInput(_ text: String) -> String {
        // Keep digits and a single separator (`,` or `.`).
        let cleaned = text
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: ".", with: ",")

        var result = ""
        var hasSeparator = false
        var digitsAfterSeparator = 0

        for ch in cleaned {
            if ch.isWholeNumber {
                if hasSeparator {
                    if digitsAfterSeparator < fractionDigits {
                        result.append(ch)
                        digitsAfterSeparator += 1
                    }
                } else {
                    result.append(ch)
                }
            } else if ch == "," && !hasSeparator {
                hasSeparator = true
                result.append(ch)
            }
        }

        // UX: avoid output like ",5"
        if result.first == "," {
            result = "0" + result
        }
        return result
    }

    static func parseToCents(_ text: String) -> Int? {
        let normalized = normalizeInput(text)
        guard !normalized.isEmpty else { return nil }

        let normalizedDot = normalized.replacingOccurrences(of: ",", with: ".")
        // Handle trailing separator: "10," => "10"
        let trimmed = normalizedDot.hasSuffix(".") ? String(normalizedDot.dropLast()) : normalizedDot
        guard !trimmed.isEmpty else { return nil }

        let decimal = Decimal(string: trimmed, locale: Locale(identifier: "en_US_POSIX"))
        guard let decimal else { return nil }

        let centsDecimal = decimal * pow10(fractionDigits)
        let nsDecimal = NSDecimalNumber(decimal: centsDecimal)
        let handler = NSDecimalNumberHandler(
            roundingMode: .plain,
            scale: 0,
            raiseOnExactness: false,
            raiseOnOverflow: false,
            raiseOnUnderflow: false,
            raiseOnDivideByZero: false
        )
        let rounded = nsDecimal.rounding(accordingToBehavior: handler)
        return rounded.intValue
    }

    static func formatCentsForInput(_ cents: Int) -> String {
        let decimal = Decimal(cents) / pow10(fractionDigits)
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "ru_RU_POSIX")
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = " "
        formatter.maximumFractionDigits = fractionDigits
        formatter.minimumFractionDigits = 0
        return formatter.string(from: NSDecimalNumber(decimal: decimal)) ?? "\(cents)"
    }

    static func formatCentsForDisplay(_ cents: Int, currencySymbol: String) -> String {
        formatCentsForInput(cents) + " " + currencySymbol
    }

    private static func pow10(_ n: Int) -> Decimal {
        var result: Decimal = 1
        for _ in 0..<n { result *= 10 }
        return result
    }
}
