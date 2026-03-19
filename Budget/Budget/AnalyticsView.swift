import SwiftUI
import UIKit

private struct ScrollViewWithoutInsets<Content: View>: UIViewRepresentable {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    func makeUIView(context: Context) -> UIScrollView {
        let scrollView = UIScrollView()
        scrollView.contentInsetAdjustmentBehavior = .never
        scrollView.contentInset = .zero
        scrollView.showsVerticalScrollIndicator = true
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.bounces = true

        let hosting = UIHostingController(rootView: content)
        hosting.view.translatesAutoresizingMaskIntoConstraints = false
        hosting.view.backgroundColor = .clear
        scrollView.addSubview(hosting.view)

        NSLayoutConstraint.activate([
            hosting.view.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            hosting.view.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            hosting.view.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            hosting.view.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            hosting.view.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor)
        ])

        context.coordinator.hosting = hosting
        return scrollView
    }

    func updateUIView(_ scrollView: UIScrollView, context: Context) {
        context.coordinator.hosting?.rootView = content
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    class Coordinator {
        var hosting: UIHostingController<Content>?
    }
}

private enum AnalyticsYearChartMode: String, Identifiable {
    case pie
    case bar

    var id: String { rawValue }
}

struct AnalyticsView: View {
    @Binding var isOverlayPresented: Bool
    @State private var selectedYear = Calendar.current.component(.year, from: Date())
    @State private var isYearPickerPresented = false
    @State private var yearPickerDraft = Calendar.current.component(.year, from: Date())
    @State private var displayMode: FinanceMode = .expense
    @State private var modePickerDraft: FinanceMode = .expense
    @State private var categories: [String] = []
    @State private var plansByCategory: [String: Int] = [:]
    @State private var monthlyByCategory: [String: [Int: Int]] = [:]
    @State private var hasAnyDataByMonth: [Int: Bool] = [:]
    @State private var planEditingCategoryName: String?
    @State private var planEditingDraft = ""
    @FocusState private var isPlanEditingFocused: Bool
    @State private var categoryNameEditingCategory: String?
    @State private var categoryNameEditingDraft = ""
    @State private var yearChartRoute: AnalyticsYearChartMode?
    @State private var isSettingsPresented = false

    @State private var baseCurrencyCodeSnapshot = AppCurrency.normalize(AppSettingsCurrency.loadBaseCurrencyCode())
    @State private var ratesByDateKey: [String: [String: Double]] = [:]
    @State private var isRatesLoading = false

    private var baseCurrencySymbol: String {
        AppCurrency.symbol(for: baseCurrencyCodeSnapshot)
    }
    private let monthSymbols = [
        "Янв", "Фев", "Мар", "Апр", "Май", "Июн",
        "Июл", "Авг", "Сен", "Окт", "Ноя", "Дек"
    ]

    private var availableYears: [Int] {
        let expenseYears = loadTransactions(for: FinanceMode.expense.storageKey)
            .map { Calendar.current.component(.year, from: $0.date) }
        let incomeYears = loadTransactions(for: FinanceMode.income.storageKey)
            .map { Calendar.current.component(.year, from: $0.date) }
        let years = Set(expenseYears + incomeYears)
        let sorted = years.sorted(by: >)
        return sorted.isEmpty ? [Calendar.current.component(.year, from: Date())] : sorted
    }

    private var totalPlan: Int {
        categories.reduce(0) { $0 + (plansByCategory[$1] ?? 0) }
    }

    private var isAnyPopupVisible: Bool {
        planEditingCategoryName != nil || categoryNameEditingCategory != nil || isYearPickerPresented
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            Color(.beige).ignoresSafeArea()

            VStack(spacing: 0) {
                HStack {
                    Spacer()
                    SettingsButton { isSettingsPresented = true }
                }
                .padding(.top, 0)

                HStack {
                    Text(displayMode.screenTitle)
                        .font(.playfairDisplay(40, weight: .semibold))
                        .foregroundStyle(Color(.green))
                    Spacer()
                    Button {
                        yearPickerDraft = selectedYear
                        modePickerDraft = displayMode
                        withAnimation(.easeInOut(duration: 0.22)) {
                            isYearPickerPresented = true
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Text(yearText(selectedYear))
                                .font(.playfairDisplay(36, weight: .semibold))
                                .foregroundStyle(Color(.green))
                            Image(systemName: "chevron.right")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundStyle(Color(.green))
                        }
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, AppLayout.screenHorizontalPadding)
                .padding(.top, -8)
                .padding(.bottom, 8)

                GeometryReader { geo in
                    ScrollViewWithoutInsets {
                        HStack(alignment: .top, spacing: 12) {
                            categoryOnlyTable(minHeight: max(0, geo.size.height + 18))

                            ScrollView(.horizontal, showsIndicators: true) {
                                monthsAndPlanTable(minHeight: max(0, geo.size.height + 18))
                                    .padding(.trailing, AppLayout.screenHorizontalPadding)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, AppLayout.screenHorizontalPadding)
                    }
                    .frame(maxHeight: .infinity)
                }

                ZStack {
                    HStack(spacing: 26) {
                        Button {
                            closePlanEditor()
                            closeCategoryNameEditor()
                            closeYearPicker()
                            yearChartRoute = .pie
                        } label: {
                            Image(systemName: "chart.pie.fill")
                                .font(.system(size: 36))
                                .foregroundStyle(Color(.gray))
                        }
                        .buttonStyle(.plain)

                        Button {
                            closePlanEditor()
                            closeCategoryNameEditor()
                            closeYearPicker()
                            yearChartRoute = .bar
                        } label: {
                            Image(systemName: "chart.bar")
                                .font(.system(size: 36))
                                .foregroundStyle(Color(.gray))
                        }
                        .buttonStyle(.plain)
                    }
                    .opacity(yearChartRoute == nil ? 1 : 0)
                    .allowsHitTesting(yearChartRoute == nil)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 86)
            }

            if isAnyPopupVisible {
                Color.black.opacity(0.2)
                    .ignoresSafeArea()
                    .onTapGesture {
                        closePlanEditor()
                        closeCategoryNameEditor()
                        closeYearPicker()
                    }
                    .zIndex(1)
            }

            if planEditingCategoryName != nil {
                planEditingOverlay
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                    .zIndex(2)
            }

            if categoryNameEditingCategory != nil {
                categoryNameEditingOverlay
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                    .zIndex(2)
            }

            if isYearPickerPresented {
                yearPickerOverlay
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                    .zIndex(2)
            }
        }
        .overlay(alignment: .bottom) {
            if let route = yearChartRoute {
                AnalyticsYearChartView(
                    mode: displayMode,
                    initialYear: selectedYear,
                    initialMode: route,
                    onDismiss: { yearChartRoute = nil }
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .zIndex(3)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            selectedYear = availableYears.first ?? selectedYear
            Task {
                await refreshCurrencyRatesForSelectedYear()
                recalculate()
                syncOverlayState()
            }
        }
        .onChange(of: planEditingCategoryName != nil) { _ in syncOverlayState() }
        .onChange(of: categoryNameEditingCategory != nil) { _ in syncOverlayState() }
        .onChange(of: isYearPickerPresented) { _ in syncOverlayState() }
        .onChange(of: isSettingsPresented) { _ in
            guard !isSettingsPresented else { return }
            let updated = AppCurrency.normalize(AppSettingsCurrency.loadBaseCurrencyCode())
            if updated != baseCurrencyCodeSnapshot {
                baseCurrencyCodeSnapshot = updated
                Task {
                    await refreshCurrencyRatesForSelectedYear()
                    recalculate()
                }
            } else if ratesByDateKey.isEmpty {
                Task {
                    await refreshCurrencyRatesForSelectedYear()
                    recalculate()
                }
            }
        }
        .onDisappear { isOverlayPresented = false }
        .fullScreenCover(isPresented: $isSettingsPresented) {
            AppSettingsView(onBack: { isSettingsPresented = false })
        }
    }
}

private extension AnalyticsView {
    var yearPickerOverlay: some View {
        VStack(spacing: 12) {
            Picker("", selection: $modePickerDraft) {
                Text(FinanceMode.expense.screenTitle).tag(FinanceMode.expense)
                Text(FinanceMode.income.screenTitle).tag(FinanceMode.income)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 2)

            Picker("Год", selection: $yearPickerDraft) {
                ForEach(availableYears, id: \.self) { year in
                    Text(yearText(year)).tag(year)
                }
            }
            .pickerStyle(.wheel)
            .labelsHidden()
            .frame(height: 180)

            HStack(spacing: 12) {
                Button("Отмена") {
                    closeYearPicker()
                }
                .font(.playfairDisplay(20, weight: .semibold))
                .foregroundStyle(.black)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(Color(.systemGray5))
                .clipShape(RoundedRectangle(cornerRadius: 10))

                Button("ОК") {
                    selectedYear = yearPickerDraft
                    displayMode = modePickerDraft
                    closeYearPicker()
                    Task {
                        await refreshCurrencyRatesForSelectedYear()
                        recalculate()
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
    }

    var planEditingOverlay: some View {
        VStack(spacing: 12) {
            Text("Введите значение")
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
            .padding(.horizontal, 12)
            .frame(height: 56)
            .background(.white)
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color(.gray).opacity(0.5), lineWidth: 1))
            .clipShape(RoundedRectangle(cornerRadius: 10))

            HStack(spacing: 12) {
                Button("Отмена") { closePlanEditor() }
                    .font(.playfairDisplay(20, weight: .semibold))
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(Color(.systemGray5))
                    .clipShape(RoundedRectangle(cornerRadius: 10))

                Button("ОК") {
                    guard let planCents = AppMoney.parseToCents(planEditingDraft), planCents >= 0, let category = planEditingCategoryName else { return }
                    plansByCategory[category] = planCents
                    savePlans()
                    closePlanEditor()
                }
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
                isPlanEditingFocused = true
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
                    Button("Отмена") { closeCategoryNameEditor() }
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
                            guard !categories.contains(newName) else { return }
                            renameCategory(from: oldName, to: newName)
                        }
                        closeCategoryNameEditor()
                    }
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
        }
    }

    @ViewBuilder
    func categoryOnlyRow(title: String, isTotal: Bool, onTap: (() -> Void)? = nil) -> some View {
        HStack {
            Text(title)
                .lineLimit(1)
                .font(.playfairDisplay(20, weight: isTotal ? .bold : .regular))
        }
        .frame(width: 150, alignment: .leading)
        .contentShape(Rectangle())
        .onTapGesture {
            onTap?()
        }
    }

    @ViewBuilder
    func monthsRow(values: [String], isTotal: Bool) -> some View {
        HStack(spacing: 12) {
            ForEach(Array(values.enumerated()), id: \.offset) { _, value in
                Text(value)
                    .multilineTextAlignment(.leading)
                    .font(.playfairDisplay(20, weight: isTotal ? .bold : .regular))
                    .frame(width: 110, alignment: .leading)
            }
        }
    }

    @ViewBuilder
    func scrollableRowWithPlan(
        values: [String],
        planText: String,
        isTotal: Bool,
        onPlanTap: (() -> Void)?
    ) -> some View {
        HStack(spacing: 12) {
            ForEach(Array(values.enumerated()), id: \.offset) { _, value in
                Text(value)
                    .multilineTextAlignment(.leading)
                    .font(.playfairDisplay(20, weight: isTotal ? .bold : .regular))
                    .frame(width: 110, alignment: .leading)
            }
            Text(planText)
                .multilineTextAlignment(.leading)
                .font(.playfairDisplay(20, weight: isTotal ? .bold : .regular))
                .frame(width: 84, alignment: .leading)
                .contentShape(Rectangle())
                .onTapGesture {
                    onPlanTap?()
                }
        }
    }

    @ViewBuilder
    func categoryOnlyTable(minHeight: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            categoryOnlyRow(title: "Категория", isTotal: false)
                .padding(.vertical, 8)
            Divider().overlay(Color(.gray).opacity(0.3))

            ForEach(categories, id: \.self) { category in
                categoryOnlyRow(title: category, isTotal: false, onTap: {
                    withAnimation(.easeInOut(duration: 0.22)) {
                        categoryNameEditingCategory = category
                        categoryNameEditingDraft = category
                    }
                })
                    .padding(.vertical, 8)
                Divider().overlay(Color(.gray).opacity(0.3))
            }

            Spacer()

            categoryOnlyRow(title: "Итого", isTotal: true)
                .padding(.vertical, 8)
                .padding(.bottom, 10)
        }
        .frame(minHeight: minHeight, alignment: .top)
    }

    @ViewBuilder
    func monthsAndPlanTable(minHeight: CGFloat) -> some View {
        VStack(spacing: 0) {
            scrollableRowWithPlan(
                values: monthSymbols + ["Итого"],
                planText: "План",
                isTotal: false,
                onPlanTap: nil
            )
            .padding(.vertical, 8)
            Divider().overlay(Color(.gray).opacity(0.3))

            ForEach(categories, id: \.self) { category in
                let planValue = plansByCategory[category] ?? 0
                scrollableRowWithPlan(
                    values: valuesForCategoryYear(category: category),
                    planText: formatAmount(planValue),
                    isTotal: false,
                    onPlanTap: {
                        withAnimation(.easeInOut(duration: 0.22)) {
                            planEditingCategoryName = category
                            planEditingDraft = AppMoney.formatCentsForInput(planValue)
                        }
                    }
                )
                .padding(.vertical, 8)
                Divider().overlay(Color(.gray).opacity(0.3))
            }

            Spacer()

            scrollableRowWithPlan(
                values: totalValuesForYear(),
                planText: formatAmount(totalPlan),
                isTotal: true,
                onPlanTap: nil
            )
            .padding(.vertical, 8)
            .padding(.bottom, 10)
        }
        .frame(minHeight: minHeight, alignment: .top)
    }

    private var planConversionDate: Date {
        Calendar.current.date(from: DateComponents(year: selectedYear, month: 1, day: 1)) ?? Date()
    }

    private func dateKey(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar.current
        formatter.timeZone = TimeZone.current
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    // Converts `amount` from `rawFromCurrencyCode` into the selected base currency, using cached CBR rates for `date`.
    private func convertedAmount(_ amount: Int, fromCurrencyCode rawFromCurrencyCode: String, on date: Date) -> Int {
        let fromCode = AppCurrency.normalize(rawFromCurrencyCode)
        let toCode = baseCurrencyCodeSnapshot

        if fromCode == toCode { return amount }

        let key = dateKey(date)
        let rates = ratesByDateKey[key] ?? [:]

        let rubPerFrom: Double
        if fromCode == AppCurrency.RUB.rawValue {
            rubPerFrom = 1.0
        } else if let rate = rates[fromCode] {
            rubPerFrom = rate
        } else {
            return amount
        }

        let rubPerTo: Double
        if toCode == AppCurrency.RUB.rawValue {
            rubPerTo = 1.0
        } else if let rate = rates[toCode] {
            rubPerTo = rate
        } else {
            return amount
        }

        guard rubPerTo != 0 else { return amount }
        let converted = Double(amount) * rubPerFrom / rubPerTo
        return Int(converted.rounded())
    }

    // Converts `amount` from `rawFromCurrencyCode` into RUB, using cached CBR rates for `date`.
    private func convertedAmountToRUB(_ amount: Int, fromCurrencyCode rawFromCurrencyCode: String, on date: Date) -> Int {
        let fromCode = AppCurrency.normalize(rawFromCurrencyCode)
        if fromCode == AppCurrency.RUB.rawValue { return amount }

        let key = dateKey(date)
        let rates = ratesByDateKey[key] ?? [:]

        guard let rubPerFrom = rates[fromCode] else { return amount }
        let rubAmount = Double(amount) * rubPerFrom
        return Int(rubAmount.rounded())
    }

    @MainActor
    private func refreshCurrencyRatesForSelectedYear() async {
        guard !isRatesLoading else { return }
        isRatesLoading = true
        defer { isRatesLoading = false }

        let calendar = Calendar.current
        let startOfYear = calendar.startOfDay(for: planConversionDate)

        let expenseTransactions = loadTransactions(for: FinanceMode.expense.storageKey)
            .filter { calendar.component(.year, from: $0.date) == selectedYear }
        let incomeTransactions = loadTransactions(for: FinanceMode.income.storageKey)
            .filter { calendar.component(.year, from: $0.date) == selectedYear }

        let allTransactionsForYear = expenseTransactions + incomeTransactions
        let base = AppCurrency.normalize(baseCurrencyCodeSnapshot)
        var uniqueDays = Set<Date>()
        for tx in allTransactionsForYear {
            if AppCurrency.normalize(tx.currency) != base {
                uniqueDays.insert(calendar.startOfDay(for: tx.date))
            }
        }
        if base != AppCurrency.RUB.rawValue {
            uniqueDays.insert(startOfYear) // for plan conversion (RUB -> base)
        }

        for day in uniqueDays {
            let dayKey = dateKey(day)
            if ratesByDateKey[dayKey] != nil { continue }
            do {
                ratesByDateKey[dayKey] = try await CBRCurrencyRates.fetchRubPerUnitByDate(day)
            } catch {
                ratesByDateKey[dayKey] = [AppCurrency.RUB.rawValue: 1.0]
            }
        }
    }

    func recalculate() {
        let transactions = loadTransactions(for: displayMode.storageKey)
        let filtered = transactions.filter { Calendar.current.component(.year, from: $0.date) == selectedYear }
        let monthGroups = Dictionary(grouping: filtered) { Calendar.current.component(.month, from: $0.date) }
        hasAnyDataByMonth = Dictionary(uniqueKeysWithValues: (1...12).map { ($0, !(monthGroups[$0] ?? []).isEmpty) })

        monthlyByCategory = [:]
        for (month, monthTransactions) in monthGroups {
            let byCategory = Dictionary(grouping: monthTransactions, by: \.category).mapValues { list in
                list.reduce(0) { sum, tx in
                    sum + convertedAmount(tx.amount, fromCurrencyCode: tx.currency, on: tx.date)
                }
            }
            for (category, amount) in byCategory {
                monthlyByCategory[category, default: [:]][month] = amount
            }
        }

        let categoriesFromData = Set(filtered.map(\.category))
        let storedPlansRUB = loadPlans()
        let categoriesFromPlan = Set(storedPlansRUB.keys)
        categories = Array(categoriesFromData.union(categoriesFromPlan)).sorted()
        // Plans are stored in RUB; convert for display into the selected base currency.
        plansByCategory = storedPlansRUB.mapValues { rubAmount in
            convertedAmount(rubAmount, fromCurrencyCode: AppCurrency.RUB.rawValue, on: planConversionDate)
        }
    }

    func formattedMonthCell(category: String, month: Int) -> String {
        let hasData = hasAnyDataByMonth[month] ?? false
        guard hasData else { return "—" }
        let value = monthlyByCategory[category]?[month] ?? 0
        return formatAmount(value)
    }

    func formattedTotalMonthCell(month: Int) -> String {
        let hasData = hasAnyDataByMonth[month] ?? false
        guard hasData else { return "—" }
        let total = categories.reduce(0) { $0 + (monthlyByCategory[$1]?[month] ?? 0) }
        return formatAmount(total)
    }

    func valuesForCategoryYear(category: String) -> [String] {
        let months = monthSymbols.enumerated().map { idx, _ in
            formattedMonthCell(category: category, month: idx + 1)
        }
        return months + [formatAmount(categoryYearTotal(category))]
    }

    func totalValuesForYear() -> [String] {
        let months = monthSymbols.enumerated().map { idx, _ in
            formattedTotalMonthCell(month: idx + 1)
        }
        return months + [formatAmount(grandTotalYear())]
    }

    func categoryYearTotal(_ category: String) -> Int {
        monthlyByCategory[category]?.values.reduce(0, +) ?? 0
    }

    func grandTotalYear() -> Int {
        categories.reduce(0) { $0 + categoryYearTotal($1) }
    }

    func formatAmount(_ value: Int) -> String {
        AppMoney.formatCentsForDisplay(value, currencySymbol: baseCurrencySymbol)
    }

    func normalizedAmountInput(_ text: String) -> String {
        AppMoney.normalizeInput(text)
    }

    func formattedAmountInput(_ text: String) -> String {
        let normalized = AppMoney.normalizeInput(text)
        guard let cents = AppMoney.parseToCents(normalized) else { return normalized }
        return AppMoney.formatCentsForInput(cents)
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
        var transactions = loadTransactions(for: displayMode.storageKey)
        for i in transactions.indices where transactions[i].category == oldName {
            transactions[i] = AnalyticsTransaction(
                id: transactions[i].id,
                category: newName,
                amount: transactions[i].amount,
                date: transactions[i].date,
                currency: transactions[i].currency
            )
        }
        if let data = try? JSONEncoder().encode(transactions) {
            UserDefaults.standard.set(data, forKey: displayMode.storageKey)
        }
        var plans = loadPlans()
        if let planValue = plans[oldName] {
            plans.removeValue(forKey: oldName)
            plans[newName] = planValue
            UserDefaults.standard.set(plans, forKey: displayMode.planStorageKey)
        }
        if var categoryNames = UserDefaults.standard.stringArray(forKey: displayMode.categoriesStorageKey) {
            if let idx = categoryNames.firstIndex(of: oldName) {
                categoryNames[idx] = newName
                UserDefaults.standard.set(categoryNames, forKey: displayMode.categoriesStorageKey)
            }
        }
        recalculate()
    }

    func syncOverlayState() {
        isOverlayPresented = isAnyPopupVisible
    }

    func closeYearPicker() {
        withAnimation(.easeInOut(duration: 0.22)) {
            isYearPickerPresented = false
        }
        syncOverlayState()
    }

    func yearText(_ year: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = ""
        formatter.usesGroupingSeparator = false
        return formatter.string(from: NSNumber(value: year)) ?? "\(year)"
    }

    func savePlans() {
        // Save plans in RUB to keep stable storage across currency changes.
        let storedPlansRUB = plansByCategory.mapValues { baseAmount in
            convertedAmountToRUB(baseAmount, fromCurrencyCode: baseCurrencyCodeSnapshot, on: planConversionDate)
        }
        UserDefaults.standard.set(storedPlansRUB, forKey: displayMode.planStorageKey)
    }

    func loadPlans() -> [String: Int] {
        if let plansV2 = UserDefaults.standard.dictionary(forKey: displayMode.planStorageKey) as? [String: Int] {
            return plansV2
        }
        
        // Migration: v1 stored whole units, v2 stores cents.
        if let legacyPlans = UserDefaults.standard.dictionary(forKey: displayMode.legacyPlanStorageKey) as? [String: Int] {
            let migrated = legacyPlans.mapValues { $0 * 100 }
            UserDefaults.standard.set(migrated, forKey: displayMode.planStorageKey)
            return migrated
        }
        
        return [:]
    }

    func loadTransactions(for storageKey: String) -> [AnalyticsTransaction] {
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let transactions = try? JSONDecoder().decode([AnalyticsTransaction].self, from: data) {
            return transactions
        }

        // Migration: v1 stored whole units, v2 stores cents.
        let legacyKey = storageKey.replacingOccurrences(of: ".v2", with: ".v1")
        guard legacyKey != storageKey,
              let legacyData = UserDefaults.standard.data(forKey: legacyKey),
              let legacyTransactions = try? JSONDecoder().decode([AnalyticsTransaction].self, from: legacyData) else {
            return []
        }

        let migrated = legacyTransactions.map {
            AnalyticsTransaction(
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
}

private struct AnalyticsTransaction: Codable {
    let id: UUID
    let category: String
    let amount: Int
    let date: Date
    let currency: String
}

private struct AnalyticsYearChartView: View {
    let mode: FinanceMode
    let initialYear: Int
    let initialMode: AnalyticsYearChartMode
    var onDismiss: () -> Void

    @State private var selectedYear: Int
    @State private var values: [ChartCategoryValue] = []
    @State private var deltaByMonth: [MonthlyDeltaValue] = []
    @State private var chartMode: AnalyticsYearChartMode
    @State private var selectedDeltaMonth: Int?
    @State private var isSettingsPresented = false

    @State private var baseCurrencyCodeSnapshot = AppCurrency.normalize(AppSettingsCurrency.loadBaseCurrencyCode())
    @State private var ratesByDateKey: [String: [String: Double]] = [:]
    @State private var isRatesLoading = false

    private var baseCurrencySymbol: String {
        AppCurrency.symbol(for: baseCurrencyCodeSnapshot)
    }

    init(
        mode: FinanceMode,
        initialYear: Int,
        initialMode: AnalyticsYearChartMode,
        onDismiss: @escaping () -> Void
    ) {
        self.mode = mode
        self.initialYear = initialYear
        self.initialMode = initialMode
        self.onDismiss = onDismiss
        _selectedYear = State(initialValue: initialYear)
        _chartMode = State(initialValue: initialMode)
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            Color(.beige)

            VStack(spacing: 0) {
                HStack {
                    Button {
                        onDismiss()
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
                    Text(chartMode == .bar ? "Дельта" : mode.screenTitle)
                        .font(.playfairDisplay(40, weight: .semibold))
                        .foregroundStyle(Color(.green))
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)

                if chartMode == .pie {
                    Spacer(minLength: 98)
                }

                if chartMode == .pie {
                    DonutChartView(values: values, currencySymbol: baseCurrencySymbol)
                        .frame(height: 198)
                        .padding(.horizontal, 42)
                        .padding(.top, 18)

                    ScrollView(.vertical, showsIndicators: true) {
                        VStack(alignment: .leading, spacing: 10) {
                            ForEach(values) { value in
                                HStack(spacing: 12) {
                                    RoundedRectangle(cornerRadius: 7)
                                        .fill(value.color)
                                        .frame(width: 28, height: 28)
                                    Text("\(value.category) (\(percent(for: value.amount))%)")
                                        .font(.playfairDisplay(18))
                                        .foregroundStyle(.black)
                                    Spacer()
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                    }
                    .padding(.top, 72)
                    .frame(maxHeight: .infinity)
                } else {
                    DeltaBarsChartView(
                        points: deltaByMonth,
                        selectedMonth: $selectedDeltaMonth,
                        currencySymbol: baseCurrencySymbol
                    )
                    .frame(maxWidth: .infinity)
                    .frame(maxHeight: .infinity)
                }

                HStack(spacing: 26) {
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            chartMode = .pie
                            selectedDeltaMonth = nil
                        }
                    } label: {
                        Image(systemName: "chart.pie.fill")
                            .font(.system(size: 36))
                            .foregroundStyle(chartMode == .pie ? Color(.green) : Color(.gray))
                    }
                    .buttonStyle(.plain)

                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            chartMode = .bar
                        }
                    } label: {
                        Image(systemName: "chart.bar")
                            .font(.system(size: 36))
                            .foregroundStyle(chartMode == .bar ? Color(.green) : Color(.gray))
                    }
                    .buttonStyle(.plain)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 86)
            }
        }
        .onAppear {
            chartMode = initialMode
            selectedDeltaMonth = nil
            Task {
                await refreshCurrencyRatesForSelectedYear()
                recalculate()
                recalculateDeltaByMonth()
            }
        }
        .onChange(of: isSettingsPresented) { _ in
            guard !isSettingsPresented else { return }
            let updated = AppCurrency.normalize(AppSettingsCurrency.loadBaseCurrencyCode())
            let didChange = updated != baseCurrencyCodeSnapshot
            if didChange {
                baseCurrencyCodeSnapshot = updated
                Task {
                    await refreshCurrencyRatesForSelectedYear()
                    recalculate()
                    recalculateDeltaByMonth()
                }
            } else if ratesByDateKey.isEmpty {
                Task {
                    await refreshCurrencyRatesForSelectedYear()
                    recalculate()
                    recalculateDeltaByMonth()
                }
            } else {
                recalculate()
                recalculateDeltaByMonth()
            }
        }
        .fullScreenCover(isPresented: $isSettingsPresented) {
            AppSettingsView(onBack: { isSettingsPresented = false })
        }
    }

    private func recalculate() {
        let transactions = loadTransactions(for: mode.storageKey)
            .filter { Calendar.current.component(.year, from: $0.date) == selectedYear }
        let grouped = Dictionary(grouping: transactions, by: \.category)
            .mapValues { list in
                list.reduce(0) { sum, tx in
                    sum + convertedAmount(tx.amount, fromCurrencyCode: tx.currency, on: tx.date)
                }
            }
        let sorted = grouped.keys.sorted()
        let palette: [Color] = [
            Color(.green),
            Color(red: 0.16, green: 0.60, blue: 0.45),
            Color(.gray),
            Color(red: 0.21, green: 0.43, blue: 0.37),
            Color(red: 0.55, green: 0.58, blue: 0.60),
            Color(red: 0.11, green: 0.33, blue: 0.28)
        ]
        values = sorted.enumerated().map { idx, key in
            ChartCategoryValue(
                category: key,
                amount: grouped[key] ?? 0,
                color: palette[idx % palette.count]
            )
        }
    }

    private func recalculateDeltaByMonth() {
        let expenses = loadTransactions(for: FinanceMode.expense.storageKey)
            .filter { Calendar.current.component(.year, from: $0.date) == selectedYear }
        let incomes = loadTransactions(for: FinanceMode.income.storageKey)
            .filter { Calendar.current.component(.year, from: $0.date) == selectedYear }

        let expenseByMonth = Dictionary(grouping: expenses) { Calendar.current.component(.month, from: $0.date) }
            .mapValues { list in
                list.reduce(0) { sum, tx in
                    sum + convertedAmount(tx.amount, fromCurrencyCode: tx.currency, on: tx.date)
                }
            }
        let incomeByMonth = Dictionary(grouping: incomes) { Calendar.current.component(.month, from: $0.date) }
            .mapValues { list in
                list.reduce(0) { sum, tx in
                    sum + convertedAmount(tx.amount, fromCurrencyCode: tx.currency, on: tx.date)
                }
            }

        let monthNames = [
            "январь", "февраль", "март", "апрель", "май", "июнь",
            "июль", "август", "сентябрь", "октябрь", "ноябрь", "декабрь"
        ]

        deltaByMonth = (1...12).map { month in
            MonthlyDeltaValue(
                monthIndex: month,
                monthName: monthNames[month - 1],
                delta: (incomeByMonth[month] ?? 0) - (expenseByMonth[month] ?? 0)
            )
        }
    }

    private func percent(for amount: Int) -> Int {
        let total = max(values.reduce(0) { $0 + $1.amount }, 1)
        return Int((Double(amount) / Double(total) * 100).rounded())
    }

    // Currency conversion helpers (CBR rates are cached in `ratesByDateKey`).
    private func dateKey(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar.current
        formatter.timeZone = TimeZone.current
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    private func convertedAmount(_ amount: Int, fromCurrencyCode rawFromCurrencyCode: String, on date: Date) -> Int {
        let fromCode = AppCurrency.normalize(rawFromCurrencyCode)
        let toCode = baseCurrencyCodeSnapshot

        if fromCode == toCode { return amount }

        let key = dateKey(date)
        let rates = ratesByDateKey[key] ?? [:]

        let rubPerFrom: Double
        if fromCode == AppCurrency.RUB.rawValue {
            rubPerFrom = 1.0
        } else if let rate = rates[fromCode] {
            rubPerFrom = rate
        } else {
            return amount
        }

        let rubPerTo: Double
        if toCode == AppCurrency.RUB.rawValue {
            rubPerTo = 1.0
        } else if let rate = rates[toCode] {
            rubPerTo = rate
        } else {
            return amount
        }

        guard rubPerTo != 0 else { return amount }
        let converted = Double(amount) * rubPerFrom / rubPerTo
        return Int(converted.rounded())
    }

    @MainActor
    private func refreshCurrencyRatesForSelectedYear() async {
        guard !isRatesLoading else { return }
        isRatesLoading = true
        defer { isRatesLoading = false }

        let calendar = Calendar.current
        let startOfYear = calendar.startOfDay(for: DateComponents(year: selectedYear, month: 1, day: 1).date ?? Date())

        let expenses = loadTransactions(for: FinanceMode.expense.storageKey)
            .filter { calendar.component(.year, from: $0.date) == selectedYear }
        let incomes = loadTransactions(for: FinanceMode.income.storageKey)
            .filter { calendar.component(.year, from: $0.date) == selectedYear }

        let allTransactionsForYear = expenses + incomes
        let base = AppCurrency.normalize(baseCurrencyCodeSnapshot)
        var uniqueDays = Set<Date>()
        for tx in allTransactionsForYear {
            if AppCurrency.normalize(tx.currency) != base {
                uniqueDays.insert(calendar.startOfDay(for: tx.date))
            }
        }
        if base != AppCurrency.RUB.rawValue {
            uniqueDays.insert(startOfYear)
        }

        for day in uniqueDays {
            let dayKey = dateKey(day)
            if ratesByDateKey[dayKey] != nil { continue }
            do {
                ratesByDateKey[dayKey] = try await CBRCurrencyRates.fetchRubPerUnitByDate(day)
            } catch {
                ratesByDateKey[dayKey] = [AppCurrency.RUB.rawValue: 1.0]
            }
        }
    }

    private func loadTransactions(for storageKey: String) -> [AnalyticsTransaction] {
        guard let data = UserDefaults.standard.data(forKey: storageKey) else { return [] }
        guard let transactions = try? JSONDecoder().decode([AnalyticsTransaction].self, from: data) else { return [] }
        return transactions
    }
}

private struct ChartCategoryValue: Identifiable {
    let id = UUID()
    let category: String
    let amount: Int
    let color: Color
}

private struct MonthlyDeltaValue: Identifiable {
    var id: Int { monthIndex }
    let monthIndex: Int
    let monthName: String
    let delta: Int
}

private struct DeltaBarsChartView: View {
    let points: [MonthlyDeltaValue]
    @Binding var selectedMonth: Int?
    let currencySymbol: String

    private var maxAbsDelta: Int {
        max(points.map { abs($0.delta) }.max() ?? 0, 1)
    }

    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let height = geo.size.height
            let baselineY = height * 0.54
            let topRange = max(24, baselineY - 34)
            let bottomRange = max(24, height - baselineY - 120)
            let horizontalInset: CGFloat = 10
            let plotWidth = max(width - (horizontalInset * 2), 1)
            let gap: CGFloat = 2
            let barsCount = max(points.count, 1)
            let barWidth = max(10, (plotWidth - (CGFloat(barsCount - 1) * gap)) / CGFloat(barsCount))
            let step = barWidth + gap

            ZStack(alignment: .topLeading) {
                Rectangle()
                    .fill(Color.black.opacity(0.55))
                    .frame(width: plotWidth, height: 1.2)
                    .position(x: horizontalInset + (plotWidth / 2), y: baselineY)

                ForEach(Array(points.enumerated()), id: \.element.id) { index, point in
                    if point.delta != 0 || selectedMonth == point.monthIndex {
                        let barHeight = heightForDelta(
                            point.delta,
                            topRange: topRange,
                            bottomRange: bottomRange
                        )
                        let x = horizontalInset + (CGFloat(index) * (barWidth + gap)) + (barWidth / 2)
                        let y = point.delta >= 0 ? (baselineY - (barHeight / 2)) : (baselineY + (barHeight / 2))

                        Rectangle()
                            .fill(point.delta >= 0 ? Color(.green) : Color(.red))
                            .frame(width: barWidth, height: barHeight)
                            .position(x: x, y: y)
                            .opacity(1)
                            .allowsHitTesting(false)
                    }
                }

                if let selectedMonth, let selectedPoint = points.first(where: { $0.monthIndex == selectedMonth }) {
                    let selectedIndex = max(0, selectedMonth - 1)
                    let selectedHeight = heightForDelta(
                        selectedPoint.delta,
                        topRange: topRange,
                        bottomRange: bottomRange
                    )
                    let selectedXRaw = horizontalInset + (CGFloat(selectedIndex) * (barWidth + gap)) + (barWidth / 2)
                    let selectedX = min(max(selectedXRaw, horizontalInset + 62), (width - horizontalInset) - 62)
                    let selectedY = selectedPoint.delta >= 0
                        ? (baselineY - (selectedHeight / 2))
                        : (baselineY + (selectedHeight / 2))
                    let badgeY: CGFloat = selectedPoint.delta >= 0
                        ? max(64, baselineY - selectedHeight - 42)
                        : baselineY

                    Rectangle()
                        .fill(selectedPoint.delta >= 0 ? Color(.green) : Color(.red))
                        .frame(width: barWidth, height: selectedHeight)
                        .shadow(color: .white.opacity(0.8), radius: 8)
                        .position(x: selectedXRaw, y: selectedY)

                    VStack(spacing: 2) {
                        Text(selectedPoint.monthName)
                            .font(.playfairDisplay(18, weight: .semibold))
                            .foregroundStyle(Color(.green))
                        Text(formatSignedAmount(selectedPoint.delta))
                            .font(.playfairDisplay(14))
                            .foregroundStyle(Color(.green))
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .shadow(color: .black.opacity(0.18), radius: 12, x: 0, y: 4)
                    .position(x: selectedX, y: badgeY)
                }
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onEnded { value in
                        let localX = min(max(value.location.x - horizontalInset, 0), plotWidth - 1)
                        let rawIndex = Int(localX / max(step, 1))
                        let clamped = min(max(rawIndex, 0), points.count - 1)
                        guard points.indices.contains(clamped) else { return }
                        withAnimation(.easeInOut(duration: 0.2)) {
                            let month = points[clamped].monthIndex
                            selectedMonth = selectedMonth == month ? nil : month
                        }
                    }
            )
        }
    }

    private func heightForDelta(_ delta: Int, topRange: CGFloat, bottomRange: CGFloat) -> CGFloat {
        guard delta != 0 else { return 2 }
        let ratio = CGFloat(abs(delta)) / CGFloat(maxAbsDelta)
        return max(2, (delta > 0 ? topRange : bottomRange) * ratio)
    }

    private func formatSignedAmount(_ value: Int) -> String {
        let absolute = AppMoney.formatCentsForInput(abs(value))
        let sign = value >= 0 ? "+" : "−"
        return "\(sign)\(absolute) \(currencySymbol)"
    }
}

private struct DonutChartView: View {
    let values: [ChartCategoryValue]
    let currencySymbol: String
    @State private var selectedIndex: Int?

    private var total: Int { max(values.reduce(0) { $0 + $1.amount }, 1) }

    var body: some View {
        GeometryReader { geo in
            let size = min(geo.size.width, geo.size.height)
            let lineWidth = size * 0.28

            ZStack {
                ForEach(Array(values.enumerated()), id: \.offset) { idx, value in
                    Circle()
                        .trim(from: startFraction(at: idx), to: endFraction(at: idx))
                        .stroke(value.color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .butt))
                        .rotationEffect(.degrees(-90))
                        .scaleEffect(selectedIndex == idx ? 1.15 : 1.0)
                        .animation(.easeInOut(duration: 0.2), value: selectedIndex)
                        .onTapGesture {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                selectedIndex = (selectedIndex == idx) ? nil : idx
                            }
                        }
                }

                if let selectedIndex, values.indices.contains(selectedIndex) {
                    VStack(spacing: 4) {
                        Text(values[selectedIndex].category)
                            .font(.playfairDisplay(16, weight: .semibold))
                            .foregroundStyle(.black)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                        Text(formatAmount(values[selectedIndex].amount))
                            .font(.playfairDisplay(14))
                            .foregroundStyle(.black.opacity(0.8))
                    }
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 10)
                }
            }
            .frame(width: size, height: size)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        }
    }

    private func startFraction(at index: Int) -> CGFloat {
        let prev = values.prefix(index).reduce(0) { $0 + $1.amount }
        return CGFloat(Double(prev) / Double(total))
    }

    private func endFraction(at index: Int) -> CGFloat {
        let amount = values.prefix(index + 1).reduce(0) { $0 + $1.amount }
        return CGFloat(Double(amount) / Double(total))
    }

    private func formatAmount(_ value: Int) -> String {
        AppMoney.formatCentsForDisplay(value, currencySymbol: currencySymbol)
    }
}
