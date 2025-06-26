import SwiftUI

struct ExpenseCategory: Identifiable {
    let id = UUID()
    let category: String
    let plan: Int
    let fact: Int
}
