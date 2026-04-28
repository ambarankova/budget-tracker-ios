import Foundation
import Combine

@MainActor
final class FinanceDashboardViewModel: ObservableObject {

    let mode: FinanceMode

    // MARK: - Dependencies

    private let transactionRepo: TransactionRepository
    private let currencyService: CurrencyRateService

    // MARK: - Published state

    @Published private(set) var categories: [Category] = []
    @Published private(set) var transactions: [Transaction] = []
    @Published private(set) var ratesByDateKey: [String: [String: Double]] = [:]
    @Published private(set) var baseCurrencyCode: String
    @Published private(set) var isRatesLoading = false
    @Published var selectedMonth: Int
    @Published var selectedYear: Int

    // MARK: - Computed view data

    var baseCurrencySymbol: String {
        AppCurrency.symbol(for: baseCurrencyCode)
    }

    var selectedDate: Date {
        Calendar.current.date(from: DateComponents(year: selectedYear, month: selectedMonth, day: 1)) ?? Date()
    }

    var categorySummaries: [CategorySummary] {
        let date = selectedDate
        let planRates = rates(on: date)
        let factByCategory = Dictionary(
            grouping: currentMonthTransactions,
            by: \.category
        ).mapValues { list in
            list.reduce(0) { sum, tx in
                sum + CurrencyConverter.convert(tx.amount, from: tx.currency, to: baseCurrencyCode, rates: rates(on: tx.date))
            }
        }
        return categories.map { category in
            CategorySummary(
                id: category.id,
                name: category.name,
                plan: CurrencyConverter.convert(category.planRUB, from: AppCurrency.RUB.rawValue, to: baseCurrencyCode, rates: planRates),
                fact: factByCategory[category.name] ?? 0
            )
        }
    }

    var totalPlan: Int { categorySummaries.reduce(0) { $0 + $1.plan } }
    var totalFact: Int { categorySummaries.reduce(0) { $0 + $1.fact } }

    // Current month's transactions converted to the display currency.
    var displayTransactions: [Transaction] {
        currentMonthTransactions.map { tx in
            Transaction(
                id: tx.id,
                category: tx.category,
                amount: CurrencyConverter.convert(tx.amount, from: tx.currency, to: baseCurrencyCode, rates: rates(on: tx.date)),
                date: tx.date,
                currency: baseCurrencyCode
            )
        }
    }

    // Income minus expense for the selected month.
    var globalDelta: Int {
        let expenseTxs = mode == .expense ? transactions : transactionRepo.loadTransactions(for: .expense)
        let incomeTxs  = mode == .income  ? transactions : transactionRepo.loadTransactions(for: .income)
        return factTotal(from: incomeTxs) - factTotal(from: expenseTxs)
    }

    var categoryNames: [String] { categories.map(\.name) }

    var currentMonthTransactions: [Transaction] {
        let cal = Calendar.current
        return transactions
            .filter {
                cal.isDate($0.date, equalTo: selectedDate, toGranularity: .month) &&
                cal.isDate($0.date, equalTo: selectedDate, toGranularity: .year)
            }
            .sorted { $0.date < $1.date }
    }

    // MARK: - Init

    init(
        mode: FinanceMode,
        transactionRepo: TransactionRepository = UserDefaultsTransactionRepository.shared,
        currencyService: CurrencyRateService = CBRCurrencyRateService.shared
    ) {
        self.mode = mode
        self.transactionRepo = transactionRepo
        self.currencyService = currencyService
        self.baseCurrencyCode = AppCurrency.normalize(AppSettingsCurrency.loadBaseCurrencyCode())
        let now = Date()
        self.selectedMonth = Calendar.current.component(.month, from: now)
        self.selectedYear  = Calendar.current.component(.year,  from: now)
    }

    // MARK: - Lifecycle

    func onAppear() {
        loadTransactions()
        loadCategories()
        Task { await refreshRatesForSelectedMonth() }
    }

    func onSelectedMonthChanged() {
        Task { await refreshRatesForSelectedMonth() }
    }

    // Call this after the settings sheet is dismissed to react to currency changes.
    func onSettingsDismissed() {
        let updated = AppCurrency.normalize(AppSettingsCurrency.loadBaseCurrencyCode())
        guard updated != baseCurrencyCode else { return }
        baseCurrencyCode = updated
        Task { await refreshRatesForSelectedMonth() }
    }

    // MARK: - Transactions

    func addTransaction(amount: Int, category: String, date: Date, currency: String) async {
        let tx = Transaction(category: category, amount: amount, date: date, currency: currency)
        transactions.append(tx)
        saveTransactions()
        if AppCurrency.normalize(currency) != baseCurrencyCode {
            await refreshRatesForDates([date])
        }
    }

    func deleteTransaction(id: UUID) {
        transactions.removeAll { $0.id == id }
        saveTransactions()
    }

    func updateTransaction(id: UUID, category: String, date: Date, amount: Int) async {
        guard let index = transactions.firstIndex(where: { $0.id == id }) else { return }
        let storedCurrency = AppCurrency.normalize(transactions[index].currency)

        let amountToStore: Int
        if storedCurrency == baseCurrencyCode {
            amountToStore = amount
        } else {
            let key = CurrencyConverter.dateKey(for: date)
            if ratesByDateKey[key] == nil {
                do { ratesByDateKey[key] = try await currencyService.rates(for: date) }
                catch { ratesByDateKey[key] = [AppCurrency.RUB.rawValue: 1.0] }
            }
            amountToStore = CurrencyConverter.convert(
                amount, from: baseCurrencyCode, to: storedCurrency, rates: ratesByDateKey[key] ?? [:]
            )
        }

        transactions[index] = Transaction(
            id: id, category: category, amount: amountToStore, date: date, currency: transactions[index].currency
        )
        saveTransactions()
    }

    // MARK: - Categories

    func addCategory(name: String) {
        guard !categories.contains(where: { $0.name == name }) else { return }
        categories.append(Category(name: name))
        saveCategories()
    }

    func deleteCategory(name: String) {
        categories.removeAll { $0.name == name }
        transactions.removeAll { $0.category == name }
        saveTransactions()
        saveCategories()
    }

    func renameCategory(from oldName: String, to newName: String) {
        guard let index = categories.firstIndex(where: { $0.name == oldName }),
              !categories.contains(where: { $0.name == newName }) else { return }
        categories[index] = Category(id: categories[index].id, name: newName, planRUB: categories[index].planRUB)
        for i in transactions.indices where transactions[i].category == oldName {
            transactions[i] = Transaction(
                id: transactions[i].id, category: newName,
                amount: transactions[i].amount, date: transactions[i].date, currency: transactions[i].currency
            )
        }
        saveCategories()
        saveTransactions()
        saveCategoryPlans()
    }

    // planInBaseCurrency is in the currently selected display currency (cents).
    func updateCategoryPlan(name: String, planInBaseCurrency: Int) {
        guard let index = categories.firstIndex(where: { $0.name == name }) else { return }
        categories[index].planRUB = CurrencyConverter.toRUB(
            planInBaseCurrency, from: baseCurrencyCode, rates: rates(on: selectedDate)
        )
        saveCategoryPlans()
    }

    // MARK: - Private: persistence

    private func loadTransactions() {
        transactions = transactionRepo.loadTransactions(for: mode)
    }

    private func saveTransactions() {
        transactionRepo.saveTransactions(transactions, for: mode)
    }

    private func loadCategories() {
        let names = transactionRepo.loadCategoryNames(for: mode)
        let plans = transactionRepo.loadCategoryPlans(for: mode)

        if !names.isEmpty {
            categories = names.map { Category(name: $0, planRUB: plans[$0] ?? 0) }
            return
        }
        // Bootstrap order from existing transaction data + plan keys.
        let fromTxs   = Set(transactions.map(\.category))
        let fromPlans = Set(plans.keys)
        let sorted    = Array(fromTxs.union(fromPlans)).sorted()
        categories = sorted.map { Category(name: $0, planRUB: plans[$0] ?? 0) }
        if !sorted.isEmpty { saveCategories() }
    }

    private func saveCategories() {
        transactionRepo.saveCategoryNames(categories.map(\.name), for: mode)
    }

    private func saveCategoryPlans() {
        let plans = Dictionary(uniqueKeysWithValues: categories.map { ($0.name, $0.planRUB) })
        transactionRepo.saveCategoryPlans(plans, for: mode)
    }

    // MARK: - Private: currency rates

    private func rates(on date: Date) -> [String: Double] {
        ratesByDateKey[CurrencyConverter.dateKey(for: date)] ?? [:]
    }

    private func factTotal(from txs: [Transaction]) -> Int {
        let cal = Calendar.current
        return txs
            .filter {
                cal.isDate($0.date, equalTo: selectedDate, toGranularity: .month) &&
                cal.isDate($0.date, equalTo: selectedDate, toGranularity: .year)
            }
            .reduce(0) { sum, tx in
                sum + CurrencyConverter.convert(tx.amount, from: tx.currency, to: baseCurrencyCode, rates: rates(on: tx.date))
            }
    }

    func refreshRatesForSelectedMonth() async {
        guard !isRatesLoading else { return }
        isRatesLoading = true
        defer { isRatesLoading = false }

        let cal  = Calendar.current
        var days = Set<Date>()

        if baseCurrencyCode != AppCurrency.RUB.rawValue {
            days.insert(cal.startOfDay(for: selectedDate))
        }

        let expenseTxs = transactionRepo.loadTransactions(for: .expense)
        let incomeTxs  = transactionRepo.loadTransactions(for: .income)
        for tx in (expenseTxs + incomeTxs) {
            guard cal.isDate(tx.date, equalTo: selectedDate, toGranularity: .month),
                  cal.isDate(tx.date, equalTo: selectedDate, toGranularity: .year),
                  AppCurrency.normalize(tx.currency) != baseCurrencyCode else { continue }
            days.insert(cal.startOfDay(for: tx.date))
        }

        await refreshRatesForDates(Array(days))
    }

    private func refreshRatesForDates(_ dates: [Date]) async {
        for date in dates {
            let key = CurrencyConverter.dateKey(for: date)
            guard ratesByDateKey[key] == nil else { continue }
            do { ratesByDateKey[key] = try await currencyService.rates(for: date) }
            catch { ratesByDateKey[key] = [AppCurrency.RUB.rawValue: 1.0] }
        }
    }
}
