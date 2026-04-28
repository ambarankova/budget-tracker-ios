import Foundation

// Stored model. planRUB is always kept in RUB cents for currency-agnostic persistence.
struct Category: Identifiable {
    let id: UUID
    var name: String
    var planRUB: Int    // cents

    init(id: UUID = UUID(), name: String, planRUB: Int = 0) {
        self.id = id
        self.name = name
        self.planRUB = planRUB
    }
}
