import Foundation

// View-layer DTO: category with plan and fact already converted to the display currency.
struct CategorySummary: Identifiable {
    let id: UUID
    let name: String
    let plan: Int   // display currency, cents
    let fact: Int   // display currency, cents
}
