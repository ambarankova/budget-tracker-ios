import Foundation

/// Composition root — owns all shared service instances.
///
/// Usage:
/// - Production:  `ContentView()`               → uses `AppDependencies.live` automatically
/// - UI Previews: `ContentView(dependencies: .preview)`
/// - Unit Tests:  `FinanceDashboardViewModel(mode: .expense, deps: AppDependencies(transactionRepo: MockTransactionRepository()))`
final class AppDependencies {

    // MARK: - Factory

    /// Shared production instance backed by UserDefaults + CBR API.
    static let live = AppDependencies()

    /// Lightweight in-memory instance for SwiftUI Previews.
    static let preview = AppDependencies(
        transactionRepo: MockTransactionRepository(),
        goalRepo: MockGoalRepository(),
        currencyService: MockCurrencyRateService()
    )

    // MARK: - Dependencies (protocol types — no concrete leakage)

    let transactionRepo: TransactionRepository
    let goalRepo: GoalRepository
    let currencyService: CurrencyRateService

    // MARK: - Init

    init(
        transactionRepo: TransactionRepository = UserDefaultsTransactionRepository.shared,
        goalRepo: GoalRepository = UserDefaultsGoalRepository.shared,
        currencyService: CurrencyRateService = CBRCurrencyRateService.shared
    ) {
        self.transactionRepo = transactionRepo
        self.goalRepo = goalRepo
        self.currencyService = currencyService
    }
}
