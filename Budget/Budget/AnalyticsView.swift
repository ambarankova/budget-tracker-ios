import SwiftUI

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
    @State private var categories: [String] = []
    @State private var plansByCategory: [String: Int] = [:]
    @State private var monthlyByCategory: [String: [Int: Int]] = [:]
    @State private var hasAnyDataByMonth: [Int: Bool] = [:]
    @State private var planEditingCategoryName: String?
    @State private var planEditingDraft = ""
    @State private var yearChartRoute: AnalyticsYearChartMode?
    @State private var isSettingsPresented = false

    private let mode: FinanceMode = .expense
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
        planEditingCategoryName != nil || isYearPickerPresented
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
                    Text("Расходы")
                        .font(.playfairDisplay(40, weight: .semibold))
                        .foregroundStyle(Color(.green))
                    Spacer()
                    Button {
                        yearPickerDraft = selectedYear
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
                .padding(.horizontal, 20)
                .padding(.top, -8)
                .padding(.bottom, 8)

                GeometryReader { geo in
                    ScrollView(.vertical, showsIndicators: true) {
                        HStack(alignment: .top, spacing: 12) {
                            fixedColumnsTable(minHeight: max(0, geo.size.height + 18))

                            ScrollView(.horizontal, showsIndicators: true) {
                                monthsTable(minHeight: max(0, geo.size.height + 18))
                            }
                        }
                        .padding(.horizontal, 20)
                    }
                }

                ZStack {
                    HStack(spacing: 26) {
                        Button {
                            yearChartRoute = .pie
                        } label: {
                            Image(systemName: "chart.pie.fill")
                                .font(.system(size: 36))
                                .foregroundStyle(Color(.gray))
                        }
                        .buttonStyle(.plain)

                        Button {
                            yearChartRoute = .bar
                        } label: {
                            Image(systemName: "chart.bar")
                                .font(.system(size: 36))
                                .foregroundStyle(Color(.gray))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 86)
            }

            if isAnyPopupVisible {
                Color.black.opacity(0.2)
                    .ignoresSafeArea()
                    .onTapGesture {
                        closePlanEditor()
                        closeYearPicker()
                    }
                    .zIndex(1)
            }

            if planEditingCategoryName != nil {
                planEditingOverlay
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                    .zIndex(2)
            }

            if isYearPickerPresented {
                yearPickerOverlay
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                    .zIndex(2)
            }
        }
        .onAppear {
            selectedYear = availableYears.first ?? selectedYear
            recalculate()
            syncOverlayState()
        }
        .onChange(of: planEditingCategoryName != nil) { _ in syncOverlayState() }
        .onChange(of: isYearPickerPresented) { _ in syncOverlayState() }
        .onDisappear { isOverlayPresented = false }
        .fullScreenCover(item: $yearChartRoute) { route in
            AnalyticsYearChartView(
                mode: mode,
                initialYear: selectedYear,
                initialMode: route,
                onDismiss: { yearChartRoute = nil }
            )
        }
        .fullScreenCover(isPresented: $isSettingsPresented) {
            AppSettingsView(onBack: { isSettingsPresented = false })
        }
    }
}

private extension AnalyticsView {
    var yearPickerOverlay: some View {
        VStack(spacing: 12) {
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
                    recalculate()
                    closeYearPicker()
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
            .keyboardType(.numberPad)
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
                    let cleaned = planEditingDraft.replacingOccurrences(of: " ", with: "")
                    guard let plan = Int(cleaned), plan >= 0, let category = planEditingCategoryName else { return }
                    plansByCategory[category] = plan
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
    }

    @ViewBuilder
    func fixedColumnsRow(
        title: String,
        planText: String,
        isHeader: Bool,
        isTotal: Bool = false,
        onPlanTap: (() -> Void)? = nil
    ) -> some View {
        HStack(spacing: 12) {
            Text(title)
                .lineLimit(1)
                .truncationMode(.tail)
                .font(.playfairDisplay(20, weight: isTotal ? .bold : .regular))
                .frame(width: 130, alignment: .leading)

            Text(planText)
                .font(.playfairDisplay(20, weight: isTotal ? .bold : .regular))
                .frame(width: 84, alignment: .leading)
                .contentShape(Rectangle())
                .onTapGesture {
                    if !isHeader { onPlanTap?() }
                }
        }
    }

    @ViewBuilder
    func monthsRow(values: [String], isTotal: Bool) -> some View {
        HStack(spacing: 12) {
            ForEach(Array(values.enumerated()), id: \.offset) { _, value in
                Text(value)
                    .font(.playfairDisplay(20, weight: isTotal ? .bold : .regular))
                    .frame(width: 110, alignment: .leading)
            }
        }
    }

    @ViewBuilder
    func fixedColumnsTable(minHeight: CGFloat) -> some View {
        VStack(spacing: 0) {
            fixedColumnsRow(title: "Категория", planText: "План", isHeader: true)
                .padding(.vertical, 8)
            Divider().overlay(Color(.gray).opacity(0.3))

            ForEach(categories, id: \.self) { category in
                let planValue = plansByCategory[category] ?? 0
                fixedColumnsRow(
                    title: category,
                    planText: formatAmount(planValue),
                    isHeader: false,
                    isTotal: false,
                    onPlanTap: {
                        withAnimation(.easeInOut(duration: 0.22)) {
                            planEditingCategoryName = category
                            planEditingDraft = String(planValue)
                        }
                    }
                )
                .padding(.vertical, 8)
                Divider().overlay(Color(.gray).opacity(0.3))
            }

            Spacer()

            fixedColumnsRow(
                title: "Итого",
                planText: formatAmount(totalPlan),
                isHeader: false,
                isTotal: true
            )
            .padding(.vertical, 8)
            .padding(.bottom, 10)
        }
        .frame(minHeight: minHeight, alignment: .top)
    }

    @ViewBuilder
    func monthsTable(minHeight: CGFloat) -> some View {
        VStack(spacing: 0) {
            monthsRow(values: monthSymbols + ["Итого"], isTotal: false)
                .padding(.vertical, 8)
            Divider().overlay(Color(.gray).opacity(0.3))

            ForEach(categories, id: \.self) { category in
                monthsRow(values: valuesForCategoryYear(category: category), isTotal: false)
                    .padding(.vertical, 8)
                Divider().overlay(Color(.gray).opacity(0.3))
            }

            Spacer()

            monthsRow(values: totalValuesForYear(), isTotal: true)
                .padding(.vertical, 8)
                .padding(.bottom, 10)
        }
        .frame(minHeight: minHeight, alignment: .top)
    }

    func recalculate() {
        let transactions = loadTransactions(for: mode.storageKey)
        let filtered = transactions.filter { Calendar.current.component(.year, from: $0.date) == selectedYear }
        let monthGroups = Dictionary(grouping: filtered) { Calendar.current.component(.month, from: $0.date) }
        hasAnyDataByMonth = Dictionary(uniqueKeysWithValues: (1...12).map { ($0, !(monthGroups[$0] ?? []).isEmpty) })

        monthlyByCategory = [:]
        for (month, monthTransactions) in monthGroups {
            let byCategory = Dictionary(grouping: monthTransactions, by: \.category).mapValues { list in
                list.reduce(0) { $0 + $1.amount }
            }
            for (category, amount) in byCategory {
                monthlyByCategory[category, default: [:]][month] = amount
            }
        }

        let categoriesFromData = Set(filtered.map(\.category))
        let storedPlans = loadPlans()
        let categoriesFromPlan = Set(storedPlans.keys)
        let base = Set(mode.defaultCategories.map(\.category))
        categories = Array(base.union(categoriesFromData).union(categoriesFromPlan)).sorted()
        plansByCategory = storedPlans
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
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = " "
        formatter.maximumFractionDigits = 0
        return (formatter.string(from: NSNumber(value: value)) ?? "\(value)") + " ₽"
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

    func closePlanEditor() {
        withAnimation(.easeInOut(duration: 0.22)) {
            planEditingCategoryName = nil
        }
        planEditingDraft = ""
        syncOverlayState()
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
        var formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = ""
        formatter.usesGroupingSeparator = false
        return formatter.string(from: NSNumber(value: year)) ?? "\(year)"
    }

    func savePlans() {
        UserDefaults.standard.set(plansByCategory, forKey: mode.planStorageKey)
    }

    func loadPlans() -> [String: Int] {
        UserDefaults.standard.dictionary(forKey: mode.planStorageKey) as? [String: Int] ?? [:]
    }

    func loadTransactions(for storageKey: String) -> [AnalyticsTransaction] {
        guard let data = UserDefaults.standard.data(forKey: storageKey) else { return [] }
        guard let transactions = try? JSONDecoder().decode([AnalyticsTransaction].self, from: data) else { return [] }
        return transactions
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
    @State private var isYearPickerPresented = false
    @State private var yearPickerDraft: Int
    @State private var values: [ChartCategoryValue] = []
    @State private var deltaByMonth: [MonthlyDeltaValue] = []
    @State private var chartMode: AnalyticsYearChartMode
    @State private var selectedDeltaMonth: Int?
    @State private var isSettingsPresented = false

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
        _yearPickerDraft = State(initialValue: initialYear)
        _chartMode = State(initialValue: initialMode)
    }

    private var availableYears: [Int] {
        let expenseYears = loadTransactions(for: FinanceMode.expense.storageKey)
            .map { Calendar.current.component(.year, from: $0.date) }
        let incomeYears = loadTransactions(for: FinanceMode.income.storageKey)
            .map { Calendar.current.component(.year, from: $0.date) }
        let years = Set(expenseYears + incomeYears)
        let sorted = years.sorted(by: >)
        return sorted.isEmpty ? [Calendar.current.component(.year, from: Date())] : sorted
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            Color(.beige).ignoresSafeArea()

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
                    if chartMode == .bar {
                        Text("Дельта")
                            .font(.playfairDisplay(40, weight: .semibold))
                            .foregroundStyle(Color(.green))
                    } else {
                        Text(yearText(selectedYear))
                            .font(.playfairDisplay(40, weight: .semibold))
                            .foregroundStyle(Color(.green))
                    }
                    Spacer()
                    Button {
                        yearPickerDraft = selectedYear
                        withAnimation(.easeInOut(duration: 0.22)) {
                            isYearPickerPresented = true
                        }
                    } label: {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(Color(.green))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)

                if chartMode == .pie {
                    Spacer(minLength: 98)
                }

                if chartMode == .pie {
                    DonutChartView(values: values)
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
                    .padding(.top, 48)
                    .frame(maxHeight: .infinity)
                } else {
                    DeltaBarsChartView(
                        points: deltaByMonth,
                        selectedMonth: $selectedDeltaMonth
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
                .padding(.bottom, 8)
            }

            if isYearPickerPresented {
                Color.black.opacity(0.2)
                    .ignoresSafeArea()
                    .onTapGesture { closeYearPicker() }
                    .zIndex(1)

                VStack(spacing: 12) {
                    Picker("Год", selection: $yearPickerDraft) {
                        ForEach(availableYears, id: \.self) { year in
                            Text(yearText(year)).tag(year)
                        }
                    }
                    .pickerStyle(.wheel)
                    .labelsHidden()
                    .frame(height: 180)

                    HStack(spacing: 12) {
                        Button("Отмена") { closeYearPicker() }
                            .font(.playfairDisplay(20, weight: .semibold))
                            .foregroundStyle(.black)
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(Color(.systemGray5))
                            .clipShape(RoundedRectangle(cornerRadius: 10))

                        Button("ОК") {
                            selectedYear = yearPickerDraft
                            recalculate()
                            recalculateDeltaByMonth()
                            selectedDeltaMonth = nil
                            closeYearPicker()
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
                .zIndex(2)
            }
        }
        .onAppear {
            chartMode = initialMode
            selectedDeltaMonth = nil
            selectedYear = availableYears.first ?? selectedYear
            recalculate()
            recalculateDeltaByMonth()
        }
        .fullScreenCover(isPresented: $isSettingsPresented) {
            AppSettingsView(onBack: { isSettingsPresented = false })
        }
    }

    private func recalculate() {
        let transactions = loadTransactions(for: mode.storageKey)
            .filter { Calendar.current.component(.year, from: $0.date) == selectedYear }
        let grouped = Dictionary(grouping: transactions, by: \.category)
            .mapValues { $0.reduce(0) { $0 + $1.amount } }
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
            .mapValues { $0.reduce(0) { $0 + $1.amount } }
        let incomeByMonth = Dictionary(grouping: incomes) { Calendar.current.component(.month, from: $0.date) }
            .mapValues { $0.reduce(0) { $0 + $1.amount } }

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

    private func closeYearPicker() {
        withAnimation(.easeInOut(duration: 0.22)) {
            isYearPickerPresented = false
        }
    }

    private func yearText(_ year: Int) -> String {
        var formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = ""
        formatter.usesGroupingSeparator = false
        return formatter.string(from: NSNumber(value: year)) ?? "\(year)"
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
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = " "
        formatter.maximumFractionDigits = 0

        let absolute = formatter.string(from: NSNumber(value: abs(value))) ?? "\(abs(value))"
        let sign = value >= 0 ? "+" : "−"
        return "\(sign)\(absolute) ₽"
    }
}

private struct DonutChartView: View {
    let values: [ChartCategoryValue]
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
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = " "
        formatter.maximumFractionDigits = 0
        return (formatter.string(from: NSNumber(value: value)) ?? "\(value)") + " ₽"
    }
}
