import Foundation

struct Transaction: Identifiable, Codable {
    let id: UUID
    let category: String
    let amount: Int     // cents (minor units)
    let date: Date
    let currency: String

    init(id: UUID = UUID(), category: String, amount: Int, date: Date, currency: String) {
        self.id = id
        self.category = category
        self.amount = amount
        self.date = date
        self.currency = currency
    }
}
