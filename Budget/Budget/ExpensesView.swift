import SwiftUI

struct ExpensesView: View {
    @State private var categories: [ExpenseCategory] = [
        .init(category: "Еда", plan: 0, fact: 0),
        .init(category: "Транспорт", plan: 0, fact: 0),
        .init(category: "Красота", plan: 0, fact: 0)
    ]
    @State private var isAddTransactionPresented = false
    @State private var transaction = TransactionDraft()
    @State private var activePicker: AddTransactionPicker?
    @FocusState private var isAmountInputFocused: Bool

    private let monthlyIncome = 0

    private var totalPlan: Int {
        categories.reduce(0) { $0 + $1.plan }
    }

    private var totalFact: Int {
        categories.reduce(0) { $0 + $1.fact }
    }

    private var deltaText: String {
        let delta = monthlyIncome - totalFact
        return formatAmount(delta, withSign: true)
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            VStack(spacing: 0) {
                HStack {
                    Spacer()

                    SettingsButton {
                        print("Settings tapped")
                    }
                }
                .padding(.top, 0)

                HStack {
                    Text("Дельта: \(deltaText)")
                        .font(.playfairDisplay(44, weight: .bold))
                        .minimumScaleFactor(0.65)
                        .lineLimit(1)
                        .foregroundStyle(Color(.green))

                    Spacer()
                }
                .padding(.top, -8)
                .padding(.horizontal, 20)

                HStack {
                    Text("Расходы")
                        .font(.playfairDisplay(42, weight: .semibold))
                        .foregroundStyle(Color(.green))

                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 8)

                TotalTableView(
                    categories: categories,
                    totalPlan: totalPlan,
                    totalFact: totalFact
                )
                .frame(maxHeight: .infinity)

                HStack(spacing: 8) {
                    Circle()
                        .fill(Color(.green))
                        .frame(width: 10, height: 10)
                    Circle()
                        .fill(Color(.gray).opacity(0.4))
                        .frame(width: 10, height: 10)
                }
                .padding(.vertical, 8)

                Button {
                    transaction = TransactionDraft(defaultCategory: categories.first?.category ?? "Еда")
                    withAnimation(.easeInOut(duration: 0.28)) {
                        isAddTransactionPresented = true
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

                BottomMenuBar()
            }
            .background(Color(.beige))

            if isAddTransactionPresented {
                addTransactionOverlay
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
    }
}

#Preview {
    ExpensesView()
}

private extension ExpensesView {
    var addTransactionOverlay: some View {
        ZStack(alignment: .bottom) {
            Color.black.opacity(0.25)
                .ignoresSafeArea()
                .onTapGesture {
                    withAnimation(.easeInOut(duration: 0.24)) {
                        isAddTransactionPresented = false
                    }
                    activePicker = nil
                }

            VStack(alignment: .leading, spacing: 12) {
                Text("Сумма")
                    .font(.playfairDisplay(24, weight: .semibold))
                    .foregroundStyle(.white)

                HStack(spacing: 10) {
                    TextField(
                        "0",
                        text: Binding(
                            get: { formattedAmountInput(transaction.amount) },
                            set: { transaction.amount = normalizedAmountInput($0) }
                        )
                    )
                        .focused($isAmountInputFocused)
                        .font(.playfairDisplay(34, weight: .semibold))
                        .foregroundStyle(.black)
                        .keyboardType(.numberPad)
                        .submitLabel(.done)

                    Button {
                        activePicker = nil
                        isAmountInputFocused = true
                    } label: {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 28, weight: .semibold))
                            .foregroundStyle(Color(.green))
                    }
                }
                .padding(.horizontal, 14)
                .frame(height: 56)
                .background(.white)
                .clipShape(RoundedRectangle(cornerRadius: 10))

                Text("Категория")
                    .font(.playfairDisplay(24, weight: .semibold))
                    .foregroundStyle(.white)

                fieldButtonRow(value: transaction.category) {
                    isAmountInputFocused = false
                    withAnimation(.easeInOut(duration: 0.2)) {
                        activePicker = activePicker == .category ? nil : .category
                    }
                }

                if activePicker == .category {
                    categoryPicker
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }

                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Дата")
                            .font(.playfairDisplay(24, weight: .semibold))
                            .foregroundStyle(.white)

                        fieldButtonRow(value: formatDate(transaction.date)) {
                            isAmountInputFocused = false
                            withAnimation(.easeInOut(duration: 0.2)) {
                                activePicker = activePicker == .date ? nil : .date
                            }
                        }
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Валюта")
                            .font(.playfairDisplay(24, weight: .semibold))
                            .foregroundStyle(.white)

                        fieldButtonRow(value: transaction.currency) {
                            isAmountInputFocused = false
                            withAnimation(.easeInOut(duration: 0.2)) {
                                activePicker = activePicker == .currency ? nil : .currency
                            }
                        }
                    }
                }

                if activePicker == .date {
                    DatePicker("", selection: $transaction.date, displayedComponents: .date)
                        .datePickerStyle(.graphical)
                        .labelsHidden()
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .background(Color(.systemGray5))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }

                if activePicker == .currency {
                    currencyPicker
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }

                HStack(spacing: 12) {
                    Button("Отмена") {
                        withAnimation(.easeInOut(duration: 0.24)) {
                            isAddTransactionPresented = false
                        }
                        activePicker = nil
                    }
                    .font(.playfairDisplay(24, weight: .semibold))
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(Color(.systemGray5))
                    .clipShape(RoundedRectangle(cornerRadius: 10))

                    Button("ОК") {
                        addTransaction()
                    }
                    .font(.playfairDisplay(24, weight: .semibold))
                    .foregroundStyle(Color(.green))
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .padding(.top, 14)
                .padding(.bottom, 20)
            }
            .padding(16)
            .background(Color(.green))
            .clipShape(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
            )
        }
        .ignoresSafeArea(edges: .bottom)
    }

    func addTransaction() {
        let cleaned = transaction.amount.replacingOccurrences(of: " ", with: "")
        guard let amount = Int(cleaned), amount > 0 else { return }
        guard let index = categories.firstIndex(where: { $0.category == transaction.category }) else { return }

        categories[index].fact += amount
        withAnimation(.easeInOut(duration: 0.24)) {
            isAddTransactionPresented = false
        }
        activePicker = nil
    }

    func formatAmount(_ value: Int, withSign: Bool = false) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = " "
        formatter.maximumFractionDigits = 0

        let number = NSNumber(value: abs(value))
        let formattedValue = formatter.string(from: number) ?? "\(abs(value))"

        if withSign {
            let sign = value >= 0 ? "+" : "-"
            return "\(sign)\(formattedValue) ₽"
        }

        return "\(formattedValue) ₽"
    }

    func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd.MM.yyyy"
        return formatter.string(from: date)
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

    func fieldButtonRow(value: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Text(value)
                    .font(.playfairDisplay(22, weight: .semibold))
                    .foregroundStyle(.black)
                    .lineLimit(1)

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(Color(.green))
            }
            .padding(.horizontal, 14)
            .frame(height: 56)
            .background(.white)
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
    }

    var categoryPicker: some View {
        Picker("Категория", selection: $transaction.category) {
            ForEach(categories.map(\.category), id: \.self) { categoryName in
                Text(categoryName).tag(categoryName)
            }
        }
        .pickerStyle(.wheel)
        .frame(height: 120)
        .background(Color(.systemGray5))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    var currencyPicker: some View {
        Picker("Валюта", selection: $transaction.currency) {
            Text("Рубль").tag("Рубль")
        }
        .pickerStyle(.wheel)
        .frame(height: 120)
        .background(Color(.systemGray5))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

private struct TransactionDraft {
    var amount: String = ""
    var category: String = "Еда"
    var date: Date = .now
    var currency: String = "Рубль"

    init(defaultCategory: String = "Еда") {
        category = defaultCategory
    }
}

private enum AddTransactionPicker {
    case category
    case date
    case currency
}

private struct BottomMenuBar: View {
    var body: some View {
        HStack(spacing: 6) {
            menuItem(symbol: "arrow.up", title: "Доход", isSelected: false)
            menuItem(symbol: "creditcard", title: "Расход", isSelected: true)
            menuItem(symbol: "chart.bar.fill", title: "Аналитика", isSelected: false)
            menuItem(symbol: "checkmark.rectangle.stack", title: "Цели", isSelected: false)
        }
        .padding(.top, 10)
        .padding(.bottom, 6)
        .background(.white)
    }

    private func menuItem(symbol: String, title: String, isSelected: Bool) -> some View {
        VStack(spacing: 6) {
            Image(systemName: symbol)
                .font(.system(size: 30))
                .foregroundStyle(isSelected ? Color(.green) : Color(.gray))

            Text(title)
                .font(.playfairDisplay(18))
                .foregroundStyle(isSelected ? .black : Color(.gray))
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
    }
}
