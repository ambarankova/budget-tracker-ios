import SwiftUI

struct ExpenseCategory: Identifiable {
    let id = UUID()
    let category: String
    var plan: Int
    var fact: Int
}
