// swiftlint:disable all
// Generated using SwiftGen — https://github.com/SwiftGen/SwiftGen

import Foundation

// swiftlint:disable superfluous_disable_command file_length implicit_return prefer_self_in_static_references

// MARK: - Strings

// swiftlint:disable explicit_type_interface function_parameter_count identifier_name line_length
// swiftlint:disable nesting type_body_length type_name vertical_whitespace_opening_braces
internal enum L10n {
  /// Analitycs
  internal static let analytics = L10n.tr("Localizable", "analytics", fallback: "Analitycs")
  /// Category
  internal static let category = L10n.tr("Localizable", "category", fallback: "Category")
  /// Date
  internal static let date = L10n.tr("Localizable", "date", fallback: "Date")
  /// Delta
  internal static let delta = L10n.tr("Localizable", "delta", fallback: "Delta")
  /// Expense
  internal static let expense = L10n.tr("Localizable", "expense", fallback: "Expense")
  /// Fact
  internal static let fact = L10n.tr("Localizable", "fact", fallback: "Fact")
  /// Goals
  internal static let goals = L10n.tr("Localizable", "goals", fallback: "Goals")
  /// Income
  internal static let income = L10n.tr("Localizable", "income", fallback: "Income")
  /// Plan
  internal static let plan = L10n.tr("Localizable", "plan", fallback: "Plan")
  /// Sum
  internal static let sum = L10n.tr("Localizable", "sum", fallback: "Sum")
  /// Total
  internal static let total = L10n.tr("Localizable", "total", fallback: "Total")
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
