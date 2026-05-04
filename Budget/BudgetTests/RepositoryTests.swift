import XCTest

final class RepositoryTests: XCTestCase {

    // MARK: - TransactionRepository (via Mock)

    func test_saveAndLoadTransactions_roundTrip() {
        let repo = MockTransactionRepository()
        let tx = Transaction(category: "Food", amount: 5000, date: .now, currency: "RUB")

        repo.saveTransactions([tx], for: .expense)
        let loaded = repo.loadTransactions(for: .expense)

        XCTAssertEqual(loaded.count, 1)
        XCTAssertEqual(loaded.first?.id, tx.id)
        XCTAssertEqual(loaded.first?.amount, 5000)
    }

    func test_transactionModes_areIsolated() {
        let repo = MockTransactionRepository()
        let expenseTx = Transaction(category: "Food",   amount: 1000, date: .now, currency: "RUB")
        let incomeTx  = Transaction(category: "Salary", amount: 9000, date: .now, currency: "RUB")

        repo.saveTransactions([expenseTx], for: .expense)
        repo.saveTransactions([incomeTx],  for: .income)

        XCTAssertEqual(repo.loadTransactions(for: .expense).first?.category, "Food")
        XCTAssertEqual(repo.loadTransactions(for: .income).first?.category,  "Salary")
    }

    func test_categoryNames_saveAndLoad() {
        let repo = MockTransactionRepository()
        repo.saveCategoryNames(["Food", "Transport"], for: .expense)

        let names = repo.loadCategoryNames(for: .expense)
        XCTAssertEqual(names, ["Food", "Transport"])
    }

    func test_hasCategory_returnsCorrectResult() {
        let repo = MockTransactionRepository()
        repo.saveCategoryNames(["Food"], for: .expense)

        XCTAssertTrue(repo.hasCategory("Food",      for: .expense))
        XCTAssertFalse(repo.hasCategory("Transport", for: .expense))
    }

    func test_renameCategory_updatesNamesAndPlans() {
        let repo = MockTransactionRepository()
        repo.saveCategoryNames(["Food"],    for: .expense)
        repo.saveCategoryPlans(["Food": 50000], for: .expense)

        repo.renameCategory(from: "Food", to: "Groceries", for: .expense)

        let names = repo.loadCategoryNames(for: .expense)
        let plans = repo.loadCategoryPlans(for: .expense)

        XCTAssertFalse(names.contains("Food"))
        XCTAssertTrue(names.contains("Groceries"))
        XCTAssertNil(plans["Food"])
        XCTAssertEqual(plans["Groceries"], 50000)
    }

    // MARK: - GoalRepository (via Mock)

    func test_saveAndLoadGoals_roundTrip() {
        let repo = MockGoalRepository()
        let goal = Goal(title: "Vacation", targetAmount: 100_000)

        repo.saveGoals([goal])
        let loaded = repo.loadGoals()

        XCTAssertEqual(loaded.count, 1)
        XCTAssertEqual(loaded.first?.title, "Vacation")
        XCTAssertEqual(loaded.first?.targetAmount, 100_000)
        XCTAssertEqual(loaded.first?.savedAmount, 0)
    }

    func test_saveGoals_overwritesPrevious() {
        let repo = MockGoalRepository()
        repo.saveGoals([Goal(title: "Old", targetAmount: 1000)])
        repo.saveGoals([Goal(title: "New", targetAmount: 2000)])

        XCTAssertEqual(repo.loadGoals().count, 1)
        XCTAssertEqual(repo.loadGoals().first?.title, "New")
    }
}
