import Foundation

protocol GoalRepository: AnyObject {
    func loadGoals() -> [Goal]
    func saveGoals(_ goals: [Goal])
}

final class UserDefaultsGoalRepository: GoalRepository {

    static let shared = UserDefaultsGoalRepository()
    private init() {}

    private let storageKey = "budget.goals.v1"

    func loadGoals() -> [Goal] {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let goals = try? JSONDecoder().decode([Goal].self, from: data) else {
            return []
        }
        return goals
    }

    func saveGoals(_ goals: [Goal]) {
        guard let data = try? JSONEncoder().encode(goals) else { return }
        UserDefaults.standard.set(data, forKey: storageKey)
    }
}
