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
                        .accessibilityLabel(L10n.a11yOpenSettings)
                }

                HStack {
                    Text(L10n.goals)
                        .font(.playfairDisplay(40, weight: .semibold))
                        .foregroundStyle(Color(.green))
                    Spacer()
                }
                .padding(.top, -8)
                .padding(.horizontal, AppLayout.screenHorizontalPadding)
                .padding(.bottom, 8)

                if viewModel.goals.isEmpty {
                    Spacer()
                    Text(L10n.goalsEmpty)
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
                .accessibilityLabel(L10n.goals)
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
                Text(L10n.name).font(.playfairDisplay(20, weight: .semibold)).foregroundStyle(.white)

                TextField(L10n.name, text: $addGoalName)
                    .font(.playfairDisplay(18, weight: .semibold))
                    .padding(.horizontal, 14)
                    .frame(height: 50)
                    .background(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 10))

                Text(L10n.sum).font(.playfairDisplay(20, weight: .semibold)).foregroundStyle(.white)

                TextField("0", text: Binding(
                    get: { viewModel.formattedAmountInput(addGoalAmount) },
                    set: { addGoalAmount = viewModel.normalizedAmountInput($0) }
                ))
                .focused($isAddAmountFocused)
                .keyboardType(.numberPad)
                .font(.playfairDisplay(20, weight: .semibold))
                .padding(.horizontal, 14)
                .frame(height: 50)
                .background(.white)
                .clipShape(RoundedRectangle(cornerRadius: 10))

                HStack(spacing: 12) {
                    Button(L10n.cancel) { closePopups() }
                        .font(.playfairDisplay(18, weight: .semibold))
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity).frame(height: 50)
                        .background(Color(.systemGray5))
                        .clipShape(RoundedRectangle(cornerRadius: 10))

                    Button(L10n.ok) {
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
            Text(L10n.enterValue)
                .font(.playfairDisplay(22, weight: .semibold))
                .foregroundStyle(.black)

            TextField("0", text: Binding(
                get: { viewModel.formattedAmountInput(replenishAmount) },
                set: { replenishAmount = viewModel.normalizedAmountInput($0) }
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
                Button(L10n.cancel) { closePopups() }
                    .font(.playfairDisplay(20, weight: .semibold)).foregroundStyle(.black)
                    .frame(maxWidth: .infinity).frame(height: 56)
                    .background(Color(.systemGray5))
                    .clipShape(RoundedRectangle(cornerRadius: 10))

                Button(L10n.ok) {
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

}

extension Goal: Equatable {
    static func == (lhs: Goal, rhs: Goal) -> Bool { lhs.id == rhs.id }
}
