import SwiftUI

struct ExpensesView: View {
    @State private var categories: [ExpenseCategory] = [
        .init(category: "Еда", plan: 0, fact: 0),
        .init(category: "Транспорт", plan: 0, fact: 0),
        .init(category: "Красота", plan: 0, fact: 0)
    ]
    @State private var allTransactions: [ExpenseTransaction] = []
    @State private var selectedPage = 0
    @State private var isAddTransactionPresented = false
    @State private var transaction = TransactionDraft()
    @State private var activePicker: AddTransactionPicker?
    @FocusState private var isAmountInputFocused: Bool
    @State private var categoryEditingTransaction: ExpenseTransaction?
    @State private var categoryEditingDraft = ""
    @State private var dateEditingTransaction: ExpenseTransaction?
    @State private var dateEditingDraft: Date = .now
    @State private var amountEditingTransaction: ExpenseTransaction?
    @State private var amountEditingDraft = ""
    @FocusState private var isAmountEditingFocused: Bool

    private let monthlyIncome = 0
    private let transactionsStorageKey = "budget.expense.transactions.v1"

    private var totalPlan: Int {
        categoriesForCurrentMonth.reduce(0) { $0 + $1.plan }
    }

    private var totalFact: Int {
        categoriesForCurrentMonth.reduce(0) { $0 + $1.fact }
    }

    private var deltaText: String {
        let delta = monthlyIncome - totalFact
        return formatAmount(delta, withSign: true)
    }

    private var currentMonthTransactions: [ExpenseTransaction] {
        allTransactions
            .filter { transaction in
                Calendar.current.isDate(transaction.date, equalTo: Date(), toGranularity: .month) &&
                Calendar.current.isDate(transaction.date, equalTo: Date(), toGranularity: .year)
            }
            .sorted { $0.date < $1.date }
    }

    private var categoriesForCurrentMonth: [ExpenseCategory] {
        let totalsByCategory = Dictionary(
            grouping: currentMonthTransactions,
            by: \.category
        ).mapValues { list in
            list.reduce(0) { $0 + $1.amount }
        }

        return categories.map { category in
            var updatedCategory = category
            updatedCategory.fact = totalsByCategory[category.category] ?? 0
            return updatedCategory
        }
    }

    private var isTransactionEditorVisible: Bool {
        categoryEditingTransaction != nil || dateEditingTransaction != nil || amountEditingTransaction != nil
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            Color(.beige)
                .ignoresSafeArea()

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

                TabView(selection: $selectedPage) {
                    TotalTableView(
                        categories: categoriesForCurrentMonth,
                        totalPlan: totalPlan,
                        totalFact: totalFact
                    )
                    .tag(0)

                    TransactionsMonthTableView(
                        transactions: currentMonthTransactions,
                        onDelete: { transaction in
                            deleteTransaction(transaction.id)
                        },
                        onEditCategory: { transaction in
                            withAnimation(.easeInOut(duration: 0.22)) {
                                categoryEditingDraft = transaction.category
                                categoryEditingTransaction = transaction
                            }
                        },
                        onEditDate: { transaction in
                            withAnimation(.easeInOut(duration: 0.22)) {
                                dateEditingDraft = transaction.date
                                dateEditingTransaction = transaction
                            }
                        },
                        onEditAmount: { transaction in
                            withAnimation(.easeInOut(duration: 0.22)) {
                                amountEditingDraft = String(transaction.amount)
                                amountEditingTransaction = transaction
                            }
                        }
                    )
                        .tag(1)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .frame(maxHeight: .infinity)

                HStack(spacing: 8) {
                    Circle()
                        .fill(selectedPage == 0 ? Color(.green) : Color(.gray).opacity(0.4))
                        .frame(width: 10, height: 10)
                    Circle()
                        .fill(selectedPage == 1 ? Color(.green) : Color(.gray).opacity(0.4))
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

            if isTransactionEditorVisible {
                Color.black.opacity(0.2)
                    .ignoresSafeArea()
                    .onTapGesture {
                        closeTransactionEditors()
                    }
                    .transition(.opacity)
                    .zIndex(1)
            }

            transactionEditingOverlay
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                .zIndex(2)

            if isAddTransactionPresented {
                addTransactionOverlay
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .zIndex(3)
            }
        }
        .onAppear {
            loadTransactions()
        }
    }
}

#Preview {
    ExpensesView()
}

private extension ExpensesView {
    @ViewBuilder
    var transactionEditingOverlay: some View {
        if let editing = dateEditingTransaction {
            VStack(spacing: 12) {
                DatePicker("", selection: $dateEditingDraft, in: ...Date(), displayedComponents: .date)
                    .datePickerStyle(.wheel)
                    .labelsHidden()
                    .frame(height: 180)

                HStack(spacing: 12) {
                    Button("Отмена") {
                        closeTransactionEditors()
                    }
                    .font(.playfairDisplay(20, weight: .semibold))
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(Color(.systemGray5))
                    .clipShape(RoundedRectangle(cornerRadius: 10))

                    Button("ОК") {
                        updateTransaction(
                            editing.id,
                            category: editing.category,
                            date: dateEditingDraft,
                            amount: editing.amount
                        )
                        closeTransactionEditors()
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
        } else if let editing = categoryEditingTransaction {
            VStack(spacing: 12) {
                Picker("Категория", selection: $categoryEditingDraft) {
                    ForEach(categories.map(\.category), id: \.self) { category in
                        Text(category).tag(category)
                    }
                }
                .pickerStyle(.wheel)
                .labelsHidden()
                .frame(height: 180)

                HStack(spacing: 12) {
                    Button("Отмена") {
                        closeTransactionEditors()
                    }
                    .font(.playfairDisplay(20, weight: .semibold))
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(Color(.systemGray5))
                    .clipShape(RoundedRectangle(cornerRadius: 10))

                    Button("ОК") {
                        updateTransaction(
                            editing.id,
                            category: categoryEditingDraft,
                            date: editing.date,
                            amount: editing.amount
                        )
                        closeTransactionEditors()
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
        } else if let editing = amountEditingTransaction {
            VStack(spacing: 12) {
                Text("Введите значение")
                    .font(.playfairDisplay(24, weight: .semibold))
                    .foregroundStyle(.black)

                TextField(
                    "0",
                    text: Binding(
                        get: { formattedAmountInput(amountEditingDraft) },
                        set: { amountEditingDraft = normalizedAmountInput($0) }
                    )
                )
                .focused($isAmountEditingFocused)
                .font(.playfairDisplay(36, weight: .semibold))
                .foregroundStyle(.black)
                .keyboardType(.numberPad)
                .padding(.horizontal, 12)
                .frame(height: 56)
                .background(.white)
                .clipShape(RoundedRectangle(cornerRadius: 10))

                HStack(spacing: 12) {
                    Button("Отмена") {
                        closeTransactionEditors()
                    }
                    .font(.playfairDisplay(20, weight: .semibold))
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(Color(.systemGray5))
                    .clipShape(RoundedRectangle(cornerRadius: 10))

                    Button("ОК") {
                        let cleaned = amountEditingDraft.replacingOccurrences(of: " ", with: "")
                        guard let amount = Int(cleaned), amount > 0 else { return }
                        updateTransaction(
                            editing.id,
                            category: editing.category,
                            date: editing.date,
                            amount: amount
                        )
                        closeTransactionEditors()
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
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    isAmountEditingFocused = true
                }
            }
        }
    }

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
                    DatePicker("", selection: $transaction.date, in: ...Date(), displayedComponents: .date)
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
                    .font(.playfairDisplay(20, weight: .semibold))
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(Color(.systemGray5))
                    .clipShape(RoundedRectangle(cornerRadius: 10))

                    Button("ОК") {
                        addTransaction()
                    }
                    .font(.playfairDisplay(20, weight: .semibold))
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
        guard categories.contains(where: { $0.category == transaction.category }) else { return }

        allTransactions.append(
            ExpenseTransaction(
                category: transaction.category,
                amount: amount,
                date: transaction.date,
                currency: transaction.currency
            )
        )
        saveTransactions()
        withAnimation(.easeInOut(duration: 0.24)) {
            isAddTransactionPresented = false
        }
        activePicker = nil
        selectedPage = 1
        transaction = TransactionDraft(defaultCategory: categories.first?.category ?? "Еда")
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

    func closeTransactionEditors() {
        withAnimation(.easeInOut(duration: 0.22)) {
            categoryEditingTransaction = nil
            dateEditingTransaction = nil
            amountEditingTransaction = nil
        }
        amountEditingDraft = ""
        isAmountEditingFocused = false
    }

    func saveTransactions() {
        guard let data = try? JSONEncoder().encode(allTransactions) else { return }
        UserDefaults.standard.set(data, forKey: transactionsStorageKey)
    }

    func loadTransactions() {
        guard let data = UserDefaults.standard.data(forKey: transactionsStorageKey) else { return }
        guard let transactions = try? JSONDecoder().decode([ExpenseTransaction].self, from: data) else { return }
        allTransactions = transactions
    }

    func deleteTransaction(_ id: UUID) {
        allTransactions.removeAll { $0.id == id }
        saveTransactions()
    }

    func updateTransaction(_ id: UUID, category: String, date: Date, amount: Int) {
        guard let index = allTransactions.firstIndex(where: { $0.id == id }) else { return }
        allTransactions[index] = ExpenseTransaction(
            id: id,
            category: category,
            amount: amount,
            date: date,
            currency: allTransactions[index].currency
        )
        saveTransactions()
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

private struct ExpenseTransaction: Identifiable, Codable {
    let id: UUID
    let category: String
    let amount: Int
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

private struct TransactionsMonthTableView: View {
    let transactions: [ExpenseTransaction]
    var onDelete: (ExpenseTransaction) -> Void
    var onEditCategory: (ExpenseTransaction) -> Void
    var onEditDate: (ExpenseTransaction) -> Void
    var onEditAmount: (ExpenseTransaction) -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Text("Категория")
                    .font(.playfairDisplay(20))
                    .frame(maxWidth: .infinity, alignment: .leading)

                Text("Дата")
                    .font(.playfairDisplay(20))
                    .frame(width: 110, alignment: .leading)

                Text("Сумма")
                    .font(.playfairDisplay(20))
                    .frame(width: 110, alignment: .leading)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 8)

            Divider()
                .overlay(Color(.gray).opacity(0.3))

            List {
                ForEach(transactions) { transaction in
                    HStack(spacing: 12) {
                        Text(transaction.category)
                            .lineLimit(1)
                            .truncationMode(.tail)
                            .font(.playfairDisplay(20))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .contentShape(Rectangle())
                            .onLongPressGesture(minimumDuration: 0.5) {
                                onEditCategory(transaction)
                            }

                        Text(formatDate(transaction.date))
                            .font(.playfairDisplay(18))
                            .frame(width: 110, alignment: .leading)
                            .contentShape(Rectangle())
                            .onLongPressGesture(minimumDuration: 0.5) {
                                onEditDate(transaction)
                            }

                        Text(formatAmount(transaction.amount))
                            .font(.playfairDisplay(20))
                            .frame(width: 110, alignment: .leading)
                            .contentShape(Rectangle())
                            .onLongPressGesture(minimumDuration: 0.5) {
                                onEditAmount(transaction)
                            }
                    }
                    .listRowInsets(EdgeInsets(top: 8, leading: 20, bottom: 8, trailing: 20))
                    .listRowBackground(Color(.beige))
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button(role: .destructive) {
                            onDelete(transaction)
                        } label: {
                            Text("Удалить")
                        }
                    }
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
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

        let number = NSNumber(value: value)
        return (formatter.string(from: number) ?? "\(value)") + " ₽"
    }
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
