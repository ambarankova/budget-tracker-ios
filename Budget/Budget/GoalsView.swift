import SwiftUI

struct GoalsView: View {
    @Binding var isOverlayPresented: Bool
    @Binding var isBottomGreenFillPresented: Bool
    @State private var goals: [GoalItem] = []
    @State private var isAddGoalPresented = false
    @State private var addGoalName = ""
    @State private var addGoalAmount = ""

    @State private var replenishingGoal: GoalItem?
    @State private var replenishAmount = ""

    @FocusState private var isAddAmountFocused: Bool
    @FocusState private var isReplenishAmountFocused: Bool
    @State private var historyRoute: GoalHistoryRoute?
    @State private var isSettingsPresented = false

    private let storageKey = "budget.goals.v1"

    var body: some View {
        ZStack(alignment: .bottom) {
            Color(.beige)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                HStack {
                    Spacer()
                    SettingsButton { isSettingsPresented = true }
                }
                .padding(.top, 0)

                HStack {
                    Text("Цели")
                        .font(.playfairDisplay(40, weight: .semibold))
                        .foregroundStyle(Color(.green))
                    Spacer()
                }
                .padding(.top, -8)
                .padding(.horizontal, 20)
                .padding(.bottom, 8)

                if goals.isEmpty {
                    Spacer()
                    Text("Пока что вы не поставили ни одной\nфинансовой цели!")
                        .font(.playfairDisplay(22))
                        .foregroundStyle(.black)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 20)
                    Spacer()
                } else {
                    ScrollView(showsIndicators: true) {
                        VStack(spacing: 0) {
                            ForEach(goals) { goal in
                                GoalRowView(
                                    goal: goal,
                                    onHistoryTap: {
                                        historyRoute = GoalHistoryRoute(goalId: goal.id)
                                    },
                                    onReplenishTap: {
                                        withAnimation(.easeInOut(duration: 0.22)) {
                                            replenishingGoal = goal
                                            replenishAmount = ""
                                        }
                                    }
                                )

                                Divider()
                                    .overlay(Color(.gray).opacity(0.3))
                                    .padding(.top, 8)
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 4)
                    }
                }

                Button {
                    addGoalName = ""
                    addGoalAmount = ""
                    withAnimation(.easeInOut(duration: 0.22)) {
                        isAddGoalPresented = true
                    }
                } label: {
                    RoundedRectangle(cornerRadius: 18)
                        .fill(Color(.green))
                        .frame(height: 100)
                        .overlay {
                            Image(systemName: "plus")
                                .font(.system(size: 44, weight: .semibold))
                                .foregroundStyle(.white)
                        }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 4)
            }

            if isAddGoalPresented || replenishingGoal != nil {
                Color.black.opacity(0.2)
                    .ignoresSafeArea()
                    .onTapGesture { closePopups() }
                    .transition(.opacity)
                    .zIndex(1)
            }

            if isAddGoalPresented {
                addGoalOverlay
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .zIndex(2)
            }

            if let goal = replenishingGoal {
                replenishOverlay(goal: goal)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .zIndex(2)
            }
        }
        .onAppear {
            loadGoals()
            syncOverlayState()
            syncBottomGreenFillState()
        }
        .onChange(of: isAddGoalPresented) { _ in
            syncOverlayState()
            syncBottomGreenFillState()
        }
        .onChange(of: replenishingGoal != nil) { _ in syncOverlayState() }
        .onDisappear {
            isOverlayPresented = false
            isBottomGreenFillPresented = false
        }
        .fullScreenCover(item: $historyRoute) { route in
            if let goal = goals.first(where: { $0.id == route.goalId }) {
                GoalHistoryView(
                    goal: goal,
                    onBack: { historyRoute = nil },
                    onDeleteEntry: { entryId in
                        deleteHistoryEntry(goalId: goal.id, entryId: entryId)
                    },
                    onUpdateEntryDate: { entryId, newDate in
                        updateHistoryEntryDate(goalId: goal.id, entryId: entryId, newDate: newDate)
                    },
                    onDeleteGoal: {
                        deleteGoal(goalId: goal.id)
                        historyRoute = nil
                    }
                )
            } else {
                Color(.beige)
                    .ignoresSafeArea()
                    .onAppear { historyRoute = nil }
            }
        }
        .fullScreenCover(isPresented: $isSettingsPresented) {
            AppSettingsView(onBack: { isSettingsPresented = false })
        }
    }
}

private extension GoalsView {
    var addGoalOverlay: some View {
        ZStack(alignment: .bottom) {
            Color(.green)
                .frame(height: 72)
                .ignoresSafeArea(edges: .bottom)

            VStack(alignment: .leading, spacing: 12) {
                Text("Название")
                    .font(.playfairDisplay(20, weight: .semibold))
                    .foregroundStyle(.white)

                TextField("Образование", text: $addGoalName)
                    .font(.playfairDisplay(18, weight: .semibold))
                    .padding(.horizontal, 14)
                    .frame(height: 50)
                    .background(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 10))

                Text("Сумма")
                    .font(.playfairDisplay(20, weight: .semibold))
                    .foregroundStyle(.white)

                TextField(
                    "320 000 ₽",
                    text: Binding(
                        get: { formattedAmountInput(addGoalAmount) },
                        set: { addGoalAmount = normalizedAmountInput($0) }
                    )
                )
                .focused($isAddAmountFocused)
                .keyboardType(.numberPad)
                .font(.playfairDisplay(26, weight: .semibold))
                .padding(.horizontal, 14)
                .frame(height: 50)
                .background(.white)
                .clipShape(RoundedRectangle(cornerRadius: 10))

                HStack(spacing: 12) {
                    Button("Отмена") { closePopups() }
                        .font(.playfairDisplay(18, weight: .semibold))
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(Color(.systemGray5))
                        .clipShape(RoundedRectangle(cornerRadius: 10))

                    Button("ОК") { createGoal() }
                        .font(.playfairDisplay(18, weight: .semibold))
                        .foregroundStyle(Color(.green))
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .padding(.top, 12)
                .padding(.bottom, 12)
            }
            .padding(14)
            .background(Color(.green))
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .padding(.bottom, 0)
        }
    }

    func replenishOverlay(goal: GoalItem) -> some View {
        VStack(spacing: 12) {
            Text("Введите значение")
                .font(.playfairDisplay(22, weight: .semibold))
                .foregroundStyle(.black)

            TextField(
                "0",
                text: Binding(
                    get: { formattedAmountInput(replenishAmount) },
                    set: { replenishAmount = normalizedAmountInput($0) }
                )
            )
            .focused($isReplenishAmountFocused)
            .keyboardType(.numberPad)
            .font(.playfairDisplay(30, weight: .semibold))
            .padding(.horizontal, 12)
            .frame(height: 56)
            .background(.white)
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color(.gray).opacity(0.5), lineWidth: 1))
            .clipShape(RoundedRectangle(cornerRadius: 10))

            HStack(spacing: 12) {
                Button("Отмена") { closePopups() }
                    .font(.playfairDisplay(20, weight: .semibold))
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(Color(.systemGray5))
                    .clipShape(RoundedRectangle(cornerRadius: 10))

                Button("ОК") { replenish(goalId: goal.id) }
                    .font(.playfairDisplay(20, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(Color(.green))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }
        }
        .padding(12)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal, 30)
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                isReplenishAmountFocused = true
            }
        }
    }

    func createGoal() {
        let cleanName = addGoalName.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanAmount = addGoalAmount.replacingOccurrences(of: " ", with: "")
        guard !cleanName.isEmpty, let target = Int(cleanAmount), target > 0 else { return }

        goals.append(GoalItem(title: cleanName, targetAmount: target, savedAmount: 0))
        saveGoals()
        closePopups()
    }

    func replenish(goalId: UUID) {
        let cleanAmount = replenishAmount.replacingOccurrences(of: " ", with: "")
        guard let delta = Int(cleanAmount), delta > 0 else { return }
        guard let index = goals.firstIndex(where: { $0.id == goalId }) else { return }
        goals[index].savedAmount += delta
        goals[index].history.append(GoalHistoryEntry(date: .now, amount: delta))
        saveGoals()
        closePopups()
    }

    func deleteHistoryEntry(goalId: UUID, entryId: UUID) {
        guard let goalIndex = goals.firstIndex(where: { $0.id == goalId }) else { return }
        goals[goalIndex].history.removeAll(where: { $0.id == entryId })
        goals[goalIndex].savedAmount = goals[goalIndex].history.reduce(0) { $0 + $1.amount }
        saveGoals()
    }

    func updateHistoryEntryDate(goalId: UUID, entryId: UUID, newDate: Date) {
        guard let goalIndex = goals.firstIndex(where: { $0.id == goalId }) else { return }
        guard let entryIndex = goals[goalIndex].history.firstIndex(where: { $0.id == entryId }) else { return }
        goals[goalIndex].history[entryIndex].date = newDate
        saveGoals()
    }

    func deleteGoal(goalId: UUID) {
        goals.removeAll(where: { $0.id == goalId })
        historyRoute = nil
        saveGoals()
    }

    func saveGoals() {
        guard let data = try? JSONEncoder().encode(goals) else { return }
        UserDefaults.standard.set(data, forKey: storageKey)
    }

    func loadGoals() {
        guard let data = UserDefaults.standard.data(forKey: storageKey) else { return }
        guard let decoded = try? JSONDecoder().decode([GoalItem].self, from: data) else { return }
        goals = decoded
    }

    func closePopups() {
        withAnimation(.easeInOut(duration: 0.22)) {
            isAddGoalPresented = false
            replenishingGoal = nil
        }
        isAddAmountFocused = false
        isReplenishAmountFocused = false
        replenishAmount = ""
        syncOverlayState()
    }

    func syncOverlayState() {
        isOverlayPresented = isAddGoalPresented || replenishingGoal != nil
    }

    func syncBottomGreenFillState() {
        isBottomGreenFillPresented = isAddGoalPresented
    }

    func normalizedAmountInput(_ text: String) -> String {
        String(text.filter(\.isWholeNumber))
    }

    func formattedAmountInput(_ text: String) -> String {
        guard !text.isEmpty, let number = Int(text) else { return text }
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = " "
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: number)) ?? text
    }
}

private struct GoalRowView: View {
    let goal: GoalItem
    var onHistoryTap: () -> Void
    var onReplenishTap: () -> Void

    private var progress: Double {
        guard goal.targetAmount > 0 else { return 0 }
        return min(Double(goal.savedAmount) / Double(goal.targetAmount), 1)
    }

    private var percentage: Int { Int((progress * 100).rounded()) }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(goal.title)
                .font(.playfairDisplay(22, weight: .semibold))
                .foregroundStyle(.black)

            Text("\(formatAmount(goal.savedAmount)) из \(formatAmount(goal.targetAmount)) скоплено")
                .font(.playfairDisplay(12))
                .foregroundStyle(.black)

            GeometryReader { proxy in
                let fullWidth = proxy.size.width
                let filledWidth = fullWidth * progress

                ZStack(alignment: .leading) {
                    Rectangle().fill(Color(.gray).opacity(0.5)).frame(height: 32)
                    Rectangle().fill(Color(.green)).frame(width: filledWidth, height: 32)
                    if progress > 0.18 {
                        Text("\(percentage) %")
                            .font(.playfairDisplay(18))
                            .foregroundStyle(.white)
                            .padding(.leading, 18)
                    } else {
                        HStack {
                            Spacer()
                            Text("\(percentage) %")
                                .font(.playfairDisplay(18))
                                .foregroundStyle(.black)
                                .padding(.trailing, 14)
                        }
                    }
                }
            }
            .frame(height: 32)

            HStack(spacing: 12) {
                Button("История") { onHistoryTap() }
                    .font(.playfairDisplay(20))
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(Color(.beige))
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color(.green).opacity(0.5), lineWidth: 1))
                    .clipShape(RoundedRectangle(cornerRadius: 10))

                Button("Пополнить") { onReplenishTap() }
                    .font(.playfairDisplay(20))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(Color(.green))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .padding(.top, 2)
        }
        .padding(.vertical, 8)
    }

    private func formatAmount(_ value: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = " "
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: value)) ?? "\(value)"
    }
}

private struct GoalHistoryView: View {
    let goal: GoalItem
    var onBack: () -> Void
    var onDeleteEntry: (UUID) -> Void
    var onUpdateEntryDate: (UUID, Date) -> Void
    var onDeleteGoal: () -> Void
    @State private var dateEditingEntry: GoalHistoryEntry?
    @State private var dateDraft: Date = .now
    @State private var isSettingsPresented = false

    private var sortedEntries: [GoalHistoryEntry] {
        goal.history.sorted { $0.date > $1.date }
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            Color(.beige).ignoresSafeArea()

            VStack(spacing: 0) {
                HStack {
                    Button {
                        onBack()
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 24, weight: .medium))
                            Text("Назад")
                                .font(.playfairDisplay(24, weight: .semibold))
                        }
                        .foregroundStyle(Color(.green))
                    }
                    .buttonStyle(.plain)

                    Spacer()
                    SettingsButton { isSettingsPresented = true }
                }
                .padding(.horizontal, 20)
                .padding(.top, 4)

                HStack {
                    Text(goal.title)
                        .font(.playfairDisplay(58, weight: .bold))
                        .foregroundStyle(Color(.green))
                        .lineLimit(2)
                        .minimumScaleFactor(0.7)
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 8)

                List {
                    ForEach(sortedEntries) { entry in
                        HStack {
                            Text(formatDate(entry.date))
                                .font(.playfairDisplay(18))
                                .foregroundStyle(.black)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    withAnimation(.easeInOut(duration: 0.22)) {
                                        dateDraft = entry.date
                                        dateEditingEntry = entry
                                    }
                                }
                            Spacer()
                            Text("\(formatAmount(entry.amount)) ₽")
                                .font(.playfairDisplay(20))
                                .foregroundStyle(.black)
                        }
                        .listRowInsets(EdgeInsets(top: 8, leading: 20, bottom: 8, trailing: 20))
                        .listRowBackground(Color(.beige))
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) { onDeleteEntry(entry.id) } label: { Text("Удалить") }
                        }
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)

                Button("Удалить цель") { onDeleteGoal() }
                    .font(.playfairDisplay(24))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(Color(.red))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .padding(.horizontal, 20)
                    .padding(.bottom, 18)
            }

            if dateEditingEntry != nil {
                Color.black.opacity(0.2)
                    .ignoresSafeArea()
                    .onTapGesture { closeDateEditor() }
                    .transition(.opacity)
                    .zIndex(1)
            }

            if let entry = dateEditingEntry {
                VStack(spacing: 12) {
                    DatePicker("", selection: $dateDraft, in: ...Date(), displayedComponents: .date)
                        .datePickerStyle(.wheel)
                        .labelsHidden()
                        .frame(height: 180)

                    HStack(spacing: 12) {
                        Button("Отмена") { closeDateEditor() }
                            .font(.playfairDisplay(20, weight: .semibold))
                            .foregroundStyle(.black)
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(Color(.systemGray5))
                            .clipShape(RoundedRectangle(cornerRadius: 10))

                        Button("ОК") {
                            onUpdateEntryDate(entry.id, dateDraft)
                            closeDateEditor()
                        }
                        .font(.playfairDisplay(20, weight: .semibold))
                        .foregroundStyle(Color(.green))
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                }
                .padding(16)
                .background(.white)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .padding(.horizontal, 20)
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .zIndex(2)
            }
        }
        .fullScreenCover(isPresented: $isSettingsPresented) {
            AppSettingsView(onBack: { isSettingsPresented = false })
        }
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd.MM.yyyy"
        return formatter.string(from: date)
    }

    private func formatAmount(_ value: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = " "
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: value)) ?? "\(value)"
    }

    private func closeDateEditor() {
        withAnimation(.easeInOut(duration: 0.22)) {
            dateEditingEntry = nil
        }
    }
}

private struct GoalHistoryRoute: Identifiable {
    let goalId: UUID
    var id: UUID { goalId }
}

private struct GoalHistoryEntry: Identifiable, Codable {
    let id: UUID
    var date: Date
    var amount: Int

    init(id: UUID = UUID(), date: Date, amount: Int) {
        self.id = id
        self.date = date
        self.amount = amount
    }
}

private struct GoalItem: Identifiable, Codable {
    let id: UUID
    var title: String
    var targetAmount: Int
    var savedAmount: Int
    var history: [GoalHistoryEntry]

    init(id: UUID = UUID(), title: String, targetAmount: Int, savedAmount: Int, history: [GoalHistoryEntry] = []) {
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
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        targetAmount = try container.decode(Int.self, forKey: .targetAmount)
        savedAmount = try container.decode(Int.self, forKey: .savedAmount)
        history = try container.decodeIfPresent([GoalHistoryEntry].self, forKey: .history) ?? []
    }
}
