import SwiftUI

// MARK: - Goal history screen

struct GoalHistoryView: View {
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
                            Text(L10n.back).font(.playfairDisplay(24, weight: .semibold))
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
                            Button(role: .destructive) { onDeleteEntry(entry.id) } label: { Text(L10n.delete) }
                        }
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)

                Button(L10n.deleteGoal) { isDeleteGoalAlertPresented = true }
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

                    Text(L10n.sum).font(.playfairDisplay(20, weight: .semibold)).foregroundStyle(.black)
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
                        Button(L10n.cancel) { closeEditor() }
                            .font(.playfairDisplay(20, weight: .semibold)).foregroundStyle(.black)
                            .frame(maxWidth: .infinity).frame(height: 56)
                            .background(Color(.systemGray5)).clipShape(RoundedRectangle(cornerRadius: 10))

                        Button(L10n.ok) {
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
                    Text(L10n.deleteGoalTitle).font(.playfairDisplay(24, weight: .semibold)).foregroundStyle(.black)
                    Text(L10n.deleteIrreversible)
                        .font(.playfairDisplay(16)).foregroundStyle(.black.opacity(0.8)).multilineTextAlignment(.center)

                    HStack(spacing: 12) {
                        Button(L10n.cancel) { isDeleteGoalAlertPresented = false }
                            .font(.playfairDisplay(20, weight: .semibold)).foregroundStyle(.black)
                            .frame(maxWidth: .infinity).frame(height: 56)
                            .background(Color(.systemGray5)).clipShape(RoundedRectangle(cornerRadius: 10))

                        Button(L10n.delete) { onDeleteGoal(); isDeleteGoalAlertPresented = false }
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
        AppDateFormat.display.string(from: date)
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
