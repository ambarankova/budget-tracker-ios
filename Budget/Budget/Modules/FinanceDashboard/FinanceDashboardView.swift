import SwiftUI

private let earliestReportDate = Calendar.current.date(from: DateComponents(year: 2019, month: 12, day: 1))!
private let newCategoryKey = "__NEW__"

struct FinanceDashboardView: View {

    @ObservedObject var viewModel: FinanceDashboardViewModel
    @Binding var isOverlayPresented: Bool
    @Binding var isBottomGreenFillPresented: Bool

    // MARK: - UI-only state (editors, pickers, drafts)

    @State private var selectedPage = 0
    @State private var isMonthPickerPresented = false
    @State private var monthPickerDraftMonth  = Calendar.current.component(.month, from: Date())
    @State private var monthPickerDraftYear   = Calendar.current.component(.year,  from: Date())

    @State private var isAddTransactionPresented = false
    @State private var transactionDraft = TransactionDraft()
    @State private var activePicker: AddTransactionPicker?
    @State private var newCategoryDraft = ""
    @FocusState private var isAmountInputFocused: Bool
    @FocusState private var isNewCategoryInputFocused: Bool

    @State private var categoryEditingTransaction: Transaction?
    @State private var categoryEditingDraft = ""
    @State private var dateEditingTransaction: Transaction?
    @State private var dateEditingDraft: Date = .now
    @State private var amountEditingTransaction: Transaction?
    @State private var amountEditingDraft = ""
    @FocusState private var isAmountEditingFocused: Bool

    @State private var planEditingCategoryName: String?
    @State private var planEditingDraft = ""
    @FocusState private var isPlanEditingFocused: Bool

    @State private var categoryNameEditingCategory: String?
    @State private var categoryNameEditingDraft = ""

    @State private var categoryToDelete: String?
    @State private var isSettingsPresented = false

    // MARK: - Derived UI state

    private var isAnyEditorVisible: Bool {
        categoryEditingTransaction != nil || dateEditingTransaction != nil || amountEditingTransaction != nil
    }
    private var isPlanEditorVisible:     Bool { planEditingCategoryName    != nil }
    private var isCategoryNameEditorVisible: Bool { categoryNameEditingCategory != nil }
    private var isAnyOverlayVisible: Bool {
        isAddTransactionPresented || isAnyEditorVisible || isPlanEditorVisible ||
        isCategoryNameEditorVisible || isMonthPickerPresented
    }

    private var isAddTransactionOkDisabled: Bool {
        let amountInvalid  = (AppMoney.parseToCents(transactionDraft.amount) ?? 0) <= 0
        let newCategoryEmpty = transactionDraft.category == newCategoryKey &&
            newCategoryDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        return amountInvalid || newCategoryEmpty
    }

    // MARK: - Body

    var body: some View {
        ZStack(alignment: .bottom) {
            Color(.beige).ignoresSafeArea()

            VStack(spacing: 0) {
                // Top bar
                HStack {
                    Spacer()
                    SettingsButton { isSettingsPresented = true }
                        .accessibilityLabel(L10n.a11yOpenSettings)
                }
                .padding(.top, 0)

                // Delta header
                HStack {
                    Text("\(L10n.delta): \(viewModel.formattedAmount(viewModel.globalDelta, withSign: true))")
                        .font(.playfairDisplay(31, weight: .bold))
                        .minimumScaleFactor(0.65)
                        .lineLimit(1)
                        .foregroundStyle(Color(.green))
                        .accessibilityLabel("\(L10n.delta): \(viewModel.formattedAmount(viewModel.globalDelta, withSign: true))")
                    Spacer()
                }
                .padding(.top, -8)
                .padding(.horizontal, AppLayout.screenHorizontalPadding)

                // Mode + month selector
                HStack {
                    Text(viewModel.mode.screenTitle)
                        .font(.playfairDisplay(30, weight: .semibold))
                        .foregroundStyle(Color(.green))
                    Spacer()
                    Button {
                        monthPickerDraftMonth = viewModel.selectedMonth
                        monthPickerDraftYear  = viewModel.selectedYear
                        withAnimation(.easeInOut(duration: 0.22)) { isMonthPickerPresented = true }
                    } label: {
                        HStack(spacing: 6) {
                            Text(viewModel.selectedMonthDisplayText)
                                .font(.playfairDisplay(28, weight: .semibold))
                                .foregroundStyle(Color(.green))
                            Image(systemName: "chevron.right")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundStyle(Color(.green))
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(L10n.a11yPickMonth)
                    .accessibilityValue(viewModel.selectedMonthDisplayText)
                }
                .padding(.horizontal, AppLayout.screenHorizontalPadding)
                .padding(.bottom, 8)

                // Paged content: summary table + transactions list
                TabView(selection: $selectedPage) {
                    TotalTableView(
                        categories: viewModel.categorySummaries,
                        totalPlan: viewModel.totalPlan,
                        totalFact: viewModel.totalFact,
                        isRedWhenFactLessThanPlan: viewModel.mode == .income,
                        onPlanTap: { name in
                            withAnimation(.easeInOut(duration: 0.22)) {
                                planEditingCategoryName = name
                                let plan = viewModel.categorySummaries.first { $0.name == name }?.plan ?? 0
                                planEditingDraft = AppMoney.formatCentsForInput(plan)
                            }
                        },
                        onCategoryTap: { name in
                            withAnimation(.easeInOut(duration: 0.22)) {
                                categoryNameEditingCategory = name
                                categoryNameEditingDraft = name
                            }
                        },
                        onDeleteCategory: { categoryToDelete = $0 }
                    )
                    .tag(0)
                    .accessibilityLabel(L10n.a11yPageSummary)

                    TransactionsListView(
                        transactions: viewModel.displayTransactions,
                        currencySymbol: viewModel.baseCurrencySymbol,
                        onDelete: { viewModel.deleteTransaction(id: $0.id) },
                        onEditCategory: { tx in
                            withAnimation(.easeInOut(duration: 0.22)) {
                                categoryEditingDraft = tx.category
                                categoryEditingTransaction = tx
                            }
                        },
                        onEditDate: { tx in
                            withAnimation(.easeInOut(duration: 0.22)) {
                                dateEditingDraft = tx.date
                                dateEditingTransaction = tx
                            }
                        },
                        onEditAmount: { tx in
                            withAnimation(.easeInOut(duration: 0.22)) {
                                amountEditingDraft = AppMoney.formatCentsForInput(tx.amount)
                                amountEditingTransaction = tx
                            }
                        }
                    )
                    .tag(1)
                    .accessibilityLabel(L10n.a11yPageTransactions)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .frame(maxHeight: .infinity)

                // Page indicator
                HStack(spacing: 8) {
                    Circle().fill(selectedPage == 0 ? Color(.green) : Color(.gray).opacity(0.4)).frame(width: 10, height: 10)
                        .accessibilityLabel(L10n.a11yPageSummary)
                        .accessibilityAddTraits(selectedPage == 0 ? .isSelected : [])
                    Circle().fill(selectedPage == 1 ? Color(.green) : Color(.gray).opacity(0.4)).frame(width: 10, height: 10)
                        .accessibilityLabel(L10n.a11yPageTransactions)
                        .accessibilityAddTraits(selectedPage == 1 ? .isSelected : [])
                }
                .padding(.vertical, 8)

                // Add button
                Button {
                    transactionDraft = TransactionDraft(
                        defaultCategory: viewModel.categoryNames.first ?? newCategoryKey,
                        currency: viewModel.baseCurrencyCode
                    )
                    withAnimation(.easeInOut(duration: 0.28)) { isAddTransactionPresented = true }
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
                .accessibilityLabel(L10n.a11yAddTransaction)
                .padding(.horizontal, AppLayout.screenHorizontalPadding)
                .padding(.bottom, 4)
            }

            // Dimming backdrop
            if isAnyEditorVisible || isPlanEditorVisible || isCategoryNameEditorVisible || isMonthPickerPresented {
                Color.black.opacity(0.2)
                    .ignoresSafeArea()
                    .onTapGesture { closeAllEditors() }
                    .transition(.opacity)
                    .zIndex(1)
            }

            if isMonthPickerPresented {
                monthPickerOverlay
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                    .zIndex(2)
            }

            transactionEditorOverlay
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                .zIndex(2)

            planEditorOverlay
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                .zIndex(2)

            categoryNameEditorOverlay
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                .zIndex(2)

            if isAddTransactionPresented {
                addTransactionOverlay
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .zIndex(3)
            }
        }
        .onAppear {
            viewModel.onAppear()
            syncOverlayBindings()
        }
        .onChange(of: isAddTransactionPresented)          { _ in syncOverlayBindings() }
        .onChange(of: categoryEditingTransaction != nil)  { _ in syncOverlayBindings() }
        .onChange(of: dateEditingTransaction    != nil)   { _ in syncOverlayBindings() }
        .onChange(of: amountEditingTransaction  != nil)   { _ in syncOverlayBindings() }
        .onChange(of: planEditingCategoryName   != nil)   { _ in syncOverlayBindings() }
        .onChange(of: categoryNameEditingCategory != nil) { _ in syncOverlayBindings() }
        .onChange(of: isMonthPickerPresented)             { _ in syncOverlayBindings() }
        .onChange(of: viewModel.selectedMonth) { _ in viewModel.onSelectedMonthChanged() }
        .onChange(of: viewModel.selectedYear)  { _ in viewModel.onSelectedMonthChanged() }
        .onChange(of: isSettingsPresented) { isPresented in
            guard !isPresented else { return }
            viewModel.onSettingsDismissed()
        }
        .alert(L10n.delete, isPresented: Binding(
            get: { categoryToDelete != nil },
            set: { if !$0 { categoryToDelete = nil } }
        )) {
            Button(L10n.cancel, role: .cancel) { categoryToDelete = nil }
            Button(L10n.delete, role: .destructive) {
                if let name = categoryToDelete { viewModel.deleteCategory(name: name) }
                categoryToDelete = nil
            }
        } message: {
            Text(L10n.confirmDeleteCategory)
        }
        .onDisappear {
            isOverlayPresented = false
            isBottomGreenFillPresented = false
        }
        .fullScreenCover(isPresented: $isSettingsPresented) {
            AppSettingsView(onBack: { isSettingsPresented = false })
        }
    }

    // MARK: - Overlay sync

    private func syncOverlayBindings() {
        isOverlayPresented = isAnyOverlayVisible
        isBottomGreenFillPresented = isAddTransactionPresented
    }

    private func closeAllEditors() {
        withAnimation(.easeInOut(duration: 0.22)) {
            categoryEditingTransaction = nil
            dateEditingTransaction = nil
            amountEditingTransaction = nil
            planEditingCategoryName = nil
            categoryNameEditingCategory = nil
            isMonthPickerPresented = false
        }
        amountEditingDraft = ""
        newCategoryDraft = ""
        planEditingDraft = ""
        categoryNameEditingDraft = ""
        isAmountEditingFocused = false
        isNewCategoryInputFocused = false
        isPlanEditingFocused = false
        syncOverlayBindings()
    }
}

// MARK: - Overlays

private extension FinanceDashboardView {

    var monthPickerOverlay: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                Picker(L10n.month, selection: $monthPickerDraftMonth) {
                    ForEach(viewModel.availableMonths(for: monthPickerDraftYear), id: \.self) { month in
                        Text(viewModel.monthName(for: month)).tag(month)
                    }
                }
                .pickerStyle(.wheel)
                .labelsHidden()
                .frame(maxWidth: .infinity)

                Picker(L10n.year, selection: $monthPickerDraftYear) {
                    ForEach(viewModel.availableYears, id: \.self) { Text(String($0)).tag($0) }
                }
                .pickerStyle(.wheel)
                .labelsHidden()
                .frame(maxWidth: .infinity)
            }
            .frame(height: 180)
            .onChange(of: monthPickerDraftYear) { year in
                let months = viewModel.availableMonths(for: year)
                if !months.contains(monthPickerDraftMonth) {
                    monthPickerDraftMonth = months.first ?? 1
                }
            }

            overlayButtons(
                onCancel: { withAnimation(.easeInOut(duration: 0.22)) { isMonthPickerPresented = false }; syncOverlayBindings() },
                onOK: {
                    viewModel.selectedMonth = monthPickerDraftMonth
                    viewModel.selectedYear  = monthPickerDraftYear
                    withAnimation(.easeInOut(duration: 0.22)) { isMonthPickerPresented = false }
                    syncOverlayBindings()
                }
            )
        }
        .overlayCard()
    }

    @ViewBuilder
    var planEditorOverlay: some View {
        if let categoryName = planEditingCategoryName {
            VStack(spacing: 12) {
                Text(L10n.planCategory(categoryName))
                    .font(.playfairDisplay(24, weight: .semibold))
                    .foregroundStyle(.black)

                amountTextField(text: Binding(
                    get: { viewModel.formattedAmountInput(planEditingDraft) },
                    set: { planEditingDraft = viewModel.normalizedAmountInput($0) }
                ), isFocused: $isPlanEditingFocused)

                overlayButtons(
                    onCancel: {
                        withAnimation(.easeInOut(duration: 0.22)) { planEditingCategoryName = nil }
                        planEditingDraft = ""
                        isPlanEditingFocused = false
                        syncOverlayBindings()
                    },
                    onOK: {
                        guard let planCents = AppMoney.parseToCents(planEditingDraft), planCents >= 0 else { return }
                        viewModel.updateCategoryPlan(name: categoryName, planInBaseCurrency: planCents)
                        withAnimation(.easeInOut(duration: 0.22)) { planEditingCategoryName = nil }
                        planEditingDraft = ""
                        syncOverlayBindings()
                    }
                )
            }
            .overlayCard()
            .transition(.move(edge: .bottom).combined(with: .opacity))
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { isPlanEditingFocused = true }
            }
        }
    }

    @ViewBuilder
    var categoryNameEditorOverlay: some View {
        if let oldName = categoryNameEditingCategory {
            VStack(spacing: 12) {
                Text(L10n.categoryName)
                    .font(.playfairDisplay(24, weight: .semibold))
                    .foregroundStyle(.black)

                TextField(L10n.name, text: $categoryNameEditingDraft)
                    .font(.playfairDisplay(20, weight: .semibold))
                    .padding(.horizontal, 14)
                    .frame(height: 56)
                    .background(.white)
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color(.gray).opacity(0.5), lineWidth: 1))
                    .clipShape(RoundedRectangle(cornerRadius: 10))

                overlayButtons(
                    onCancel: {
                        withAnimation(.easeInOut(duration: 0.22)) { categoryNameEditingCategory = nil }
                        categoryNameEditingDraft = ""
                        syncOverlayBindings()
                    },
                    onOK: {
                        let newName = categoryNameEditingDraft.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !newName.isEmpty, newName != oldName else {
                            withAnimation(.easeInOut(duration: 0.22)) { categoryNameEditingCategory = nil }
                            syncOverlayBindings()
                            return
                        }
                        viewModel.renameCategory(from: oldName, to: newName)
                        withAnimation(.easeInOut(duration: 0.22)) { categoryNameEditingCategory = nil }
                        categoryNameEditingDraft = ""
                        syncOverlayBindings()
                    }
                )
            }
            .overlayCard()
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }

    @ViewBuilder
    var transactionEditorOverlay: some View {
        if let editing = dateEditingTransaction {
            VStack(spacing: 12) {
                DatePicker("", selection: $dateEditingDraft, in: earliestReportDate...Date(), displayedComponents: .date)
                    .datePickerStyle(.wheel)
                    .labelsHidden()
                    .frame(height: 180)

                overlayButtons(
                    onCancel: { closeTransactionEditor() },
                    onOK: {
                        Task { @MainActor in
                            await viewModel.updateTransaction(id: editing.id, category: editing.category, date: dateEditingDraft, amount: editing.amount)
                            closeTransactionEditor()
                        }
                    }
                )
            }
            .overlayCard()
            .transition(.move(edge: .bottom).combined(with: .opacity))

        } else if let editing = categoryEditingTransaction {
            VStack(spacing: 12) {
                Picker(L10n.category, selection: $categoryEditingDraft) {
                    ForEach(categoryPickerOptions, id: \.self) { option in
                        Text(option == newCategoryKey ? L10n.newCategory : option).tag(option)
                    }
                }
                .pickerStyle(.wheel)
                .labelsHidden()
                .frame(height: 180)

                if categoryEditingDraft == newCategoryKey {
                    TextField(L10n.categoryName, text: $newCategoryDraft)
                        .font(.playfairDisplay(20, weight: .semibold))
                        .foregroundStyle(.black)
                        .padding(.horizontal, 12)
                        .frame(height: 50)
                        .background(Color(.systemGray5))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .focused($isNewCategoryInputFocused)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }

                overlayButtons(
                    onCancel: { newCategoryDraft = ""; closeTransactionEditor() },
                    onOK: {
                        var categoryToUse = categoryEditingDraft
                        if categoryEditingDraft == newCategoryKey {
                            let name = newCategoryDraft.trimmingCharacters(in: .whitespacesAndNewlines)
                            guard !name.isEmpty else { return }
                            viewModel.addCategory(name: name)
                            categoryToUse = name
                            newCategoryDraft = ""
                        }
                        Task { @MainActor in
                            await viewModel.updateTransaction(id: editing.id, category: categoryToUse, date: editing.date, amount: editing.amount)
                            closeTransactionEditor()
                        }
                    },
                    okDisabled: categoryEditingDraft == newCategoryKey && newCategoryDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                )
            }
            .overlayCard()
            .transition(.move(edge: .bottom).combined(with: .opacity))
            .onChange(of: categoryEditingDraft) { newValue in
                if newValue == newCategoryKey {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { isNewCategoryInputFocused = true }
                } else {
                    isNewCategoryInputFocused = false
                }
            }

        } else if let editing = amountEditingTransaction {
            VStack(spacing: 12) {
                Text(L10n.enterValue)
                    .font(.playfairDisplay(24, weight: .semibold))
                    .foregroundStyle(.black)

                amountTextField(text: Binding(
                    get: { viewModel.formattedAmountInput(amountEditingDraft) },
                    set: { amountEditingDraft = viewModel.normalizedAmountInput($0) }
                ), isFocused: $isAmountEditingFocused)

                overlayButtons(
                    onCancel: { closeTransactionEditor() },
                    onOK: {
                        guard let cents = AppMoney.parseToCents(amountEditingDraft), cents > 0 else { return }
                        Task { @MainActor in
                            await viewModel.updateTransaction(id: editing.id, category: editing.category, date: editing.date, amount: cents)
                            closeTransactionEditor()
                        }
                    }
                )
            }
            .overlayCard()
            .transition(.move(edge: .bottom).combined(with: .opacity))
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { isAmountEditingFocused = true }
            }
        }
    }

    var addTransactionOverlay: some View {
        ZStack(alignment: .bottom) {
            Color.black.opacity(0.25)
                .ignoresSafeArea()
                .onTapGesture {
                    isAmountInputFocused = false
                    isNewCategoryInputFocused = false
                    withAnimation(.easeInOut(duration: 0.24)) { isAddTransactionPresented = false }
                    activePicker = nil
                }

            Color(.green)
                .frame(height: 180)
                .ignoresSafeArea(edges: .bottom)

            VStack(alignment: .leading, spacing: 12) {
                Text(L10n.sum).font(.playfairDisplay(20, weight: .semibold)).foregroundStyle(.white)

                HStack(spacing: 10) {
                    TextField("0", text: Binding(
                        get: { viewModel.formattedAmountInput(transactionDraft.amount) },
                        set: { transactionDraft.amount = viewModel.normalizedAmountInput($0) }
                    ))
                    .focused($isAmountInputFocused)
                    .font(.playfairDisplay(20, weight: .semibold))
                    .foregroundStyle(.black)
                    .keyboardType(.decimalPad)
                    .submitLabel(.done)

                    Button { activePicker = nil; isAmountInputFocused = true } label: {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 28, weight: .semibold))
                            .foregroundStyle(Color(.green))
                    }
                }
                .padding(.horizontal, 14)
                .frame(height: 50)
                .background(.white)
                .clipShape(RoundedRectangle(cornerRadius: 10))

                Text(L10n.category).font(.playfairDisplay(20, weight: .semibold)).foregroundStyle(.white)

                fieldButton(value: transactionDraft.category == newCategoryKey ? L10n.newCategory : transactionDraft.category) {
                    isAmountInputFocused = false
                    isNewCategoryInputFocused = false
                    if viewModel.categoryNames.isEmpty {
                        transactionDraft.category = newCategoryKey
                    } else {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            activePicker = activePicker == .category ? nil : .category
                        }
                    }
                }

                if transactionDraft.category == newCategoryKey {
                    TextField(L10n.categoryName, text: $newCategoryDraft)
                        .font(.playfairDisplay(20, weight: .semibold))
                        .foregroundStyle(.black)
                        .padding(.horizontal, 14)
                        .frame(height: 50)
                        .background(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .focused($isNewCategoryInputFocused)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }

                if activePicker == .category {
                    Picker(L10n.category, selection: $transactionDraft.category) {
                        ForEach(categoryPickerOptions, id: \.self) { option in
                            Text(option == newCategoryKey ? L10n.newCategory : option).tag(option)
                        }
                    }
                    .pickerStyle(.wheel)
                    .frame(height: 120)
                    .background(Color(.systemGray5))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .transition(.opacity.combined(with: .move(edge: .top)))
                    .onChange(of: transactionDraft.category) { newValue in
                        if newValue == newCategoryKey {
                            activePicker = nil
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { isNewCategoryInputFocused = true }
                        } else {
                            isNewCategoryInputFocused = false
                        }
                    }
                }

                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(L10n.date).font(.playfairDisplay(20, weight: .semibold)).foregroundStyle(.white)
                        fieldButton(value: formatDate(transactionDraft.date)) {
                            isAmountInputFocused = false
                            withAnimation(.easeInOut(duration: 0.2)) {
                                activePicker = activePicker == .date ? nil : .date
                            }
                        }
                    }
                    VStack(alignment: .leading, spacing: 8) {
                        Text(L10n.currency).font(.playfairDisplay(20, weight: .semibold)).foregroundStyle(.white)
                        fieldButton(value: AppCurrency.displayName(for: transactionDraft.currency)) {
                            isAmountInputFocused = false
                            withAnimation(.easeInOut(duration: 0.2)) {
                                activePicker = activePicker == .currency ? nil : .currency
                            }
                        }
                    }
                }

                if activePicker == .date {
                    DatePicker("", selection: $transactionDraft.date, in: earliestReportDate...Date(), displayedComponents: .date)
                        .datePickerStyle(.graphical)
                        .labelsHidden()
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .background(Color(.systemGray5))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }

                if activePicker == .currency {
                    Picker(L10n.currency, selection: $transactionDraft.currency) {
                        ForEach(AppCurrency.mainCurrencies) { currency in
                            Text(currency.displayName).tag(currency.rawValue)
                        }
                    }
                    .pickerStyle(.wheel)
                    .frame(height: 120)
                    .background(Color(.systemGray5))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }

                HStack(spacing: 12) {
                    Button(L10n.cancel) {
                        withAnimation(.easeInOut(duration: 0.24)) { isAddTransactionPresented = false }
                        activePicker = nil
                        isAmountInputFocused = false
                        isNewCategoryInputFocused = false
                        newCategoryDraft = ""
                    }
                    .font(.playfairDisplay(18, weight: .semibold))
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(Color(.systemGray5))
                    .clipShape(RoundedRectangle(cornerRadius: 10))

                    Button(L10n.ok) { commitAddTransaction() }
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
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .padding(.bottom, 56)
        }
        .onChange(of: transactionDraft.category) { newValue in
            if newValue == newCategoryKey {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { isNewCategoryInputFocused = true }
            } else {
                isNewCategoryInputFocused = false
            }
        }
        .ignoresSafeArea(edges: .bottom)
    }

    // MARK: - Actions

    private func commitAddTransaction() {
        guard let cents = AppMoney.parseToCents(transactionDraft.amount), cents > 0 else { return }
        guard transactionDraft.date >= earliestReportDate else { return }

        var categoryToUse = transactionDraft.category
        if transactionDraft.category == newCategoryKey {
            let name = newCategoryDraft.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !name.isEmpty else { return }
            viewModel.addCategory(name: name)
            categoryToUse = name
            newCategoryDraft = ""
        }

        Task { @MainActor in
            await viewModel.addTransaction(
                amount: cents,
                category: categoryToUse,
                date: transactionDraft.date,
                currency: transactionDraft.currency
            )
        }

        withAnimation(.easeInOut(duration: 0.24)) { isAddTransactionPresented = false }
        activePicker = nil
        isAmountInputFocused = false
        isNewCategoryInputFocused = false
        selectedPage = 1
        transactionDraft = TransactionDraft(
            defaultCategory: viewModel.categoryNames.first ?? newCategoryKey,
            currency: viewModel.baseCurrencyCode
        )
    }

    private func closeTransactionEditor() {
        withAnimation(.easeInOut(duration: 0.22)) {
            categoryEditingTransaction = nil
            dateEditingTransaction = nil
            amountEditingTransaction = nil
        }
        amountEditingDraft = ""
        newCategoryDraft = ""
        isAmountEditingFocused = false
        isNewCategoryInputFocused = false
        syncOverlayBindings()
    }

    // MARK: - Helpers

    private var categoryPickerOptions: [String] {
        viewModel.categoryNames + [newCategoryKey]
    }

    private func formatDate(_ date: Date) -> String {
        AppDateFormat.display.string(from: date)
    }

    // MARK: - Reusable sub-views

    private func fieldButton(value: String, action: @escaping () -> Void) -> some View {
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

    private func amountTextField(text: Binding<String>, isFocused: FocusState<Bool>.Binding) -> some View {
        TextField("0", text: text)
            .focused(isFocused)
            .keyboardType(.decimalPad)
            .font(.playfairDisplay(36, weight: .semibold))
            .foregroundStyle(.black)
            .padding(.horizontal, 12)
            .frame(height: 56)
            .background(.white)
            .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private func overlayButtons(onCancel: @escaping () -> Void, onOK: @escaping () -> Void, okDisabled: Bool = false) -> some View {
        HStack(spacing: 12) {
            Button(L10n.cancel, action: onCancel)
                .font(.playfairDisplay(20, weight: .semibold))
                .foregroundStyle(.black)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(Color(.systemGray5))
                .clipShape(RoundedRectangle(cornerRadius: 10))

            Button(L10n.ok, action: onOK)
                .font(.playfairDisplay(20, weight: .semibold))
                .foregroundStyle(Color(.green))
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(.white)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .disabled(okDisabled)
                .opacity(okDisabled ? 0.5 : 1)
        }
    }
}

// MARK: - Transactions list sub-view

private struct TransactionsListView: View {
    let transactions: [Transaction]
    let currencySymbol: String
    var onDelete: (Transaction) -> Void
    var onEditCategory: (Transaction) -> Void
    var onEditDate: (Transaction) -> Void
    var onEditAmount: (Transaction) -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Text(L10n.category).font(.playfairDisplay(20)).frame(maxWidth: .infinity, alignment: .leading)
                Text(L10n.date)    .font(.playfairDisplay(20)).frame(width: 110, alignment: .leading)
                Text(L10n.sum)     .font(.playfairDisplay(20)).frame(width: 110, alignment: .leading)
            }
            .padding(.horizontal, AppLayout.screenHorizontalPadding)
            .padding(.vertical, 8)

            Divider().overlay(Color(.gray).opacity(0.3))

            List {
                ForEach(transactions) { tx in
                    VStack(spacing: 0) {
                        HStack(spacing: 12) {
                            Text(tx.category)
                                .lineLimit(1).truncationMode(.tail)
                                .font(.playfairDisplay(20))
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .contentShape(Rectangle())
                                .onTapGesture { onEditCategory(tx) }

                            Text(formatDate(tx.date))
                                .font(.playfairDisplay(18))
                                .frame(width: 110, alignment: .leading)
                                .contentShape(Rectangle())
                                .onTapGesture { onEditDate(tx) }

                            Text(AppMoney.formatCentsForDisplay(tx.amount, currencySymbol: currencySymbol))
                                .font(.playfairDisplay(20))
                                .frame(width: 110, alignment: .leading)
                                .contentShape(Rectangle())
                                .onTapGesture { onEditAmount(tx) }
                        }
                        .padding(.vertical, 8)
                        Divider().overlay(Color(.gray).opacity(0.3))
                    }
                    .padding(.horizontal, AppLayout.screenHorizontalPadding)
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color(.beige))
                    .listRowSeparator(.hidden)
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button(role: .destructive) { onDelete(tx) } label: { Text(L10n.delete) }
                    }
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .environment(\.defaultMinListRowHeight, 44)
        }
    }

    private func formatDate(_ date: Date) -> String {
        AppDateFormat.display.string(from: date)
    }
}

// MARK: - Local types

private struct TransactionDraft {
    var amount: String = ""
    var category: String
    var date: Date = .now
    var currency: String

    init(defaultCategory: String = "Еда", currency: String = AppCurrency.RUB.rawValue) {
        self.category = defaultCategory
        self.currency = currency
    }
}

private enum AddTransactionPicker { case category, date, currency }


#Preview {
    let deps = AppDependencies.preview
    FinanceDashboardView(
        viewModel: FinanceDashboardViewModel(
            mode: .expense,
            transactionRepo: deps.transactionRepo,
            currencyService: deps.currencyService
        ),
        isOverlayPresented: .constant(false),
        isBottomGreenFillPresented: .constant(false)
    )
}
