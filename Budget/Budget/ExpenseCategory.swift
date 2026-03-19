import SwiftUI

struct ExpenseCategory: Identifiable {
    let id: UUID
    let category: String
    var plan: Int
    var fact: Int

    init(id: UUID = UUID(), category: String, plan: Int, fact: Int = 0) {
        self.id = id
        self.category = category
        self.plan = plan
        self.fact = fact
    }
}
