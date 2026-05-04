import Foundation

@MainActor
final class GoalsViewModel: ObservableObject {

    private let repo: GoalRepository

    @Published private(set) var goals: [Goal] = []

    init(repo: GoalRepository) {
        self.repo = repo
    }

    // MARK: - Lifecycle

    func onAppear() {
        goals = repo.loadGoals()
    }

    // MARK: - Goal operations

    func createGoal(title: String, targetAmount: Int) {
        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanTitle.isEmpty, targetAmount > 0 else { return }
        goals.append(Goal(title: cleanTitle, targetAmount: targetAmount))
        save()
    }

    func deleteGoal(id: UUID) {
        goals.removeAll { $0.id == id }
        save()
    }

    func replenish(goalId: UUID, amount: Int) {
        guard amount > 0, let index = goals.firstIndex(where: { $0.id == goalId }) else { return }
        goals[index].savedAmount += amount
        goals[index].history.append(GoalHistoryEntry(date: .now, amount: amount))
        save()
    }

    // MARK: - History operations

    func deleteHistoryEntry(goalId: UUID, entryId: UUID) {
        guard let gi = goals.firstIndex(where: { $0.id == goalId }) else { return }
        goals[gi].history.removeAll { $0.id == entryId }
        goals[gi].savedAmount = goals[gi].history.reduce(0) { $0 + $1.amount }
        save()
    }

    func updateHistoryEntryDate(goalId: UUID, entryId: UUID, newDate: Date) {
        guard let gi = goals.firstIndex(where: { $0.id == goalId }),
              let ei = goals[gi].history.firstIndex(where: { $0.id == entryId }) else { return }
        goals[gi].history[ei].date = newDate
        save()
    }

    func updateHistoryEntryAmount(goalId: UUID, entryId: UUID, newAmount: Int) {
        guard newAmount > 0,
              let gi = goals.firstIndex(where: { $0.id == goalId }),
              let ei = goals[gi].history.firstIndex(where: { $0.id == entryId }) else { return }
        goals[gi].history[ei].amount = newAmount
        goals[gi].savedAmount = goals[gi].history.reduce(0) { $0 + $1.amount }
        save()
    }

    // MARK: - Input formatting

    func normalizedAmountInput(_ text: String) -> String {
        String(text.filter(\.isWholeNumber))
    }

    func formattedAmountInput(_ text: String) -> String {
        guard !text.isEmpty, let number = Int(text) else { return text }
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.groupingSeparator = " "
        f.maximumFractionDigits = 0
        return f.string(from: NSNumber(value: number)) ?? text
    }

    // MARK: - Private

    private func save() {
        repo.saveGoals(goals)
    }
}
