import Foundation

struct Category: Identifiable {
    let id: UUID
    var name: String
    var planRUB: Int

    init(id: UUID = UUID(), name: String, planRUB: Int = 0) {
        self.id = id
        self.name = name
        self.planRUB = planRUB
    }
}
