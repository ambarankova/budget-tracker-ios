import SwiftUI

struct GoalsView: View {

    @ObservedObject var viewModel: GoalsViewModel
    @Binding var isOverlayPresented: Bool
    @Binding var isBottomGreenFillPresented: Bool

    // MARK: - UI-only state

    @State private var isAddGoalPresented = false
    @State private var addGoalName = ""
    @State private var addGoalAmount = ""
    @State private var replenishingGoalId: UUID?
    @State private var replenishAmount = ""
    @FocusState private var isAddAmountFocused: Bool
    @FocusState private var isReplenishAmountFocused: Bool
    @State private var historyGoalId: UUID?
    @State private var isSettingsPresented = false
    @State private var keyboardHeight: CGFloat = 0

    private var replenishingGoal: Goal? {
        guard let id = replenishingGoalId else { return nil }
        return viewModel.goals.first { $0.id == id }
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            Color(.beige)
                .ignoresSafeArea()
                .ignoresSafeArea(.keyboard)

            VStack(spacing: 0) {
                HStack {
                    Spacer()
                    SettingsButton { isSettingsPresented = true }
                }

                HStack {
                    Text("Цели")
                        .font(.playfairDisplay(40, weight: .semibold))
                        .foregroundStyle(Color(.green))
                    Spacer()
                }
                .padding(.top, -8)
                .padding(.horizontal, AppLayout.screenHorizontalPadding)
                .padding(.bottom, 8)

                if viewModel.goals.isEmpty {
                    Spacer()
                    Text("Пока что вы не поставили ни одной\nфинансовой цели!")
                        .font(.playfairDisplay(22))
                        .foregroundStyle(.black)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, AppLayout.screenHorizontalPadding)
                    Spacer()
                } else {
                    ScrollView(showsIndicators: true) {
                        VStack(spacing: 0) {
                            ForEach(viewModel.goals) { goal in
                                GoalRowView(
                                    goal: goal,
                                    onHistoryTap: { historyGoalId = goal.id },
                                    onReplenishTap: {
                                        withAnimation(.easeInOut(duration: 0.22)) {
                                            replenishingGoalId = goal.id
                                            replenishAmount = ""
                                        }
                                    }
                                )
                                Divider()
                                    .overlay(Color(.gray).opacity(0.3))
                                    .padding(.top, 8)
                            }
                        }
                        .padding(.horizontal, AppLayout.screenHorizontalPadding)
                        .padding(.top, 4)
                    }
                }

                Button {
                    addGoalName = ""
                    addGoalAmount = ""
                    withAnimation(.easeInOut(duration: 0.22)) { isAddGoalPresented = true }
                    syncBottomFill()
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
                .padding(.horizontal, AppLayout.screenHorizontalPadding)
                .padding(.bottom, 4)
            }
            .ignoresSafeArea(.keyboard)

            if replenishingGoalId != nil {
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
            viewModel.onAppear()
            syncOverlayState()
            syncBottomFill()
        }
        .onChange(of: isAddGoalPresented)      { _ in syncOverlayState(); syncBottomFill() }
        .onChange(of: replenishingGoalId != nil) { _ in syncOverlayState() }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillChangeFrameNotification)) { note in
            guard let frame = note.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect else { return }
            let isVisible = frame.origin.y < UIScreen.main.bounds.height - 50
            DispatchQueue.main.async {
                withAnimation(.easeOut(duration: 0.25)) {
                    keyboardHeight = isVisible ? frame.height : 0
                }
            }
        }
        .onDisappear {
            isOverlayPresented = false
            isBottomGreenFillPresented = false
        }
        .fullScreenCover(item: Binding(
            get: { historyGoalId.flatMap { id in viewModel.goals.first { $0.id == id } } },
            set: { if $0 == nil { historyGoalId = nil } }
        )) { goal in
            GoalHistoryView(
                goal: goal,
                onBack: { historyGoalId = nil },
                onDeleteEntry: { viewModel.deleteHistoryEntry(goalId: goal.id, entryId: $0) },
                onUpdateEntryDate: { viewModel.updateHistoryEntryDate(goalId: goal.id, entryId: $0, newDate: $1) },
                onUpdateEntryAmount: { viewModel.updateHistoryEntryAmount(goalId: goal.id, entryId: $0, newAmount: $1) },
                onDeleteGoal: { viewModel.deleteGoal(id: goal.id); historyGoalId = nil }
            )
        }
        .fullScreenCover(isPresented: $isSettingsPresented) {
            AppSettingsView(onBack: { isSettingsPresented = false })
        }
    }

    // MARK: - Overlay sync

    private func syncOverlayState() {
        isOverlayPresented = isAddGoalPresented || replenishingGoalId != nil
    }

    private func syncBottomFill() {
        isBottomGreenFillPresented = isAddGoalPresented
    }

    private func closePopups() {
        withAnimation(.easeInOut(duration: 0.22)) {
            isAddGoalPresented = false
            replenishingGoalId = nil
        }
        isAddAmountFocused = false
        isReplenishAmountFocused = false
        replenishAmount = ""
        syncOverlayState()
        syncBottomFill()
    }
}

// MARK: - Overlays

private extension GoalsView {

    var addGoalOverlay: some View {
        ZStack(alignment: .bottom) {
            Color.black.opacity(0.25)
                .contentShape(Rectangle())
                .ignoresSafeArea()
                .onTapGesture {
                    if isAddAmountFocused {
                        isAddAmountFocused = false
                        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                    } else {
                        closePopups()
                    }
                }

            Color(.green).frame(height: 180).ignoresSafeArea(edges: .bottom)

            VStack(alignment: .leading, spacing: 12) {
                Text("Название").font(.playfairDisplay(20, weight: .semibold)).foregroundStyle(.white)

                TextField("Образование", text: $addGoalName)
                    .font(.playfairDisplay(18, weight: .semibold))
                    .padding(.horizontal, 14)
                    .frame(height: 50)
                    .background(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 10))

                Text("Сумма").font(.playfairDisplay(20, weight: .semibold)).foregroundStyle(.white)

                TextField("320 000 ₽", text: Binding(
                    get: { formattedAmount(addGoalAmount) },
                    set: { addGoalAmount = normalizedAmount($0) }
                ))
                .focused($isAddAmountFocused)
                .keyboardType(.numberPad)
                .font(.playfairDisplay(20, weight: .semibold))
                .padding(.horizontal, 14)
                .frame(height: 50)
                .background(.white)
                .clipShape(RoundedRectangle(cornerRadius: 10))

                HStack(spacing: 12) {
                    Button("Отмена") { closePopups() }
                        .font(.playfairDisplay(18, weight: .semibold))
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity).frame(height: 50)
                        .background(Color(.systemGray5))
                        .clipShape(RoundedRectangle(cornerRadius: 10))

                    Button("ОК") {
                        guard let amount = Int(addGoalAmount.filter(\.isWholeNumber)), amount > 0 else { return }
                        viewModel.createGoal(title: addGoalName, targetAmount: amount)
                        closePopups()
                    }
                    .font(.playfairDisplay(18, weight: .semibold))
                    .foregroundStyle(Color(.green))
                    .frame(maxWidth: .infinity).frame(height: 50)
                    .background(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .padding(.top, 12)
                .padding(.bottom, 12)
            }
            .padding(14)
            .background(Color(.green))
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .padding(.bottom, 56)
            .contentShape(Rectangle())
            .onTapGesture {
                isAddAmountFocused = false
                UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
            }
            .offset(y: -max(0, keyboardHeight - 90))
        }
        .ignoresSafeArea(edges: .bottom)
    }

    func replenishOverlay(goal: Goal) -> some View {
        VStack(spacing: 12) {
            Text("Введите значение")
                .font(.playfairDisplay(22, weight: .semibold))
                .foregroundStyle(.black)

            TextField("0", text: Binding(
                get: { formattedAmount(replenishAmount) },
                set: { replenishAmount = normalizedAmount($0) }
            ))
            .focused($isReplenishAmountFocused)
            .keyboardType(.numberPad)
            .font(.playfairDisplay(22, weight: .semibold))
            .padding(.horizontal, 12)
            .frame(height: 56)
            .background(.white)
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color(.gray).opacity(0.5), lineWidth: 1))
            .clipShape(RoundedRectangle(cornerRadius: 10))

            HStack(spacing: 12) {
                Button("Отмена") { closePopups() }
                    .font(.playfairDisplay(20, weight: .semibold)).foregroundStyle(.black)
                    .frame(maxWidth: .infinity).frame(height: 56)
                    .background(Color(.systemGray5))
                    .clipShape(RoundedRectangle(cornerRadius: 10))

                Button("ОК") {
                    guard let delta = Int(replenishAmount.filter(\.isWholeNumber)), delta > 0 else { return }
                    viewModel.replenish(goalId: goal.id, amount: delta)
                    closePopups()
                }
                .font(.playfairDisplay(20, weight: .semibold)).foregroundStyle(.white)
                .frame(maxWidth: .infinity).frame(height: 56)
                .background(Color(.green))
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
        }
        .padding(12)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal, 30)
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { isReplenishAmountFocused = true }
        }
    }

    // MARK: - Formatting helpers

    private func normalizedAmount(_ text: String) -> String { String(text.filter(\.isWholeNumber)) }

    private func formattedAmount(_ text: String) -> String {
        guard !text.isEmpty, let number = Int(text) else { return text }
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.groupingSeparator = " "
        f.maximumFractionDigits = 0
        return f.string(from: NSNumber(value: number)) ?? text
    }
}

// MARK: - Goal row

private struct GoalRowView: View {
    let goal: Goal
    var onHistoryTap: () -> Void
    var onReplenishTap: () -> Void

    private var progress: Double {
        guard goal.targetAmount > 0 else { return 0 }
        return min(Double(goal.savedAmount) / Double(goal.targetAmount), 1)
    }
    private var percentage: Int { Int((progress * 100).rounded()) }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(goal.title).font(.playfairDisplay(22, weight: .semibold)).foregroundStyle(.black)
            Text("\(format(goal.savedAmount)) из \(format(goal.targetAmount)) скоплено")
                .font(.playfairDisplay(12)).foregroundStyle(.black)

            GeometryReader { proxy in
                let full = proxy.size.width
                let filled = full * progress
                ZStack(alignment: .leading) {
                    Rectangle().fill(Color(.gray).opacity(0.5)).frame(height: 32)
                    Rectangle().fill(Color(.green)).frame(width: filled, height: 32)
                    if progress > 0.18 {
                        Text("\(percentage) %").font(.playfairDisplay(18)).foregroundStyle(.white).padding(.leading, 18)
                    } else {
                        HStack {
                            Spacer()
                            Text("\(percentage) %").font(.playfairDisplay(18)).foregroundStyle(.black).padding(.trailing, 14)
                        }
                    }
                }
            }
            .frame(height: 32)

            HStack(spacing: 12) {
                Button("История") { onHistoryTap() }
                    .font(.playfairDisplay(20)).foregroundStyle(.black)
                    .frame(maxWidth: .infinity).frame(height: 56)
                    .background(Color(.beige))
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color(.green).opacity(0.5), lineWidth: 1))
                    .clipShape(RoundedRectangle(cornerRadius: 10))

                Button("Пополнить") { onReplenishTap() }
                    .font(.playfairDisplay(20)).foregroundStyle(.white)
                    .frame(maxWidth: .infinity).frame(height: 56)
                    .background(Color(.green))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .padding(.top, 2)
        }
        .padding(.vertical, 8)
    }

    private func format(_ value: Int) -> String {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.groupingSeparator = " "
        f.maximumFractionDigits = 0
        return f.string(from: NSNumber(value: value)) ?? "\(value)"
    }
}

// MARK: - Goal history screen

private struct GoalHistoryView: View {
    let goal: Goal
    var onBack: () -> Void
    var onDeleteEntry: (UUID) -> Void
    var onUpdateEntryDate: (UUID, Date) -> Void
    var onUpdateEntryAmount: (UUID, Int) -> Void
    var onDeleteGoal: () -> Void

    @State private var editingEntry: GoalHistoryEntry?
    @State private var dateDraft: Date = .now
    @State private var amountDraft = ""
    @State private var isDeleteGoalAlertPresented = false
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
                            Image(systemName: "chevron.left").font(.system(size: 24, weight: .medium))
                            Text("Назад").font(.playfairDisplay(24, weight: .semibold))
                        }
                        .foregroundStyle(Color(.green))
                    }
                    .buttonStyle(.plain)
                    Spacer()
                    SettingsButton { isSettingsPresented = true }
                }
                .padding(.horizontal, AppLayout.screenHorizontalPadding)
                .padding(.top, 4)

                HStack {
                    Text(goal.title)
                        .font(.playfairDisplay(40, weight: .bold))
                        .foregroundStyle(Color(.green))
                        .lineLimit(2)
                        .minimumScaleFactor(0.7)
                    Spacer()
                }
                .padding(.horizontal, AppLayout.screenHorizontalPadding)
                .padding(.bottom, 8)

                List {
                    ForEach(sortedEntries) { entry in
                        HStack {
                            Text(formatDate(entry.date)).font(.playfairDisplay(18)).foregroundStyle(.black)
                            Spacer()
                            Text("\(format(entry.amount)) ₽").font(.playfairDisplay(20)).foregroundStyle(.black)
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            withAnimation(.easeInOut(duration: 0.22)) {
                                dateDraft = entry.date
                                amountDraft = String(entry.amount)
                                editingEntry = entry
                            }
                        }
                        .listRowInsets(EdgeInsets(top: 8, leading: AppLayout.screenHorizontalPadding, bottom: 8, trailing: AppLayout.screenHorizontalPadding))
                        .listRowBackground(Color(.beige))
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) { onDeleteEntry(entry.id) } label: { Text("Удалить") }
                        }
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)

                Button("Удалить цель") { isDeleteGoalAlertPresented = true }
                    .font(.playfairDisplay(24)).foregroundStyle(.white)
                    .frame(maxWidth: .infinity).frame(height: 56)
                    .background(Color(.red))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .padding(.horizontal, AppLayout.screenHorizontalPadding)
                    .padding(.bottom, 18)
            }

            if editingEntry != nil {
                Color.black.opacity(0.2)
                    .ignoresSafeArea()
                    .onTapGesture { closeEditor() }
                    .transition(.opacity)
                    .zIndex(1)
            }

            if let entry = editingEntry {
                VStack(spacing: 12) {
                    DatePicker("", selection: $dateDraft, in: ...Date(), displayedComponents: .date)
                        .datePickerStyle(.wheel).labelsHidden().frame(height: 180)

                    Text("Сумма").font(.playfairDisplay(20, weight: .semibold)).foregroundStyle(.black)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    TextField("0", text: Binding(
                        get: { formattedAmount(amountDraft) },
                        set: { amountDraft = String($0.filter(\.isWholeNumber)) }
                    ))
                    .keyboardType(.numberPad)
                    .font(.playfairDisplay(26, weight: .semibold))
                    .padding(.horizontal, 12).frame(height: 56)
                    .background(.white)
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color(.gray).opacity(0.5), lineWidth: 1))
                    .clipShape(RoundedRectangle(cornerRadius: 10))

                    HStack(spacing: 12) {
                        Button("Отмена") { closeEditor() }
                            .font(.playfairDisplay(20, weight: .semibold)).foregroundStyle(.black)
                            .frame(maxWidth: .infinity).frame(height: 56)
                            .background(Color(.systemGray5)).clipShape(RoundedRectangle(cornerRadius: 10))

                        Button("ОК") {
                            let cleaned = amountDraft.filter(\.isWholeNumber)
                            guard let amount = Int(cleaned), amount > 0 else { return }
                            onUpdateEntryDate(entry.id, dateDraft)
                            onUpdateEntryAmount(entry.id, amount)
                            closeEditor()
                        }
                        .font(.playfairDisplay(20, weight: .semibold)).foregroundStyle(Color(.green))
                        .frame(maxWidth: .infinity).frame(height: 56)
                        .background(.white).clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                }
                .padding(16).background(.white).clipShape(RoundedRectangle(cornerRadius: 16))
                .padding(.horizontal, AppLayout.screenHorizontalPadding)
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .zIndex(2)
            }

            if isDeleteGoalAlertPresented {
                Color.black.opacity(0.2).ignoresSafeArea()
                    .onTapGesture { isDeleteGoalAlertPresented = false }
                    .transition(.opacity).zIndex(1)

                VStack(spacing: 12) {
                    Text("Удалить цель?").font(.playfairDisplay(24, weight: .semibold)).foregroundStyle(.black)
                    Text("Это действие нельзя отменить.")
                        .font(.playfairDisplay(16)).foregroundStyle(.black.opacity(0.8)).multilineTextAlignment(.center)

                    HStack(spacing: 12) {
                        Button("Отмена") { isDeleteGoalAlertPresented = false }
                            .font(.playfairDisplay(20, weight: .semibold)).foregroundStyle(.black)
                            .frame(maxWidth: .infinity).frame(height: 56)
                            .background(Color(.systemGray5)).clipShape(RoundedRectangle(cornerRadius: 10))

                        Button("Да, удалить") { onDeleteGoal(); isDeleteGoalAlertPresented = false }
                            .font(.playfairDisplay(20, weight: .semibold)).foregroundStyle(.white)
                            .frame(maxWidth: .infinity).frame(height: 56)
                            .background(Color(.red)).clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                }
                .padding(16).background(.white).clipShape(RoundedRectangle(cornerRadius: 16))
                .padding(.horizontal, AppLayout.screenHorizontalPadding)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                .transition(.move(edge: .bottom).combined(with: .opacity)).zIndex(2)
            }
        }
        .fullScreenCover(isPresented: $isSettingsPresented) {
            AppSettingsView(onBack: { isSettingsPresented = false })
        }
    }

    private func closeEditor() {
        withAnimation(.easeInOut(duration: 0.22)) { editingEntry = nil; amountDraft = "" }
    }

    private func formatDate(_ date: Date) -> String {
        let f = DateFormatter(); f.dateFormat = "dd.MM.yyyy"; return f.string(from: date)
    }

    private func format(_ value: Int) -> String {
        let f = NumberFormatter()
        f.numberStyle = .decimal; f.groupingSeparator = " "; f.maximumFractionDigits = 0
        return f.string(from: NSNumber(value: value)) ?? "\(value)"
    }

    private func formattedAmount(_ text: String) -> String {
        guard !text.isEmpty, let n = Int(text) else { return text }
        let f = NumberFormatter()
        f.numberStyle = .decimal; f.groupingSeparator = " "; f.maximumFractionDigits = 0
        return f.string(from: NSNumber(value: n)) ?? text
    }
}

// Goal conforms to Identifiable (from Models/Goal.swift), used as fullScreenCover item.
extension Goal: Equatable {
    static func == (lhs: Goal, rhs: Goal) -> Bool { lhs.id == rhs.id }
}
