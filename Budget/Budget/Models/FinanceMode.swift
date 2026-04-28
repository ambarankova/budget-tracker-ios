import Foundation

enum FinanceMode: Hashable {
    case expense
    case income

    var screenTitle: String {
        switch self {
        case .expense: "Расходы"
        case .income:  "Доходы"
        }
    }

    var storageKey: String {
        switch self {
        case .expense: "budget.expense.transactions.v2"
        case .income:  "budget.income.transactions.v2"
        }
    }

    var legacyStorageKey: String {
        switch self {
        case .expense: "budget.expense.transactions.v1"
        case .income:  "budget.income.transactions.v1"
        }
    }

    var planStorageKey: String {
        switch self {
        case .expense: "budget.expense.plan.v2"
        case .income:  "budget.income.plan.v2"
        }
    }

    var legacyPlanStorageKey: String {
        switch self {
        case .expense: "budget.expense.plan.v1"
        case .income:  "budget.income.plan.v1"
        }
    }

    var categoriesStorageKey: String {
        switch self {
        case .expense: "budget.expense.categories.v1"
        case .income:  "budget.income.categories.v1"
        }
    }
}
