import Foundation

protocol TransactionRepository: AnyObject {
    func loadTransactions(for mode: FinanceMode) -> [Transaction]
    func saveTransactions(_ transactions: [Transaction], for mode: FinanceMode)
    func loadCategoryNames(for mode: FinanceMode) -> [String]
    func saveCategoryNames(_ names: [String], for mode: FinanceMode)
    func loadCategoryPlans(for mode: FinanceMode) -> [String: Int]   // RUB cents
    func saveCategoryPlans(_ plans: [String: Int], for mode: FinanceMode)
}

final class UserDefaultsTransactionRepository: TransactionRepository {

    static let shared = UserDefaultsTransactionRepository()
    private init() {}

    // MARK: Transactions

    func loadTransactions(for mode: FinanceMode) -> [Transaction] {
        let key = mode.storageKey
        if let data = UserDefaults.standard.data(forKey: key),
           let transactions = try? JSONDecoder().decode([Transaction].self, from: data) {
            return transactions
        }
        return migratedTransactions(for: mode) ?? []
    }

    func saveTransactions(_ transactions: [Transaction], for mode: FinanceMode) {
        guard let data = try? JSONEncoder().encode(transactions) else { return }
        UserDefaults.standard.set(data, forKey: mode.storageKey)
    }

    // MARK: Categories

    func loadCategoryNames(for mode: FinanceMode) -> [String] {
        UserDefaults.standard.stringArray(forKey: mode.categoriesStorageKey) ?? []
    }

    func saveCategoryNames(_ names: [String], for mode: FinanceMode) {
        UserDefaults.standard.set(names, forKey: mode.categoriesStorageKey)
    }

    // MARK: Plans (stored in RUB cents)

    func loadCategoryPlans(for mode: FinanceMode) -> [String: Int] {
        if let plans = UserDefaults.standard.dictionary(forKey: mode.planStorageKey) as? [String: Int] {
            return plans
        }
        // Migration: v1 stored whole units, v2 stores cents.
        if let legacy = UserDefaults.standard.dictionary(forKey: mode.legacyPlanStorageKey) as? [String: Int] {
            let migrated = legacy.mapValues { $0 * 100 }
            UserDefaults.standard.set(migrated, forKey: mode.planStorageKey)
            return migrated
        }
        return [:]
    }

    func saveCategoryPlans(_ plans: [String: Int], for mode: FinanceMode) {
        UserDefaults.standard.set(plans, forKey: mode.planStorageKey)
    }

    // MARK: - Private migration

    // Migrates v1 transactions (whole units) to v2 (cents) on first load.
    private func migratedTransactions(for mode: FinanceMode) -> [Transaction]? {
        let legacyKey = mode.storageKey.replacingOccurrences(of: ".v2", with: ".v1")
        guard legacyKey != mode.storageKey,
              let data = UserDefaults.standard.data(forKey: legacyKey),
              let legacy = try? JSONDecoder().decode([Transaction].self, from: data) else {
            return nil
        }
        let migrated = legacy.map {
            Transaction(id: $0.id, category: $0.category, amount: $0.amount * 100, date: $0.date, currency: $0.currency)
        }
        saveTransactions(migrated, for: mode)
        return migrated
    }
}
