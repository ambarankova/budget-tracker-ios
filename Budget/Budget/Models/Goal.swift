import Foundation

struct Goal: Identifiable, Codable {
    let id: UUID
    var title: String
    var targetAmount: Int   // whole units (no cents for goals)
    var savedAmount: Int
    var history: [GoalHistoryEntry]

    init(id: UUID = UUID(), title: String, targetAmount: Int, savedAmount: Int = 0, history: [GoalHistoryEntry] = []) {
        self.id = id
        self.title = title
        self.targetAmount = targetAmount
        self.savedAmount = savedAmount
        self.history = history
    }

    enum CodingKeys: String, CodingKey {
        case id, title, targetAmount, savedAmount, history
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        title = try c.decode(String.self, forKey: .title)
        targetAmount = try c.decode(Int.self, forKey: .targetAmount)
        savedAmount = try c.decode(Int.self, forKey: .savedAmount)
        history = try c.decodeIfPresent([GoalHistoryEntry].self, forKey: .history) ?? []
    }
}

struct GoalHistoryEntry: Identifiable, Codable {
    let id: UUID
    var date: Date
    var amount: Int

    init(id: UUID = UUID(), date: Date, amount: Int) {
        self.id = id
        self.date = date
        self.amount = amount
    }
}
