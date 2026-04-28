import Foundation

enum CurrencyConverter {

    // Reusable formatter — creating DateFormatter is expensive, so it's static.
    static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.calendar = Calendar.current
        f.timeZone = TimeZone.current
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    static func dateKey(for date: Date) -> String {
        dateFormatter.string(from: date)
    }

    // Convert `amount` from one currency to another using the provided CBR rates map
    // (rates map: currencyCode → RUB per 1 unit of that currency).
    // Returns `amount` unchanged if conversion data is unavailable.
    static func convert(
        _ amount: Int,
        from rawFrom: String,
        to rawTo: String,
        rates: [String: Double]
    ) -> Int {
        let fromCode = AppCurrency.normalize(rawFrom)
        let toCode   = AppCurrency.normalize(rawTo)
        guard fromCode != toCode else { return amount }

        let rubPerFrom = rubRate(for: fromCode, in: rates)
        let rubPerTo   = rubRate(for: toCode,   in: rates)

        guard let pf = rubPerFrom, let pt = rubPerTo, pt != 0 else { return amount }
        return Int((Double(amount) * pf / pt).rounded())
    }

    // Convert `amount` from a given currency into RUB.
    static func toRUB(_ amount: Int, from rawFrom: String, rates: [String: Double]) -> Int {
        let fromCode = AppCurrency.normalize(rawFrom)
        guard fromCode != AppCurrency.RUB.rawValue else { return amount }
        guard let rate = rates[fromCode] else { return amount }
        return Int((Double(amount) * rate).rounded())
    }

    // MARK: - Private

    private static func rubRate(for code: String, in rates: [String: Double]) -> Double? {
        if code == AppCurrency.RUB.rawValue { return 1.0 }
        return rates[code]
    }
}
