import SwiftUI

private let earliestReportDate = Calendar.current.date(from: DateComponents(year: 2019, month: 12, day: 1))!
private let newCategoryKey = "__NEW__"

struct FinanceDashboardView: View {
    let mode: FinanceMode
    @Binding var isOverlayPresented: Bool
    @Binding var isBottomGreenFillPresented: Bool
    @Binding var selectedReportMonth: Int
    @Binding var selectedReportYear: Int
    @State private var categories: [ExpenseCategory]
    @State private var allTransactions: [ExpenseTransaction] = []
    @State private var selectedPage = 0
    @State private var isMonthPickerPresented = false
    @State private var monthPickerDraftMonth = Calendar.current.component(.month, from: Date())
    @State private var monthPickerDraftYear = Calendar.current.component(.year, from: Date())
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
    @State private var planEditingCategoryName: String?
    @State private var planEditingDraft = ""
    @FocusState private var isPlanEditingFocused: Bool
    @State private var categoryNameEditingCategory: String?
    @State private var categoryNameEditingDraft = ""
    @State private var isSettingsPresented = false
    @State private var baseCurrencyCodeSnapshot = AppCurrency.normalize(AppSettingsCurrency.loadBaseCurrencyCode())
    @State private var newCategoryDraft = ""
    @State private var categoryToDelete: String?

    @State private var ratesByDateKey: [String: [String: Double]] = [:]
    @State private var isRatesLoading = false

    private var totalPlan: Int {
        categoriesForCurrentMonth.reduce(0) { $0 + $1.plan }
    }

    private var totalFact: Int {
        categoriesForCurrentMonth.reduce(0) { $0 + $1.fact }
    }

    private var deltaText: String {
        formatAmount(globalDelta, withSign: true)
    }

    private var selectedReportDate: Date {
        Calendar.current.date(from: DateComponents(year: selectedReportYear, month: selectedReportMonth, day: 1)) ?? Date()
    }

    private var currentMonthTransactions: [ExpenseTransaction] {
        allTransactions
            .filter { transaction in
                Calendar.current.isDate(transaction.date, equalTo: selectedReportDate, toGranularity: .month) &&
                Calendar.current.isDate(transaction.date, equalTo: selectedReportDate, toGranularity: .year)
            }
            .sorted { $0.date < $1.date }
    }

    private var currentMonthTransactionsForDisplay: [ExpenseTransaction] {
        currentMonthTransactions.map { tx in
            ExpenseTransaction(
                id: tx.id,
                category: tx.category,
                amount: convertedAmount(tx.amount, fromCurrencyCode: tx.currency, on: tx.date),
                date: tx.date,
                currency: baseCurrencyCode
            )
        }
    }

    private var categoriesForCurrentMonth: [ExpenseCategory] {
        let totalsByCategory = Dictionary(
            grouping: currentMonthTransactions,
            by: \.category
        ).mapValues { list in
            list.reduce(0) { sum, tx in
                sum + convertedAmount(tx.amount, fromCurrencyCode: tx.currency, on: tx.date)
            }
        }

        return categories.map { category in
            var updatedCategory = category
            updatedCategory.plan = convertedAmount(category.plan, fromCurrencyCode: AppCurrency.RUB.rawValue, on: selectedReportDate)
            updatedCategory.fact = totalsByCategory[category.category] ?? 0
            return updatedCategory
        }
    }

    private var isTransactionEditorVisible: Bool {
        categoryEditingTransaction != nil || dateEditingTransaction != nil || amountEditingTransaction != nil
    }

    private var isPlanEditorVisible: Bool {
        planEditingCategoryName != nil
    }

    private var isCategoryNameEditorVisible: Bool {
        categoryNameEditingCategory != nil
    }

    private var isMonthPickerVisible: Bool {
        isMonthPickerPresented
    }

    private var globalDelta: Int {
        totalFactForMonth(mode: .income, month: selectedReportMonth, year: selectedReportYear) -
        totalFactForMonth(mode: .expense, month: selectedReportMonth, year: selectedReportYear)
    }

    private var baseCurrencyCode: String {
        AppCurrency.normalize(AppSettingsCurrency.loadBaseCurrencyCode())
    }

    private var baseCurrencySymbol: String {
        AppCurrency.symbol(for: baseCurrencyCode)
    }

    private static let monthNames = [
        "январь", "февраль", "март", "апрель", "май", "июнь",
        "июль", "август", "сентябрь", "октябрь", "ноябрь", "декабрь"
    ]

    private var selectedMonthDisplayText: String {
        let yearShort = selectedReportYear % 100
        return "\(Self.monthNames[selectedReportMonth - 1]) \(yearShort)"
    }

    private var availableYears: [Int] {
        Array(2019...Calendar.current.component(.year, from: Date()))
    }

    private func availableMonths(for year: Int) -> [Int] {
        let now = Date()
        let currentYear = Calendar.current.component(.year, from: now)
        let currentMonth = Calendar.current.component(.month, from: now)
        if year == 2019 {
            return [12]
        }
        if year == currentYear {
            return Array(1...currentMonth)
        }
        return Array(1...12)
    }

    private var transactionsStorageKey: String {
        mode.storageKey
    }

    private var isAddTransactionOkDisabled: Bool {
        let amountCents = AppMoney.parseToCents(transaction.amount) ?? 0
        let amountInvalid = amountCents <= 0
        let newCategoryEmpty = transaction.category == newCategoryKey && newCategoryDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        return amountInvalid || newCategoryEmpty
    }

    init(
        mode: FinanceMode = .expense,
        isOverlayPresented: Binding<Bool> = .constant(false),
        isBottomGreenFillPresented: Binding<Bool> = .constant(false),
        selectedReportMonth: Binding<Int>? = nil,
        selectedReportYear: Binding<Int>? = nil
    ) {
        self.mode = mode
        _isOverlayPresented = isOverlayPresented
        _isBottomGreenFillPresented = isBottomGreenFillPresented
        let calendar = Calendar.current
        let now = Date()
        _selectedReportMonth = selectedReportMonth ?? .constant(calendar.component(.month, from: now))
        _selectedReportYear = selectedReportYear ?? .constant(calendar.component(.year, from: now))
        _categories = State(initialValue: [])
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            Color(.beige)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                HStack {
                    Spacer()

                    SettingsButton {
                        isSettingsPresented = true
                    }
                }
                .padding(.top, 0)

                HStack {
                    Text("Дельта: \(deltaText)")
                        .font(.playfairDisplay(31, weight: .bold))
                        .minimumScaleFactor(0.65)
                        .lineLimit(1)
                        .foregroundStyle(Color(.green))

                    Spacer()
                }
                .padding(.top, -8)
                .padding(.horizontal, AppLayout.screenHorizontalPadding)

                HStack {
                    Text(mode.screenTitle)
                        .font(.playfairDisplay(30, weight: .semibold))
                        .foregroundStyle(Color(.green))

                    Spacer()

                    Button {
                        monthPickerDraftMonth = selectedReportMonth
                        monthPickerDraftYear = selectedReportYear
                        withAnimation(.easeInOut(duration: 0.22)) {
                            isMonthPickerPresented = true
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Text(selectedMonthDisplayText)
                                .font(.playfairDisplay(28, weight: .semibold))
                                .foregroundStyle(Color(.green))
                            Image(systemName: "chevron.right")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundStyle(Color(.green))
                        }
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, AppLayout.screenHorizontalPadding)
                .padding(.bottom, 8)

                TabView(selection: $selectedPage) {
                    TotalTableView(
                        categories: categoriesForCurrentMonth,
                        totalPlan: totalPlan,
                        totalFact: totalFact,
                        isRedWhenFactLessThanPlan: mode == .income,
                        onPlanTap: { categoryName in
                            withAnimation(.easeInOut(duration: 0.22)) {
                                planEditingCategoryName = categoryName
                                if let category = categoriesForCurrentMonth.first(where: { $0.category == categoryName }) {
                                    planEditingDraft = AppMoney.formatCentsForInput(category.plan)
                                } else {
                                    planEditingDraft = ""
                                }
                            }
                        },
                        onCategoryTap: { categoryName in
                            withAnimation(.easeInOut(duration: 0.22)) {
                                categoryNameEditingCategory = categoryName
                                categoryNameEditingDraft = categoryName
                            }
                        },
                        onDeleteCategory: { categoryName in
                            categoryToDelete = categoryName
                        }
                    )
                    .tag(0)

                    TransactionsMonthTableView(
                        transactions: currentMonthTransactionsForDisplay,
                        currencySymbol: baseCurrencySymbol,
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
                                amountEditingDraft = AppMoney.formatCentsForInput(transaction.amount)
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
                    transaction = TransactionDraft(defaultCategory: categories.first?.category ?? newCategoryKey)
                    transaction.currency = baseCurrencyCode
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
                .padding(.horizontal, AppLayout.screenHorizontalPadding)
                .padding(.bottom, 4)
            }

            if isTransactionEditorVisible || isPlanEditorVisible || isCategoryNameEditorVisible || isMonthPickerVisible {
                Color.black.opacity(0.2)
                    .ignoresSafeArea()
                    .onTapGesture {
                        closeTransactionEditors()
                        closePlanEditor()
                        closeCategoryNameEditor()
                        closeMonthPicker()
                    }
                    .transition(.opacity)
                    .zIndex(1)
            }

            if isMonthPickerPresented {
                monthPickerOverlay
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                    .zIndex(2)
            }

            transactionEditingOverlay
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                .zIndex(2)

            planEditingOverlay
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                .zIndex(2)

            categoryNameEditingOverlay
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
            loadCategories()
            loadCategoryPlans()
            syncOverlayState()
            syncBottomGreenFillState()
            Task { await refreshCurrencyRatesForVisibleMonth() }
        }
        .onChange(of: isAddTransactionPresented) { _ in
            syncOverlayState()
            syncBottomGreenFillState()
        }
        .onChange(of: categoryEditingTransaction != nil) { _ in
            syncOverlayState()
        }
        .onChange(of: dateEditingTransaction != nil) { _ in
            syncOverlayState()
        }
        .onChange(of: amountEditingTransaction != nil) { _ in
            syncOverlayState()
        }
        .onChange(of: planEditingCategoryName != nil) { _ in
            syncOverlayState()
        }
        .onChange(of: categoryNameEditingCategory != nil) { _ in
            syncOverlayState()
        }
        .onChange(of: isMonthPickerPresented) { _ in
            syncOverlayState()
        }
        .onChange(of: selectedReportMonth) { _ in
            Task { await refreshCurrencyRatesForVisibleMonth() }
        }
        .onChange(of: selectedReportYear) { _ in
            Task { await refreshCurrencyRatesForVisibleMonth() }
        }
        .onChange(of: isSettingsPresented) { _ in
            guard !isSettingsPresented else { return }
            let updated = AppCurrency.normalize(AppSettingsCurrency.loadBaseCurrencyCode())
            guard updated != baseCurrencyCodeSnapshot else { return }
            baseCurrencyCodeSnapshot = updated
            Task { await refreshCurrencyRatesForVisibleMonth() }
        }
        .alert("Удаление категории", isPresented: Binding(
            get: { categoryToDelete != nil },
            set: { if !$0 { categoryToDelete = nil } }
        )) {
            Button("Отмена", role: .cancel) {
                categoryToDelete = nil
            }
            Button("Да", role: .destructive) {
                if let name = categoryToDelete {
                    deleteCategory(name)
                    categoryToDelete = nil
                }
            }
        } message: {
            Text("Вы уверены, что хотите удалить категорию?")
        }
        .onDisappear {
            isOverlayPresented = false
            isBottomGreenFillPresented = false
        }
        .fullScreenCover(isPresented: $isSettingsPresented) {
            AppSettingsView(onBack: { isSettingsPresented = false })
        }
    }
}

#Preview {
    struct PreviewWrapper: View {
        @State private var month = Calendar.current.component(.month, from: Date())
        @State private var year = Calendar.current.component(.year, from: Date())
        var body: some View {
            FinanceDashboardView(
                mode: .expense,
                selectedReportMonth: $month,
                selectedReportYear: $year
            )
        }
    }
    return PreviewWrapper()
}

private extension FinanceDashboardView {
    @ViewBuilder
    var planEditingOverlay: some View {
        if let categoryName = planEditingCategoryName {
            VStack(spacing: 12) {
                Text("План: \(categoryName)")
                    .font(.playfairDisplay(24, weight: .semibold))
                    .foregroundStyle(.black)

                TextField(
                    "0",
                    text: Binding(
                        get: { formattedAmountInput(planEditingDraft) },
                        set: { planEditingDraft = normalizedAmountInput($0) }
                    )
                )
                .focused($isPlanEditingFocused)
                .keyboardType(.decimalPad)
                .font(.playfairDisplay(36, weight: .semibold))
                .foregroundStyle(.black)
                .padding(.horizontal, 12)
                .frame(height: 56)
                .background(.white)
                .clipShape(RoundedRectangle(cornerRadius: 10))

                HStack(spacing: 12) {
                    Button("Отмена") {
                        closePlanEditor()
                    }
                    .font(.playfairDisplay(20, weight: .semibold))
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(Color(.systemGray5))
                    .clipShape(RoundedRectangle(cornerRadius: 10))

                    Button("ОК") {
                        guard let planCents = AppMoney.parseToCents(planEditingDraft), planCents >= 0 else { return }
                        updateCategoryPlan(categoryName: categoryName, plan: planCents)
                        closePlanEditor()
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
                    isPlanEditingFocused = true
                }
            }
        }
    }

    @ViewBuilder
    var categoryNameEditingOverlay: some View {
        if let oldName = categoryNameEditingCategory {
            VStack(spacing: 12) {
                Text("Название категории")
                    .font(.playfairDisplay(24, weight: .semibold))
                    .foregroundStyle(.black)

                TextField("Название", text: $categoryNameEditingDraft)
                    .font(.playfairDisplay(20, weight: .semibold))
                    .padding(.horizontal, 14)
                    .frame(height: 56)
                    .background(.white)
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color(.gray).opacity(0.5), lineWidth: 1))
                    .clipShape(RoundedRectangle(cornerRadius: 10))

                HStack(spacing: 12) {
                    Button("Отмена") {
                        closeCategoryNameEditor()
                    }
                    .font(.playfairDisplay(20, weight: .semibold))
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(Color(.systemGray5))
                    .clipShape(RoundedRectangle(cornerRadius: 10))

                    Button("ОК") {
                        let newName = categoryNameEditingDraft.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !newName.isEmpty else { return }
                        if newName != oldName {
                            guard !categories.contains(where: { $0.category == newName }) else { return }
                            renameCategory(from: oldName, to: newName)
                        }
                        closeCategoryNameEditor()
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
        }
    }

    var monthPickerOverlay: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                Picker("Месяц", selection: $monthPickerDraftMonth) {
                    ForEach(availableMonths(for: monthPickerDraftYear), id: \.self) { month in
                        Text(Self.monthNames[month - 1]).tag(month)
                    }
                }
                .pickerStyle(.wheel)
                .labelsHidden()
                .frame(maxWidth: .infinity)

                Picker("Год", selection: $monthPickerDraftYear) {
                    ForEach(availableYears, id: \.self) { year in
                        Text(String(year)).tag(year)
                    }
                }
                .pickerStyle(.wheel)
                .labelsHidden()
                .frame(maxWidth: .infinity)
            }
            .frame(height: 180)
            .onChange(of: monthPickerDraftYear) { newYear in
                let months = availableMonths(for: newYear)
                if !months.contains(monthPickerDraftMonth) {
                    monthPickerDraftMonth = months.first ?? 1
                }
            }

            HStack(spacing: 12) {
                Button("Отмена") {
                    closeMonthPicker()
                }
                .font(.playfairDisplay(20, weight: .semibold))
                .foregroundStyle(.black)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(Color(.systemGray5))
                .clipShape(RoundedRectangle(cornerRadius: 10))

                Button("ОК") {
                    selectedReportMonth = monthPickerDraftMonth
                    selectedReportYear = monthPickerDraftYear
                    closeMonthPicker()
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
    }

    @ViewBuilder
    var transactionEditingOverlay: some View {
        if let editing = dateEditingTransaction {
            VStack(spacing: 12) {
                DatePicker("", selection: $dateEditingDraft, in: earliestReportDate...Date(), displayedComponents: .date)
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
                        Task { @MainActor in
                            await updateTransaction(
                                editing.id,
                                category: editing.category,
                                date: dateEditingDraft,
                                amount: editing.amount
                            )
                            closeTransactionEditors()
                        }
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
                    ForEach(categoryPickerOptions, id: \.self) { option in
                        Text(option == newCategoryKey ? "Новая" : option).tag(option)
                    }
                }
                .pickerStyle(.wheel)
                .labelsHidden()
                .frame(height: 180)

                if categoryEditingDraft == newCategoryKey {
                    TextField("Название категории", text: $newCategoryDraft)
                        .font(.playfairDisplay(20, weight: .semibold))
                        .foregroundStyle(.black)
                        .padding(.horizontal, 12)
                        .frame(height: 50)
                        .background(Color(.systemGray5))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }

                HStack(spacing: 12) {
                    Button("Отмена") {
                        newCategoryDraft = ""
                        closeTransactionEditors()
                    }
                    .font(.playfairDisplay(20, weight: .semibold))
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(Color(.systemGray5))
                    .clipShape(RoundedRectangle(cornerRadius: 10))

                    Button("ОК") {
                        var categoryToUse = categoryEditingDraft
                        if categoryEditingDraft == newCategoryKey {
                            let name = newCategoryDraft.trimmingCharacters(in: .whitespacesAndNewlines)
                            guard !name.isEmpty, !categories.contains(where: { $0.category == name }) else { return }
                            categories.append(ExpenseCategory(category: name, plan: 0, fact: 0))
                            saveCategories()
                            categoryToUse = name
                            newCategoryDraft = ""
                        }
                        Task { @MainActor in
                            await updateTransaction(
                                editing.id,
                                category: categoryToUse,
                                date: editing.date,
                                amount: editing.amount
                            )
                            closeTransactionEditors()
                        }
                    }
                    .font(.playfairDisplay(20, weight: .semibold))
                    .foregroundStyle(Color(.green))
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .disabled(categoryEditingDraft == newCategoryKey && newCategoryDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .opacity(categoryEditingDraft == newCategoryKey && newCategoryDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.5 : 1)
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
                .font(.playfairDisplay(24, weight: .semibold))
                .foregroundStyle(.black)
                .keyboardType(.decimalPad)
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
                        guard let amountCents = AppMoney.parseToCents(amountEditingDraft), amountCents > 0 else { return }
                        Task { @MainActor in
                            await updateTransaction(
                                editing.id,
                                category: editing.category,
                                date: editing.date,
                                amount: amountCents
                            )
                            closeTransactionEditors()
                        }
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
                    isAmountInputFocused = false
                    withAnimation(.easeInOut(duration: 0.24)) {
                        isAddTransactionPresented = false
                    }
                    activePicker = nil
                }

            Color(.green)
                .frame(height: 180)
                .ignoresSafeArea(edges: .bottom)

            VStack(alignment: .leading, spacing: 12) {
                Text("Сумма")
                    .font(.playfairDisplay(20, weight: .semibold))
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
                        .font(.playfairDisplay(20, weight: .semibold))
                        .foregroundStyle(.black)
                        .keyboardType(.decimalPad)
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
                .frame(height: 50)
                .background(.white)
                .clipShape(RoundedRectangle(cornerRadius: 10))

                Text("Категория")
                    .font(.playfairDisplay(20, weight: .semibold))
                    .foregroundStyle(.white)

                fieldButtonRow(value: transaction.category == newCategoryKey ? "Новая" : transaction.category) {
                    isAmountInputFocused = false
                    if categories.isEmpty {
                        transaction.category = newCategoryKey
                    } else {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            activePicker = activePicker == .category ? nil : .category
                        }
                    }
                }

                if transaction.category == newCategoryKey {
                    TextField("Название категории", text: $newCategoryDraft)
                        .font(.playfairDisplay(20, weight: .semibold))
                        .foregroundStyle(.black)
                        .padding(.horizontal, 14)
                        .frame(height: 50)
                        .background(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }

                if activePicker == .category {
                    categoryPicker
                        .transition(.opacity.combined(with: .move(edge: .top)))
                        .onChange(of: transaction.category) { newValue in
                            if newValue == newCategoryKey {
                                activePicker = nil
                            }
                        }
                }

                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Дата")
                            .font(.playfairDisplay(20, weight: .semibold))
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
                            .font(.playfairDisplay(20, weight: .semibold))
                            .foregroundStyle(.white)

                        fieldButtonRow(value: AppCurrency.displayName(for: transaction.currency)) {
                            isAmountInputFocused = false
                            withAnimation(.easeInOut(duration: 0.2)) {
                                activePicker = activePicker == .currency ? nil : .currency
                            }
                        }
                    }
                }

                if activePicker == .date {
                    DatePicker("", selection: $transaction.date, in: earliestReportDate...Date(), displayedComponents: .date)
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
                        newCategoryDraft = ""
                    }
                    .font(.playfairDisplay(18, weight: .semibold))
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(Color(.systemGray5))
                    .clipShape(RoundedRectangle(cornerRadius: 10))

                    Button("ОК") {
                        addTransaction()
                    }
                    .font(.playfairDisplay(18, weight: .semibold))
                    .foregroundStyle(Color(.green))
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .disabled(isAddTransactionOkDisabled)
                    .opacity(isAddTransactionOkDisabled ? 0.5 : 1)
                }
                .padding(.top, 14)
                .padding(.bottom, 12)
            }
            .padding(14)
            .background(Color(.green))
            .clipShape(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
            )
            .padding(.bottom, 56)
            .onTapGesture {
                isAmountInputFocused = false
            }
        }
        .ignoresSafeArea(edges: .bottom)
    }

    func addTransaction() {
        guard let amountCents = AppMoney.parseToCents(transaction.amount), amountCents > 0 else { return }
        guard transaction.date >= earliestReportDate else { return }

        let addedDate = transaction.date
        let addedCurrencyCode = AppCurrency.normalize(transaction.currency)

        var categoryToUse = transaction.category
        if transaction.category == newCategoryKey {
            let name = newCategoryDraft.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !name.isEmpty, !categories.contains(where: { $0.category == name }) else { return }
            categories.append(ExpenseCategory(category: name, plan: 0, fact: 0))
            saveCategories()
            categoryToUse = name
            newCategoryDraft = ""
        } else {
            guard categories.contains(where: { $0.category == transaction.category }) else { return }
        }

        allTransactions.append(
            ExpenseTransaction(
                category: categoryToUse,
                amount: amountCents,
                date: transaction.date,
                currency: transaction.currency
            )
        )
        saveTransactions()
        // Fetch rates only when conversion is needed for this new transaction.
        if addedCurrencyCode != baseCurrencyCode {
            Task { await refreshCurrencyRatesForDatesIfNeeded([addedDate]) }
        }
        withAnimation(.easeInOut(duration: 0.24)) {
            isAddTransactionPresented = false
        }
        activePicker = nil
        selectedPage = 1
        transaction = TransactionDraft(defaultCategory: categories.first?.category ?? newCategoryKey)
        transaction.currency = baseCurrencyCode
        newCategoryDraft = ""
    }

    func formatAmount(_ value: Int, withSign: Bool = false) -> String {
        let absCents = abs(value)
        let absString = AppMoney.formatCentsForInput(absCents)
        if withSign {
            let sign = value >= 0 ? "+" : "-"
            return "\(sign)\(absString) \(baseCurrencySymbol)"
        } else {
            let prefix = value < 0 ? "-" : ""
            return "\(prefix)\(absString) \(baseCurrencySymbol)"
        }
    }

    private func dateKey(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar.current
        formatter.timeZone = TimeZone.current
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    // Converts `amount` from `fromCurrencyCode` to the base currency from settings,
    // using cached CBRCurrencyRates for the given date.
    private func convertedAmount(_ amount: Int, fromCurrencyCode rawFromCurrencyCode: String, on date: Date) -> Int {
        let fromCurrencyCode = AppCurrency.normalize(rawFromCurrencyCode)
        let toCurrencyCode = baseCurrencyCode

        if fromCurrencyCode == toCurrencyCode { return amount }

        let key = dateKey(date)
        let rates = ratesByDateKey[key] ?? [:]

        let rubPerFrom: Double
        if fromCurrencyCode == AppCurrency.RUB.rawValue {
            rubPerFrom = 1.0
        } else if let rate = rates[fromCurrencyCode] {
            rubPerFrom = rate
        } else {
            return amount
        }

        let rubPerTo: Double
        if toCurrencyCode == AppCurrency.RUB.rawValue {
            rubPerTo = 1.0
        } else if let rate = rates[toCurrencyCode] {
            rubPerTo = rate
        } else {
            return amount
        }

        guard rubPerTo != 0 else { return amount }
        let converted = Double(amount) * rubPerFrom / rubPerTo
        return Int(converted.rounded())
    }

    // Converts `amount` from currency into RUB, using cached CBRCurrencyRates for the given date.
    private func convertedAmountToRUB(_ amount: Int, fromCurrencyCode rawFromCurrencyCode: String, on date: Date) -> Int {
        let fromCurrencyCode = AppCurrency.normalize(rawFromCurrencyCode)
        if fromCurrencyCode == AppCurrency.RUB.rawValue { return amount }

        let key = dateKey(date)
        let rates = ratesByDateKey[key] ?? [:]
        guard let rubPerFrom = rates[fromCurrencyCode] else { return amount }

        let converted = Double(amount) * rubPerFrom
        return Int(converted.rounded())
    }

    func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd.MM.yyyy"
        return formatter.string(from: date)
    }

    func normalizedAmountInput(_ text: String) -> String {
        AppMoney.normalizeInput(text)
    }

    func formattedAmountInput(_ text: String) -> String {
        let normalized = AppMoney.normalizeInput(text)
        guard let cents = AppMoney.parseToCents(normalized) else { return normalized }
        return AppMoney.formatCentsForInput(cents)
    }

    func closeTransactionEditors() {
        withAnimation(.easeInOut(duration: 0.22)) {
            categoryEditingTransaction = nil
            dateEditingTransaction = nil
            amountEditingTransaction = nil
        }
        amountEditingDraft = ""
        newCategoryDraft = ""
        isAmountEditingFocused = false
        syncOverlayState()
    }

    func closePlanEditor() {
        withAnimation(.easeInOut(duration: 0.22)) {
            planEditingCategoryName = nil
        }
        planEditingDraft = ""
        isPlanEditingFocused = false
        syncOverlayState()
    }

    func closeCategoryNameEditor() {
        withAnimation(.easeInOut(duration: 0.22)) {
            categoryNameEditingCategory = nil
        }
        categoryNameEditingDraft = ""
        syncOverlayState()
    }

    func renameCategory(from oldName: String, to newName: String) {
        guard let index = categories.firstIndex(where: { $0.category == oldName }) else { return }
        let cat = categories[index]
        categories[index] = ExpenseCategory(id: cat.id, category: newName, plan: cat.plan, fact: cat.fact)
        for i in allTransactions.indices where allTransactions[i].category == oldName {
            allTransactions[i] = ExpenseTransaction(
                id: allTransactions[i].id,
                category: newName,
                amount: allTransactions[i].amount,
                date: allTransactions[i].date,
                currency: allTransactions[i].currency
            )
        }
        saveCategories()
        saveTransactions()
        saveCategoryPlans()
    }

    func syncOverlayState() {
        isOverlayPresented = isAddTransactionPresented || isTransactionEditorVisible || isPlanEditorVisible || isMonthPickerVisible
    }

    func closeMonthPicker() {
        withAnimation(.easeInOut(duration: 0.22)) {
            isMonthPickerPresented = false
        }
        syncOverlayState()
    }

    func deleteCategory(_ categoryName: String) {
        categories.removeAll { $0.category == categoryName }
        allTransactions.removeAll { $0.category == categoryName }
        saveCategories()
        saveTransactions()
    }

    func syncBottomGreenFillState() {
        isBottomGreenFillPresented = isAddTransactionPresented
    }

    func saveTransactions() {
        guard let data = try? JSONEncoder().encode(allTransactions) else { return }
        UserDefaults.standard.set(data, forKey: transactionsStorageKey)
    }

    func loadTransactions() {
        allTransactions = loadTransactions(for: transactionsStorageKey)
    }

    func loadTransactions(for storageKey: String) -> [ExpenseTransaction] {
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let transactions = try? JSONDecoder().decode([ExpenseTransaction].self, from: data) {
            return transactions
        }

        // Migration: v1 stored whole units, v2 stores cents.
        let legacyKey = storageKey.replacingOccurrences(of: ".v2", with: ".v1")
        guard legacyKey != storageKey,
              let legacyData = UserDefaults.standard.data(forKey: legacyKey),
              let legacyTransactions = try? JSONDecoder().decode([ExpenseTransaction].self, from: legacyData) else {
            return []
        }

        let migrated = legacyTransactions.map {
            ExpenseTransaction(
                id: $0.id,
                category: $0.category,
                amount: $0.amount * 100,
                date: $0.date,
                currency: $0.currency
            )
        }

        if let migratedData = try? JSONEncoder().encode(migrated) {
            UserDefaults.standard.set(migratedData, forKey: storageKey)
        }

        return migrated
    }

    @MainActor
    private func refreshCurrencyRatesForDatesIfNeeded(_ dates: [Date]) async {
        guard !isRatesLoading else { return }
        isRatesLoading = true
        defer { isRatesLoading = false }

        let calendar = Calendar.current
        for date in dates {
            let day = calendar.startOfDay(for: date)
            let dayKey = dateKey(day)
            if ratesByDateKey[dayKey] != nil { continue }
            do {
                ratesByDateKey[dayKey] = try await CBRCurrencyRates.fetchRubPerUnitByDate(day)
            } catch {
                ratesByDateKey[dayKey] = [AppCurrency.RUB.rawValue: 1.0]
            }
        }
    }

    @MainActor
    private func refreshCurrencyRatesForVisibleMonth() async {
        let base = baseCurrencyCode
        let calendar = Calendar.current

        var uniqueDays = Set<Date>()

        // План хранится в RUB, поэтому для конвертации в выбранную валюту нужны курсы на первый день месяца.
        if base != AppCurrency.RUB.rawValue {
            uniqueDays.insert(calendar.startOfDay(for: selectedReportDate))
        }

        let expenseTransactions = loadTransactions(for: FinanceMode.expense.storageKey)
            .filter {
                calendar.isDate($0.date, equalTo: selectedReportDate, toGranularity: .month) &&
                calendar.isDate($0.date, equalTo: selectedReportDate, toGranularity: .year)
            }
        let incomeTransactions = loadTransactions(for: FinanceMode.income.storageKey)
            .filter {
                calendar.isDate($0.date, equalTo: selectedReportDate, toGranularity: .month) &&
                calendar.isDate($0.date, equalTo: selectedReportDate, toGranularity: .year)
            }

        for tx in (expenseTransactions + incomeTransactions) {
            let from = AppCurrency.normalize(tx.currency)
            guard from != base else { continue }
            uniqueDays.insert(calendar.startOfDay(for: tx.date))
        }

        await refreshCurrencyRatesForDatesIfNeeded(Array(uniqueDays))
    }

    func totalFactForMonth(mode: FinanceMode, month: Int, year: Int) -> Int {
        let transactions = mode == self.mode ? allTransactions : loadTransactions(for: mode.storageKey)
        let calendar = Calendar.current
        guard let targetDate = calendar.date(from: DateComponents(year: year, month: month, day: 1)) else { return 0 }

        return transactions
            .filter {
                calendar.isDate($0.date, equalTo: targetDate, toGranularity: .month) &&
                calendar.isDate($0.date, equalTo: targetDate, toGranularity: .year)
            }
            .reduce(0) { sum, tx in
                sum + convertedAmount(tx.amount, fromCurrencyCode: tx.currency, on: tx.date)
            }
    }

    func deleteTransaction(_ id: UUID) {
        allTransactions.removeAll { $0.id == id }
        saveTransactions()
    }

    @MainActor
    func updateTransaction(_ id: UUID, category: String, date: Date, amount: Int) async {
        guard date >= earliestReportDate else { return }
        guard let index = allTransactions.firstIndex(where: { $0.id == id }) else { return }

        // UI edits are in selected base currency; stored transaction keeps its own original currency.
        // Convert `amount` (base) into the transaction's stored currency for the given date.
        let storedCurrencyCode = AppCurrency.normalize(allTransactions[index].currency)
        let baseCurrencyCode = self.baseCurrencyCode

        // If currencies match, no conversion (and no additional CBR request) is needed.
        let amountToStore: Int
        if storedCurrencyCode == baseCurrencyCode {
            amountToStore = amount
        } else {
            let key = dateKey(date)
            if ratesByDateKey[key] == nil {
                do {
                    ratesByDateKey[key] = try await CBRCurrencyRates.fetchRubPerUnitByDate(date)
                } catch {
                    ratesByDateKey[key] = [AppCurrency.RUB.rawValue: 1.0]
                }
            }

            let rates = ratesByDateKey[key] ?? [:]
            let rubPerFrom: Double = baseCurrencyCode == AppCurrency.RUB.rawValue ? 1.0 : (rates[baseCurrencyCode] ?? 0)
            let rubPerTo: Double = storedCurrencyCode == AppCurrency.RUB.rawValue ? 1.0 : (rates[storedCurrencyCode] ?? 0)

            if rubPerFrom == 0 || rubPerTo == 0 {
                amountToStore = amount
            } else {
                let converted = Double(amount) * rubPerFrom / rubPerTo
                amountToStore = Int(converted.rounded())
            }
        }

        allTransactions[index] = ExpenseTransaction(
            id: id,
            category: category,
            amount: amountToStore,
            date: date,
            currency: allTransactions[index].currency
        )
        saveTransactions()
    }

    func updateCategoryPlan(categoryName: String, plan: Int) {
        guard let index = categories.firstIndex(where: { $0.category == categoryName }) else { return }
        // UI input is in selected base currency; storage is kept in RUB.
        categories[index].plan = convertedAmountToRUB(plan, fromCurrencyCode: baseCurrencyCode, on: selectedReportDate)
        saveCategoryPlans()
    }

    func saveCategoryPlans() {
        let planByCategory = Dictionary(uniqueKeysWithValues: categories.map { ($0.category, $0.plan) })
        UserDefaults.standard.set(planByCategory, forKey: mode.planStorageKey)
    }

    func loadCategories() {
        if let names = UserDefaults.standard.stringArray(forKey: mode.categoriesStorageKey), !names.isEmpty {
            let planByCategory = loadPlanByCategoryCents()
            categories = names.map { name in
                ExpenseCategory(category: name, plan: planByCategory[name] ?? 0, fact: 0)
            }
            return
        }
        let planByCategory = loadPlanByCategoryCents()
        let fromTransactions = Set(allTransactions.map(\.category))
        let fromPlans = Set(planByCategory.keys)
        let names = Array(fromTransactions.union(fromPlans)).sorted()
        categories = names.map { name in
            ExpenseCategory(category: name, plan: planByCategory[name] ?? 0, fact: 0)
        }
        if !names.isEmpty {
            saveCategories()
        }
    }

    func saveCategories() {
        let names = categories.map(\.category)
        UserDefaults.standard.set(names, forKey: mode.categoriesStorageKey)
    }

    private func loadPlanByCategoryCents() -> [String: Int] {
        if let planByCategory = UserDefaults.standard.dictionary(forKey: mode.planStorageKey) as? [String: Int] {
            return planByCategory
        }
        if let legacyPlanByCategory = UserDefaults.standard.dictionary(forKey: mode.legacyPlanStorageKey) as? [String: Int] {
            let migrated = legacyPlanByCategory.mapValues { $0 * 100 }
            UserDefaults.standard.set(migrated, forKey: mode.planStorageKey)
            return migrated
        }
        return [:]
    }

    func loadCategoryPlans() {
        let planByCategory = loadPlanByCategoryCents()
        categories = categories.map { category in
            var updated = category
            if let storedPlan = planByCategory[category.category] {
                updated.plan = storedPlan
            }
            return updated
        }
    }

    func fieldButtonRow(value: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Text(value)
                    .font(.playfairDisplay(20, weight: .semibold))
                    .foregroundStyle(.black)
                    .lineLimit(1)

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(Color(.green))
            }
            .padding(.horizontal, 14)
            .frame(height: 50)
            .background(.white)
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
    }

    private var categoryPickerOptions: [String] {
        categories.map(\.category) + [newCategoryKey]
    }

    var categoryPicker: some View {
        Picker("Категория", selection: $transaction.category) {
            ForEach(categoryPickerOptions, id: \.self) { option in
                Text(option == newCategoryKey ? "Новая" : option).tag(option)
            }
        }
        .pickerStyle(.wheel)
        .frame(height: 120)
        .background(Color(.systemGray5))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    var currencyPicker: some View {
        Picker("Валюта", selection: $transaction.currency) {
            ForEach(AppCurrency.mainCurrencies) { currency in
                Text(currency.displayName).tag(currency.rawValue)
            }
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
    var currency: String = AppCurrency.RUB.rawValue

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
    let currencySymbol: String
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
            .padding(.horizontal, AppLayout.screenHorizontalPadding)
            .padding(.vertical, 8)

            Divider()
                .overlay(Color(.gray).opacity(0.3))

            List {
                ForEach(transactions) { transaction in
                    VStack(spacing: 0) {
                        HStack(spacing: 12) {
                            Text(transaction.category)
                                .lineLimit(1)
                                .truncationMode(.tail)
                                .font(.playfairDisplay(20))
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    onEditCategory(transaction)
                                }

                            Text(formatDate(transaction.date))
                                .font(.playfairDisplay(18))
                                .frame(width: 110, alignment: .leading)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    onEditDate(transaction)
                                }

                            Text(formatAmount(transaction.amount))
                                .font(.playfairDisplay(20))
                                .frame(width: 110, alignment: .leading)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    onEditAmount(transaction)
                                }
                        }
                        .padding(.vertical, 8)
                        Divider()
                            .overlay(Color(.gray).opacity(0.3))
                    }
                    .padding(.horizontal, AppLayout.screenHorizontalPadding)
                    .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                    .listRowBackground(Color(.beige))
                    .listRowSeparator(.hidden)
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
            .environment(\.defaultMinListRowHeight, 44)
        }
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd.MM.yyyy"
        return formatter.string(from: date)
    }

    private func formatAmount(_ value: Int) -> String {
        AppMoney.formatCentsForDisplay(value, currencySymbol: currencySymbol)
    }
}

enum FinanceMode: Hashable {
    case expense
    case income

    var screenTitle: String {
        switch self {
        case .expense: "Расходы"
        case .income: "Доходы"
        }
    }

    var storageKey: String {
        switch self {
        case .expense: "budget.expense.transactions.v2"
        case .income: "budget.income.transactions.v2"
        }
    }

    var legacyStorageKey: String {
        switch self {
        case .expense: "budget.expense.transactions.v1"
        case .income: "budget.income.transactions.v1"
        }
    }

    var planStorageKey: String {
        switch self {
        case .expense: "budget.expense.plan.v2"
        case .income: "budget.income.plan.v2"
        }
    }

    var legacyPlanStorageKey: String {
        switch self {
        case .expense: "budget.expense.plan.v1"
        case .income: "budget.income.plan.v1"
        }
    }

    var categoriesStorageKey: String {
        switch self {
        case .expense: "budget.expense.categories.v1"
        case .income: "budget.income.categories.v1"
        }
    }

    var defaultCategories: [ExpenseCategory] {
        []
    }
}
