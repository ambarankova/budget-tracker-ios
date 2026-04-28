import SwiftUI
import UIKit

struct AnalyticsView: View {

    @ObservedObject var viewModel: AnalyticsViewModel
    @Binding var isOverlayPresented: Bool

    @State private var isYearPickerPresented = false
    @State private var yearPickerDraft: Int = Calendar.current.component(.year, from: Date())
    @State private var modePickerDraft: FinanceMode = .expense
    @State private var planEditingCategoryName: String?
    @State private var planEditingDraft = ""
    @FocusState private var isPlanEditingFocused: Bool
    @State private var categoryNameEditingCategory: String?
    @State private var categoryNameEditingDraft = ""
    @State private var yearChartRoute: ChartMode?
    @State private var isSettingsPresented = false

    private var isAnyPopupVisible: Bool {
        planEditingCategoryName != nil || categoryNameEditingCategory != nil || isYearPickerPresented
    }

    private let monthSymbols = ["Янв","Фев","Мар","Апр","Май","Июн","Июл","Авг","Сен","Окт","Ноя","Дек"]

    var body: some View {
        ZStack(alignment: .bottom) {
            Color(.beige).ignoresSafeArea()

            VStack(spacing: 0) {
                HStack {
                    Spacer()
                    SettingsButton { isSettingsPresented = true }
                }

                HStack {
                    Text(viewModel.displayMode.screenTitle)
                        .font(.playfairDisplay(40, weight: .semibold))
                        .foregroundStyle(Color(.green))
                    Spacer()
                    Button {
                        yearPickerDraft = viewModel.selectedYear
                        modePickerDraft = viewModel.displayMode
                        withAnimation(.easeInOut(duration: 0.22)) { isYearPickerPresented = true }
                    } label: {
                        HStack(spacing: 6) {
                            Text(String(viewModel.selectedYear))
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
                            categoryColumn(minHeight: max(0, geo.size.height + 18))

                            ScrollView(.horizontal, showsIndicators: true) {
                                monthsAndPlanColumns(minHeight: max(0, geo.size.height + 18))
                                    .padding(.trailing, AppLayout.screenHorizontalPadding)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, AppLayout.screenHorizontalPadding)
                    }
                    .frame(maxHeight: .infinity)
                }

                HStack(spacing: 26) {
                    Button { openChart(.pie) } label: {
                        Image(systemName: "chart.pie.fill")
                            .font(.system(size: 36))
                            .foregroundStyle(Color(.gray))
                    }
                    .buttonStyle(.plain)

                    Button { openChart(.bar) } label: {
                        Image(systemName: "chart.bar")
                            .font(.system(size: 36))
                            .foregroundStyle(Color(.gray))
                    }
                    .buttonStyle(.plain)
                }
                .opacity(yearChartRoute == nil ? 1 : 0)
                .allowsHitTesting(yearChartRoute == nil)
                .frame(maxWidth: .infinity)
                .frame(height: 86)
            }

            if isAnyPopupVisible {
                Color.black.opacity(0.2)
                    .ignoresSafeArea()
                    .onTapGesture { closeAllPopups() }
                    .zIndex(1)
            }

            if planEditingCategoryName != nil {
                planEditorOverlay
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                    .zIndex(2)
            }

            if categoryNameEditingCategory != nil {
                categoryNameEditorOverlay
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
                AnalyticsChartView(
                    viewModel: viewModel,
                    initialMode: route,
                    onDismiss: { yearChartRoute = nil }
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .zIndex(3)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            viewModel.onAppear()
            syncOverlayState()
        }
        .onChange(of: planEditingCategoryName != nil)      { _ in syncOverlayState() }
        .onChange(of: categoryNameEditingCategory != nil)  { _ in syncOverlayState() }
        .onChange(of: isYearPickerPresented)               { _ in syncOverlayState() }
        .onChange(of: isSettingsPresented) { isPresented in
            guard !isPresented else { return }
            viewModel.onSettingsDismissed()
        }
        .onDisappear { isOverlayPresented = false }
        .fullScreenCover(isPresented: $isSettingsPresented) {
            AppSettingsView(onBack: { isSettingsPresented = false })
        }
    }

    // MARK: - Private helpers

    private func openChart(_ mode: ChartMode) {
        closeAllPopups()
        yearChartRoute = mode
    }

    private func closeAllPopups() {
        withAnimation(.easeInOut(duration: 0.22)) {
            planEditingCategoryName = nil
            categoryNameEditingCategory = nil
            isYearPickerPresented = false
        }
        planEditingDraft = ""
        isPlanEditingFocused = false
        categoryNameEditingDraft = ""
        syncOverlayState()
    }

    private func syncOverlayState() {
        isOverlayPresented = isAnyPopupVisible
    }

    // MARK: - Table sub-views

    @ViewBuilder
    private func categoryColumn(minHeight: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Категория")
                .font(.playfairDisplay(20))
                .frame(width: 150, alignment: .leading)
                .padding(.vertical, 8)
            Divider().overlay(Color(.gray).opacity(0.3))

            ForEach(viewModel.categoryRows) { row in
                Text(row.name)
                    .lineLimit(1)
                    .font(.playfairDisplay(20))
                    .frame(width: 150, alignment: .leading)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        withAnimation(.easeInOut(duration: 0.22)) {
                            categoryNameEditingCategory = row.name
                            categoryNameEditingDraft = row.name
                        }
                    }
                    .padding(.vertical, 8)
                Divider().overlay(Color(.gray).opacity(0.3))
            }

            Spacer()
            Text("Итого")
                .font(.playfairDisplay(20, weight: .bold))
                .frame(width: 150, alignment: .leading)
                .padding(.vertical, 8)
                .padding(.bottom, 10)
        }
        .frame(minHeight: minHeight, alignment: .top)
    }

    @ViewBuilder
    private func monthsAndPlanColumns(minHeight: CGFloat) -> some View {
        VStack(spacing: 0) {
            // Header
            monthRow(values: monthSymbols + ["Итого"], planText: "План", bold: false, onPlanTap: nil)
                .padding(.vertical, 8)
            Divider().overlay(Color(.gray).opacity(0.3))

            ForEach(viewModel.categoryRows) { row in
                monthRow(
                    values: monthValues(for: row),
                    planText: formatAmount(row.plan),
                    bold: false,
                    onPlanTap: {
                        withAnimation(.easeInOut(duration: 0.22)) {
                            planEditingCategoryName = row.name
                            planEditingDraft = AppMoney.formatCentsForInput(row.plan)
                        }
                    }
                )
                .padding(.vertical, 8)
                Divider().overlay(Color(.gray).opacity(0.3))
            }

            Spacer()
            monthRow(
                values: totalMonthValues(),
                planText: formatAmount(viewModel.totalPlan),
                bold: true,
                onPlanTap: nil
            )
            .padding(.vertical, 8)
            .padding(.bottom, 10)
        }
        .frame(minHeight: minHeight, alignment: .top)
    }

    private func monthRow(values: [String], planText: String, bold: Bool, onPlanTap: (() -> Void)?) -> some View {
        HStack(spacing: 12) {
            ForEach(Array(values.enumerated()), id: \.offset) { _, value in
                Text(value)
                    .font(.playfairDisplay(20, weight: bold ? .bold : .regular))
                    .frame(width: 110, alignment: .leading)
            }
            Text(planText)
                .font(.playfairDisplay(20, weight: bold ? .bold : .regular))
                .frame(width: 84, alignment: .leading)
                .contentShape(Rectangle())
                .onTapGesture { onPlanTap?() }
        }
    }

    private func monthValues(for row: CategoryYearSummary) -> [String] {
        let months = (1...12).map { month -> String in
            guard viewModel.hasDataByMonth[month] == true else { return "—" }
            return formatAmount(row.monthlyFact[month] ?? 0)
        }
        return months + [formatAmount(row.yearTotal)]
    }

    private func totalMonthValues() -> [String] {
        let months = (1...12).map { month -> String in
            guard viewModel.hasDataByMonth[month] == true else { return "—" }
            let total = viewModel.categoryRows.reduce(0) { $0 + ($1.monthlyFact[month] ?? 0) }
            return formatAmount(total)
        }
        let grandTotal = viewModel.categoryRows.reduce(0) { $0 + $1.yearTotal }
        return months + [formatAmount(grandTotal)]
    }

    private func formatAmount(_ value: Int) -> String {
        AppMoney.formatCentsForDisplay(value, currencySymbol: viewModel.baseCurrencySymbol)
    }

    // MARK: - Popups

    private var yearPickerOverlay: some View {
        VStack(spacing: 12) {
            Picker("", selection: $modePickerDraft) {
                Text(FinanceMode.expense.screenTitle).tag(FinanceMode.expense)
                Text(FinanceMode.income.screenTitle).tag(FinanceMode.income)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 2)

            Picker("Год", selection: $yearPickerDraft) {
                ForEach(viewModel.availableYears, id: \.self) { Text(String($0)).tag($0) }
            }
            .pickerStyle(.wheel)
            .labelsHidden()
            .frame(height: 180)

            HStack(spacing: 12) {
                Button("Отмена") {
                    withAnimation(.easeInOut(duration: 0.22)) { isYearPickerPresented = false }
                    syncOverlayState()
                }
                .overlayButton(style: .cancel)

                Button("ОК") {
                    viewModel.selectedYear  = yearPickerDraft
                    viewModel.displayMode   = modePickerDraft
                    withAnimation(.easeInOut(duration: 0.22)) { isYearPickerPresented = false }
                    syncOverlayState()
                    viewModel.onYearOrModeChanged()
                }
                .overlayButton(style: .confirm)
            }
        }
        .overlayCard()
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }

    private var planEditorOverlay: some View {
        VStack(spacing: 12) {
            Text("Введите значение")
                .font(.playfairDisplay(24, weight: .semibold))
                .foregroundStyle(.black)

            TextField("0", text: Binding(
                get: { formattedAmountInput(planEditingDraft) },
                set: { planEditingDraft = AppMoney.normalizeInput($0) }
            ))
            .focused($isPlanEditingFocused)
            .keyboardType(.decimalPad)
            .font(.playfairDisplay(36, weight: .semibold))
            .padding(.horizontal, 12)
            .frame(height: 56)
            .background(.white)
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color(.gray).opacity(0.5), lineWidth: 1))
            .clipShape(RoundedRectangle(cornerRadius: 10))

            HStack(spacing: 12) {
                Button("Отмена") { closeAllPopups() }.overlayButton(style: .cancel)
                Button("ОК") {
                    guard let cents = AppMoney.parseToCents(planEditingDraft), cents >= 0,
                          let name = planEditingCategoryName else { return }
                    viewModel.updateCategoryPlan(name: name, planInBaseCurrency: cents)
                    closeAllPopups()
                }
                .overlayButton(style: .confirm)
            }
        }
        .overlayCard()
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { isPlanEditingFocused = true }
        }
    }

    @ViewBuilder
    private var categoryNameEditorOverlay: some View {
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
                    Button("Отмена") { closeAllPopups() }.overlayButton(style: .cancel)
                    Button("ОК") {
                        let newName = categoryNameEditingDraft.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !newName.isEmpty, newName != oldName else { closeAllPopups(); return }
                        viewModel.renameCategory(from: oldName, to: newName)
                        closeAllPopups()
                    }
                    .overlayButton(style: .confirm)
                }
            }
            .overlayCard()
        }
    }

    private func formattedAmountInput(_ text: String) -> String {
        let normalized = AppMoney.normalizeInput(text)
        guard let cents = AppMoney.parseToCents(normalized) else { return normalized }
        return AppMoney.formatCentsForInput(cents)
    }
}

// MARK: - Chart mode

enum ChartMode: String, Identifiable {
    case pie, bar
    var id: String { rawValue }
}

// MARK: - Chart view

private struct AnalyticsChartView: View {
    @ObservedObject var viewModel: AnalyticsViewModel
    let initialMode: ChartMode
    var onDismiss: () -> Void

    @State private var chartMode: ChartMode
    @State private var selectedDeltaMonth: Int?
    @State private var isSettingsPresented = false

    init(viewModel: AnalyticsViewModel, initialMode: ChartMode, onDismiss: @escaping () -> Void) {
        self.viewModel = viewModel
        self.initialMode = initialMode
        self.onDismiss = onDismiss
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
                            Image(systemName: "chevron.left").font(.system(size: 24, weight: .medium))
                            Text("Назад").font(.playfairDisplay(24, weight: .semibold))
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
                    Text(chartMode == .bar ? "Дельта" : viewModel.displayMode.screenTitle)
                        .font(.playfairDisplay(40, weight: .semibold))
                        .foregroundStyle(Color(.green))
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)

                if chartMode == .pie {
                    Spacer(minLength: 98)
                    DonutChartView(values: viewModel.chartValues, currencySymbol: viewModel.baseCurrencySymbol)
                        .frame(height: 198)
                        .padding(.horizontal, 42)
                        .padding(.top, 18)

                    ScrollView(.vertical, showsIndicators: true) {
                        VStack(alignment: .leading, spacing: 10) {
                            ForEach(viewModel.chartValues) { value in
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
                        points: viewModel.deltaByMonth,
                        selectedMonth: $selectedDeltaMonth,
                        currencySymbol: viewModel.baseCurrencySymbol
                    )
                    .frame(maxWidth: .infinity)
                    .frame(maxHeight: .infinity)
                }

                HStack(spacing: 26) {
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) { chartMode = .pie; selectedDeltaMonth = nil }
                    } label: {
                        Image(systemName: "chart.pie.fill")
                            .font(.system(size: 36))
                            .foregroundStyle(chartMode == .pie ? Color(.green) : Color(.gray))
                    }
                    .buttonStyle(.plain)

                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) { chartMode = .bar }
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
        .onAppear { chartMode = initialMode; selectedDeltaMonth = nil }
        .onChange(of: isSettingsPresented) { isPresented in
            guard !isPresented else { return }
            viewModel.onSettingsDismissed()
        }
        .fullScreenCover(isPresented: $isSettingsPresented) {
            AppSettingsView(onBack: { isSettingsPresented = false })
        }
    }

    private func percent(for amount: Int) -> Int {
        let total = max(viewModel.chartValues.reduce(0) { $0 + $1.amount }, 1)
        return Int((Double(amount) / Double(total) * 100).rounded())
    }
}

// MARK: - Donut chart

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
                if let idx = selectedIndex, values.indices.contains(idx) {
                    VStack(spacing: 4) {
                        Text(values[idx].category)
                            .font(.playfairDisplay(16, weight: .semibold))
                            .foregroundStyle(.black)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                        Text(AppMoney.formatCentsForDisplay(values[idx].amount, currencySymbol: currencySymbol))
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

    private func startFraction(at i: Int) -> CGFloat {
        CGFloat(Double(values.prefix(i).reduce(0) { $0 + $1.amount }) / Double(total))
    }
    private func endFraction(at i: Int) -> CGFloat {
        CGFloat(Double(values.prefix(i + 1).reduce(0) { $0 + $1.amount }) / Double(total))
    }
}

// MARK: - Delta bars chart

private struct DeltaBarsChartView: View {
    let points: [MonthlyDeltaValue]
    @Binding var selectedMonth: Int?
    let currencySymbol: String

    private var maxAbsDelta: Int { max(points.map { abs($0.delta) }.max() ?? 0, 1) }

    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let height = geo.size.height
            let baselineY = height * 0.54
            let topRange = max(24, baselineY - 34)
            let bottomRange = max(24, height - baselineY - 120)
            let inset: CGFloat = 10
            let plotWidth = max(width - inset * 2, 1)
            let gap: CGFloat = 2
            let count = max(points.count, 1)
            let barWidth = max(10, (plotWidth - CGFloat(count - 1) * gap) / CGFloat(count))
            let step = barWidth + gap

            ZStack(alignment: .topLeading) {
                Rectangle()
                    .fill(Color.black.opacity(0.55))
                    .frame(width: plotWidth, height: 1.2)
                    .position(x: inset + plotWidth / 2, y: baselineY)

                ForEach(Array(points.enumerated()), id: \.element.id) { index, point in
                    if point.delta != 0 || selectedMonth == point.monthIndex {
                        let barH = barHeight(point.delta, top: topRange, bottom: bottomRange)
                        let x = inset + CGFloat(index) * step + barWidth / 2
                        let y = point.delta >= 0 ? (baselineY - barH / 2) : (baselineY + barH / 2)
                        Rectangle()
                            .fill(point.delta >= 0 ? Color(.green) : Color(.red))
                            .frame(width: barWidth, height: barH)
                            .position(x: x, y: y)
                            .allowsHitTesting(false)
                    }
                }

                if let sel = selectedMonth, let point = points.first(where: { $0.monthIndex == sel }) {
                    let idx = max(0, sel - 1)
                    let barH = barHeight(point.delta, top: topRange, bottom: bottomRange)
                    let rawX = inset + CGFloat(idx) * step + barWidth / 2
                    let clampedX = min(max(rawX, inset + 62), width - inset - 62)
                    let barY = point.delta >= 0 ? (baselineY - barH / 2) : (baselineY + barH / 2)
                    let badgeY: CGFloat = point.delta >= 0 ? max(64, baselineY - barH - 42) : baselineY

                    Rectangle()
                        .fill(point.delta >= 0 ? Color(.green) : Color(.red))
                        .frame(width: barWidth, height: barH)
                        .shadow(color: .white.opacity(0.8), radius: 8)
                        .position(x: rawX, y: barY)

                    VStack(spacing: 2) {
                        Text(point.monthName).font(.playfairDisplay(18, weight: .semibold)).foregroundStyle(Color(.green))
                        Text(signedAmount(point.delta)).font(.playfairDisplay(14)).foregroundStyle(Color(.green))
                    }
                    .padding(.horizontal, 12).padding(.vertical, 8)
                    .background(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .shadow(color: .black.opacity(0.18), radius: 12, x: 0, y: 4)
                    .position(x: clampedX, y: badgeY)
                }
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0).onEnded { value in
                    let localX = min(max(value.location.x - inset, 0), plotWidth - 1)
                    let rawIdx = Int(localX / max(step, 1))
                    let clamped = min(max(rawIdx, 0), points.count - 1)
                    guard points.indices.contains(clamped) else { return }
                    withAnimation(.easeInOut(duration: 0.2)) {
                        let month = points[clamped].monthIndex
                        selectedMonth = selectedMonth == month ? nil : month
                    }
                }
            )
        }
    }

    private func barHeight(_ delta: Int, top: CGFloat, bottom: CGFloat) -> CGFloat {
        guard delta != 0 else { return 2 }
        let ratio = CGFloat(abs(delta)) / CGFloat(maxAbsDelta)
        return max(2, (delta > 0 ? top : bottom) * ratio)
    }

    private func signedAmount(_ value: Int) -> String {
        "\(value >= 0 ? "+" : "−")\(AppMoney.formatCentsForInput(abs(value))) \(currencySymbol)"
    }
}

// MARK: - UIKit-backed scroll view (preserves existing inset behaviour)

private struct ScrollViewWithoutInsets<Content: View>: UIViewRepresentable {
    let content: Content
    init(@ViewBuilder content: () -> Content) { self.content = content() }

    func makeUIView(context: Context) -> UIScrollView {
        let scrollView = UIScrollView()
        scrollView.contentInsetAdjustmentBehavior = .never
        scrollView.contentInset = .zero
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

    func makeCoordinator() -> Coordinator { Coordinator() }
    class Coordinator { var hosting: UIHostingController<Content>? }
}

// MARK: - Button style helpers

private enum OverlayButtonStyle { case cancel, confirm }

private extension Button {
    @ViewBuilder
    func overlayButton(style: OverlayButtonStyle) -> some View {
        self
            .font(.playfairDisplay(20, weight: .semibold))
            .foregroundStyle(style == .cancel ? .black : Color(.green))
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(style == .cancel ? Color(.systemGray5) : .white)
            .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

private extension View {
    func overlayCard() -> some View {
        self.padding(16)
            .background(.white)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .padding(.horizontal, 20)
    }
}
