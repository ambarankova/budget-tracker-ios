import Foundation
import SwiftUI

// View-layer DTO for one category's annual breakdown.
struct CategoryYearSummary: Identifiable {
    let id = UUID()
    let name: String
    let monthlyFact: [Int: Int]
    let plan: Int
    var yearTotal: Int { monthlyFact.values.reduce(0, +) }
}

// View-layer DTO for a pie/bar chart category segment.
struct ChartCategoryValue: Identifiable {
    let id = UUID()
    let category: String
    let amount: Int
    let color: Color
}

// View-layer DTO for monthly income-expense delta.
struct MonthlyDeltaValue: Identifiable {
    var id: Int { monthIndex }
    let monthIndex: Int
    let monthName: String
    let delta: Int
}

@MainActor
final class AnalyticsViewModel: ObservableObject {

    // MARK: - Dependencies

    private let transactionRepo: TransactionRepository
    private let currencyService: CurrencyRateService

    // MARK: - Published state

    @Published private(set) var categoryRows: [CategoryYearSummary] = []
    @Published private(set) var chartValues: [ChartCategoryValue] = []
    @Published private(set) var deltaByMonth: [MonthlyDeltaValue] = []
    @Published private(set) var hasDataByMonth: [Int: Bool] = [:]
    @Published private(set) var baseCurrencyCode: String
    @Published private(set) var isLoading = false
    @Published var selectedYear: Int
    @Published var displayMode: FinanceMode = .expense

    // MARK: - Computed

    var baseCurrencySymbol: String { AppCurrency.symbol(for: baseCurrencyCode) }

    var availableYears: [Int] {
        let expenseYears = transactionRepo.loadTransactions(for: .expense).map { Calendar.current.component(.year, from: $0.date) }
        let incomeYears  = transactionRepo.loadTransactions(for: .income).map  { Calendar.current.component(.year, from: $0.date) }
        let years = Set(expenseYears + incomeYears)
        let sorted = years.sorted(by: >)
        return sorted.isEmpty ? [Calendar.current.component(.year, from: Date())] : sorted
    }

    var totalPlan: Int { categoryRows.reduce(0) { $0 + $1.plan } }

    func formattedAmount(_ cents: Int) -> String {
        AppMoney.formatCentsForDisplay(cents, currencySymbol: baseCurrencySymbol)
    }

    func formattedAmountInput(_ text: String) -> String {
        let normalized = AppMoney.normalizeInput(text)
        guard let cents = AppMoney.parseToCents(normalized) else { return normalized }
        return AppMoney.formatCentsForInput(cents)
    }

    func monthValues(for row: CategoryYearSummary) -> [String] {
        let months = (1...12).map { month -> String in
            guard hasDataByMonth[month] == true else { return "—" }
            return formattedAmount(row.monthlyFact[month] ?? 0)
        }
        return months + [formattedAmount(row.yearTotal)]
    }

    func totalMonthValues() -> [String] {
        let months = (1...12).map { month -> String in
            guard hasDataByMonth[month] == true else { return "—" }
            let total = categoryRows.reduce(0) { $0 + ($1.monthlyFact[month] ?? 0) }
            return formattedAmount(total)
        }
        let grandTotal = categoryRows.reduce(0) { $0 + $1.yearTotal }
        return months + [formattedAmount(grandTotal)]
    }

    // MARK: - Private

    private var ratesByDateKey: [String: [String: Double]] = [:]

    private var planConversionDate: Date {
        Calendar.current.date(from: DateComponents(year: selectedYear, month: 1, day: 1)) ?? Date()
    }

    // MARK: - Init

    init(
        transactionRepo: TransactionRepository,
        currencyService: CurrencyRateService
    ) {
        self.transactionRepo = transactionRepo
        self.currencyService = currencyService
        self.baseCurrencyCode = AppCurrency.normalize(AppSettingsCurrency.loadBaseCurrencyCode())
        self.selectedYear = Calendar.current.component(.year, from: Date())
    }

    // MARK: - Lifecycle

    func onAppear() {
        selectedYear = availableYears.first ?? selectedYear
        Task {
            await refreshRates()
            recalculate()
        }
    }

    func onYearOrModeChanged() {
        Task {
            await refreshRates()
            recalculate()
        }
    }

    func onSettingsDismissed() {
        let updated = AppCurrency.normalize(AppSettingsCurrency.loadBaseCurrencyCode())
        guard updated != baseCurrencyCode else { return }
        baseCurrencyCode = updated
        Task {
            await refreshRates()
            recalculate()
        }
    }

    // MARK: - Category rename (proxied to storage)

    func renameCategory(from oldName: String, to newName: String) {
        for mode in [FinanceMode.expense, FinanceMode.income] {
            var txs = transactionRepo.loadTransactions(for: mode)
            for i in txs.indices where txs[i].category == oldName {
                txs[i] = Transaction(id: txs[i].id, category: newName, amount: txs[i].amount, date: txs[i].date, currency: txs[i].currency)
            }
            transactionRepo.saveTransactions(txs, for: mode)

            var plans = transactionRepo.loadCategoryPlans(for: mode)
            if let planValue = plans.removeValue(forKey: oldName) {
                plans[newName] = planValue
                transactionRepo.saveCategoryPlans(plans, for: mode)
            }

            var names = transactionRepo.loadCategoryNames(for: mode)
            if let idx = names.firstIndex(of: oldName) {
                names[idx] = newName
                transactionRepo.saveCategoryNames(names, for: mode)
            }
        }
        recalculate()
    }

    func updateCategoryPlan(name: String, planInBaseCurrency: Int) {
        var plans = transactionRepo.loadCategoryPlans(for: displayMode)
        plans[name] = CurrencyConverter.toRUB(
            planInBaseCurrency, from: baseCurrencyCode, rates: ratesByDateKey[CurrencyConverter.dateKey(for: planConversionDate)] ?? [:]
        )
        transactionRepo.saveCategoryPlans(plans, for: displayMode)
        recalculate()
    }

    // MARK: - Recalculate

    func recalculate() {
        let cal = Calendar.current
        let transactions = transactionRepo.loadTransactions(for: displayMode)
            .filter { cal.component(.year, from: $0.date) == selectedYear }

        let monthGroups = Dictionary(grouping: transactions) { cal.component(.month, from: $0.date) }
        hasDataByMonth = Dictionary(uniqueKeysWithValues: (1...12).map { ($0, !(monthGroups[$0] ?? []).isEmpty) })

        var monthlyByCat: [String: [Int: Int]] = [:]
        for (month, txs) in monthGroups {
            let byCat = Dictionary(grouping: txs, by: \.category).mapValues { list in
                list.reduce(0) { sum, tx in
                    sum + convert(tx.amount, from: tx.currency, on: tx.date)
                }
            }
            for (cat, amount) in byCat {
                monthlyByCat[cat, default: [:]][month] = amount
            }
        }

        let storedPlansRUB  = transactionRepo.loadCategoryPlans(for: displayMode)
        let catsFromData    = Set(transactions.map(\.category))
        let catsFromPlans   = Set(storedPlansRUB.keys)
        let allCats         = Array(catsFromData.union(catsFromPlans)).sorted()

        let planDate   = planConversionDate
        let planRates  = ratesByDateKey[CurrencyConverter.dateKey(for: planDate)] ?? [:]

        categoryRows = allCats.map { name in
            CategoryYearSummary(
                name: name,
                monthlyFact: monthlyByCat[name] ?? [:],
                plan: CurrencyConverter.convert(storedPlansRUB[name] ?? 0, from: AppCurrency.RUB.rawValue, to: baseCurrencyCode, rates: planRates)
            )
        }

        recalculateChartValues(from: transactions)
        recalculateDeltaByMonth()
    }

    // MARK: - Private: charts

    private func recalculateChartValues(from transactions: [Transaction]) {
        let grouped = Dictionary(grouping: transactions, by: \.category).mapValues { list in
            list.reduce(0) { sum, tx in sum + convert(tx.amount, from: tx.currency, on: tx.date) }
        }
        let palette: [Color] = [
            Color(.green),
            Color(red: 0.16, green: 0.60, blue: 0.45),
            Color(.gray),
            Color(red: 0.21, green: 0.43, blue: 0.37),
            Color(red: 0.55, green: 0.58, blue: 0.60),
            Color(red: 0.11, green: 0.33, blue: 0.28)
        ]
        chartValues = grouped.keys.sorted().enumerated().map { idx, key in
            ChartCategoryValue(category: key, amount: grouped[key] ?? 0, color: palette[idx % palette.count])
        }
    }

    private func recalculateDeltaByMonth() {
        let cal = Calendar.current
        let expenses = transactionRepo.loadTransactions(for: .expense).filter { cal.component(.year, from: $0.date) == selectedYear }
        let incomes  = transactionRepo.loadTransactions(for: .income) .filter { cal.component(.year, from: $0.date) == selectedYear }

        let expByMonth = Dictionary(grouping: expenses) { cal.component(.month, from: $0.date) }
            .mapValues { list in list.reduce(0) { sum, tx in sum + convert(tx.amount, from: tx.currency, on: tx.date) } }
        let incByMonth = Dictionary(grouping: incomes)  { cal.component(.month, from: $0.date) }
            .mapValues { list in list.reduce(0) { sum, tx in sum + convert(tx.amount, from: tx.currency, on: tx.date) } }

        let monthNames: [String] = {
            var f = DateFormatter(); f.locale = Locale.current; return f.monthSymbols
        }()
        deltaByMonth = (1...12).map { month in
            MonthlyDeltaValue(
                monthIndex: month,
                monthName: monthNames[month - 1],
                delta: (incByMonth[month] ?? 0) - (expByMonth[month] ?? 0)
            )
        }
    }

    // MARK: - Private: currency

    private func convert(_ amount: Int, from currency: String, on date: Date) -> Int {
        CurrencyConverter.convert(
            amount, from: currency, to: baseCurrencyCode,
            rates: ratesByDateKey[CurrencyConverter.dateKey(for: date)] ?? [:]
        )
    }

    private func refreshRates() async {
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }

        let cal = Calendar.current
        let startOfYear = cal.startOfDay(for: planConversionDate)

        let expenseTxs = transactionRepo.loadTransactions(for: .expense).filter { cal.component(.year, from: $0.date) == selectedYear }
        let incomeTxs  = transactionRepo.loadTransactions(for: .income) .filter { cal.component(.year, from: $0.date) == selectedYear }

        var days = Set<Date>()
        if baseCurrencyCode != AppCurrency.RUB.rawValue { days.insert(startOfYear) }
        for tx in (expenseTxs + incomeTxs) where AppCurrency.normalize(tx.currency) != baseCurrencyCode {
            days.insert(cal.startOfDay(for: tx.date))
        }

        for day in days {
            let key = CurrencyConverter.dateKey(for: day)
            guard ratesByDateKey[key] == nil else { continue }
            do { ratesByDateKey[key] = try await currencyService.rates(for: day) }
            catch { ratesByDateKey[key] = [AppCurrency.RUB.rawValue: 1.0] }
        }
    }
}
