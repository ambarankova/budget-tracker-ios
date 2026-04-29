// swiftlint:disable all
// Generated using SwiftGen — https://github.com/SwiftGen/SwiftGen

import Foundation

// swiftlint:disable superfluous_disable_command file_length implicit_return prefer_self_in_static_references

// MARK: - Strings

// swiftlint:disable explicit_type_interface function_parameter_count identifier_name line_length
// swiftlint:disable nesting type_body_length type_name vertical_whitespace_opening_braces
internal enum L10n {
  /// Add transaction
  internal static let a11yAddTransaction = L10n.tr("Localizable", "a11y_add_transaction", fallback: "Add transaction")
  /// Open settings
  internal static let a11yOpenSettings = L10n.tr("Localizable", "a11y_open_settings", fallback: "Open settings")
  /// Summary table
  internal static let a11yPageSummary = L10n.tr("Localizable", "a11y_page_summary", fallback: "Summary table")
  /// Transactions list
  internal static let a11yPageTransactions = L10n.tr("Localizable", "a11y_page_transactions", fallback: "Transactions list")
  /// Select month
  internal static let a11yPickMonth = L10n.tr("Localizable", "a11y_pick_month", fallback: "Select month")
  /// Analytics
  internal static let analytics = L10n.tr("Localizable", "analytics", fallback: "Analytics")
  /// Back
  internal static let back = L10n.tr("Localizable", "back", fallback: "Back")
  /// Buy premium
  internal static let buyPremium = L10n.tr("Localizable", "buy_premium", fallback: "Buy premium")
  /// Cancel
  internal static let cancel = L10n.tr("Localizable", "cancel", fallback: "Cancel")
  /// Category
  internal static let category = L10n.tr("Localizable", "category", fallback: "Category")
  /// Category name
  internal static let categoryName = L10n.tr("Localizable", "category_name", fallback: "Category name")
  /// Are you sure you want to delete this category?
  internal static let confirmDeleteCategory = L10n.tr("Localizable", "confirm_delete_category", fallback: "Are you sure you want to delete this category?")
  /// Currency
  internal static let currency = L10n.tr("Localizable", "currency", fallback: "Currency")
  /// Date
  internal static let date = L10n.tr("Localizable", "date", fallback: "Date")
  /// Delete
  internal static let delete = L10n.tr("Localizable", "delete", fallback: "Delete")
  /// Delete goal
  internal static let deleteGoal = L10n.tr("Localizable", "delete_goal", fallback: "Delete goal")
  /// Delete goal?
  internal static let deleteGoalTitle = L10n.tr("Localizable", "delete_goal_title", fallback: "Delete goal?")
  /// This action cannot be undone.
  internal static let deleteIrreversible = L10n.tr("Localizable", "delete_irreversible", fallback: "This action cannot be undone.")
  /// Delta
  internal static let delta = L10n.tr("Localizable", "delta", fallback: "Delta")
  /// Enter value
  internal static let enterValue = L10n.tr("Localizable", "enter_value", fallback: "Enter value")
  /// Expense
  internal static let expense = L10n.tr("Localizable", "expense", fallback: "Expense")
  /// Fact
  internal static let fact = L10n.tr("Localizable", "fact", fallback: "Fact")
  /// Goals
  internal static let goals = L10n.tr("Localizable", "goals", fallback: "Goals")
  /// You haven't set any
  /// financial goals yet!
  internal static let goalsEmpty = L10n.tr("Localizable", "goals_empty", fallback: "You haven't set any\nfinancial goals yet!")
  /// History
  internal static let history = L10n.tr("Localizable", "history", fallback: "History")
  /// Income
  internal static let income = L10n.tr("Localizable", "income", fallback: "Income")
  /// Month
  internal static let month = L10n.tr("Localizable", "month", fallback: "Month")
  /// Name
  internal static let name = L10n.tr("Localizable", "name", fallback: "Name")
  /// New
  internal static let newCategory = L10n.tr("Localizable", "new_category", fallback: "New")
  /// OK
  internal static let ok = L10n.tr("Localizable", "ok", fallback: "OK")
  /// Plan
  internal static let plan = L10n.tr("Localizable", "plan", fallback: "Plan")
  /// Plan: %@
  internal static func planCategory(_ p1: Any) -> String {
    return L10n.tr("Localizable", "plan_category_%@", String(describing: p1), fallback: "Plan: %@")
  }
  /// Rate app
  internal static let rateApp = L10n.tr("Localizable", "rate_app", fallback: "Rate app")
  /// Replenish
  internal static let replenish = L10n.tr("Localizable", "replenish", fallback: "Replenish")
  /// Save
  internal static let save = L10n.tr("Localizable", "save", fallback: "Save")
  /// Settings
  internal static let settings = L10n.tr("Localizable", "settings", fallback: "Settings")
  /// Share
  internal static let share = L10n.tr("Localizable", "share", fallback: "Share")
  /// Sum
  internal static let sum = L10n.tr("Localizable", "sum", fallback: "Sum")
  /// Total
  internal static let total = L10n.tr("Localizable", "total", fallback: "Total")
  /// Year
  internal static let year = L10n.tr("Localizable", "year", fallback: "Year")
}
// swiftlint:enable explicit_type_interface function_parameter_count identifier_name line_length
// swiftlint:enable nesting type_body_length type_name vertical_whitespace_opening_braces

// MARK: - Implementation Details

extension L10n {
  private static func tr(_ table: String, _ key: String, _ args: CVarArg..., fallback value: String) -> String {
    let format = BundleToken.bundle.localizedString(forKey: key, value: value, table: table)
    return String(format: format, locale: Locale.current, arguments: args)
  }
}

// swiftlint:disable convenience_type
private final class BundleToken {
  static let bundle: Bundle = {
    #if SWIFT_PACKAGE
    return Bundle.module
    #else
    return Bundle(for: BundleToken.self)
    #endif
  }()
}
// swiftlint:enable convenience_type
