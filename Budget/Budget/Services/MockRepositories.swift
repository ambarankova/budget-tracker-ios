import Foundation

// MARK: - Mock Transaction Repository
final class MockTransactionRepository: TransactionRepository {

    private var transactions:  [FinanceMode: [Transaction]]    = [:]
    private var categoryNames: [FinanceMode: [String]]         = [:]
    private var categoryPlans: [FinanceMode: [String: Int]]    = [:]

    // MARK: Transactions

    func loadTransactions(for mode: FinanceMode) -> [Transaction] {
        transactions[mode] ?? []
    }

    func saveTransactions(_ transactions: [Transaction], for mode: FinanceMode) {
        self.transactions[mode] = transactions
    }

    // MARK: Categories

    func loadCategoryNames(for mode: FinanceMode) -> [String] {
        categoryNames[mode] ?? []
    }

    func saveCategoryNames(_ names: [String], for mode: FinanceMode) {
        categoryNames[mode] = names
    }

    // MARK: Plans

    func loadCategoryPlans(for mode: FinanceMode) -> [String: Int] {
        categoryPlans[mode] ?? [:]
    }

    func saveCategoryPlans(_ plans: [String: Int], for mode: FinanceMode) {
        categoryPlans[mode] = plans
    }
}

// MARK: - Mock Goal Repository

/// In-memory GoalRepository for unit tests and SwiftUI Previews.
final class MockGoalRepository: GoalRepository {

    private(set) var goals: [Goal] = []

    func loadGoals() -> [Goal] { goals }

    func saveGoals(_ goals: [Goal]) { self.goals = goals }
}

// MARK: - Mock Currency Rate Service

/// Returns fixed rates — no network calls, deterministic for tests.
final class MockCurrencyRateService: CurrencyRateService {

    var mockRates: [String: Double] = [
        AppCurrency.RUB.rawValue: 1.0,
        AppCurrency.USD.rawValue: 90.0,
        AppCurrency.EUR.rawValue: 100.0,
        AppCurrency.GBP.rawValue: 115.0,
        AppCurrency.CNY.rawValue: 12.5,
    ]

    func rates(for date: Date) async throws -> [String: Double] {
        mockRates
    }
}
