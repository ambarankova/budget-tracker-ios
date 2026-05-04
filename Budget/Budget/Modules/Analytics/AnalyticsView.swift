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
    
    private let monthSymbols: [String] = {
        var f = DateFormatter(); f.locale = Locale.current; return f.shortMonthSymbols
    }()
    
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
                            
                            ScrollViewReader { proxy in
                                ScrollView(.horizontal, showsIndicators: true) {
                                    monthsAndPlanColumns(minHeight: max(0, geo.size.height + 18))
                                        .padding(.trailing, AppLayout.screenHorizontalPadding)
                                }
                                .onAppear {
                                    DispatchQueue.main.async {
                                        proxy.scrollTo("analyticsMonth_\(scrollTargetMonth)", anchor: .leading)
                                    }
                                }
                                .onChange(of: viewModel.selectedYear) { _ in
                                    withAnimation(.easeInOut(duration: 0.3)) {
                                        proxy.scrollTo("analyticsMonth_\(scrollTargetMonth)", anchor: .leading)
                                    }
                                }
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
        .onChange(of: planEditingCategoryName != nil) { _ in syncOverlayState() }
        .onChange(of: categoryNameEditingCategory != nil) { _ in syncOverlayState() }
        .onChange(of: isYearPickerPresented) { _ in syncOverlayState() }
        .onChange(of: isSettingsPresented) { isPresented in
            guard !isPresented else { return }
            viewModel.onSettingsDismissed()
        }
        .onDisappear { isOverlayPresented = false }
        .fullScreenCover(isPresented: $isSettingsPresented) {
            AppSettingsView(onBack: { isSettingsPresented = false })
        }
    }
}

private extension AnalyticsView {
    
    // MARK: - Table sub-views
    
    @ViewBuilder
    func categoryColumn(minHeight: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(L10n.category)
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
            Text(L10n.total)
                .font(.playfairDisplay(20, weight: .bold))
                .frame(width: 150, alignment: .leading)
                .padding(.vertical, 8)
                .padding(.bottom, 10)
        }
        .frame(minHeight: minHeight, alignment: .top)
    }
    
    @ViewBuilder
    func monthsAndPlanColumns(minHeight: CGFloat) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                ForEach(Array(monthSymbols.enumerated()), id: \.offset) { index, symbol in
                    Text(symbol)
                        .font(.playfairDisplay(20))
                        .frame(width: 110, alignment: .leading)
                        .id("analyticsMonth_\(index + 1)")
                }
                Text(L10n.total)
                    .font(.playfairDisplay(20))
                    .frame(width: 110, alignment: .leading)
                Text(L10n.plan)
                    .font(.playfairDisplay(20))
                    .frame(width: 84, alignment: .leading)
            }
            .padding(.vertical, 8)
            Divider().overlay(Color(.gray).opacity(0.3))
            
            ForEach(viewModel.categoryRows) { row in
                monthRow(
                    values: viewModel.monthValues(for: row),
                    planText: viewModel.formattedAmount(row.plan),
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
                values: viewModel.totalMonthValues(),
                planText: viewModel.formattedAmount(viewModel.totalPlan),
                bold: true,
                onPlanTap: nil
            )
            .padding(.vertical, 8)
            .padding(.bottom, 10)
        }
        .frame(minHeight: minHeight, alignment: .top)
    }
    
    func monthRow(values: [String], planText: String, bold: Bool, onPlanTap: (() -> Void)?) -> some View {
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
    
    // MARK: - Private helpers

    private var scrollTargetMonth: Int {
        let currentYear = Calendar.current.component(.year, from: Date())
        guard viewModel.selectedYear == currentYear else { return 12 }
        return Calendar.current.component(.month, from: Date())
    }

    func openChart(_ mode: ChartMode) {
        closeAllPopups()
        yearChartRoute = mode
    }
    
    func closeAllPopups() {
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
    
    func syncOverlayState() {
        isOverlayPresented = isAnyPopupVisible
    }
    
    // MARK: - Overlays
    
    var yearPickerOverlay: some View {
        VStack(spacing: 12) {
            Picker("", selection: $modePickerDraft) {
                Text(FinanceMode.expense.screenTitle).tag(FinanceMode.expense)
                Text(FinanceMode.income.screenTitle).tag(FinanceMode.income)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 2)
            
            Picker(L10n.year, selection: $yearPickerDraft) {
                ForEach(viewModel.availableYears, id: \.self) { Text(String($0)).tag($0) }
            }
            .pickerStyle(.wheel)
            .labelsHidden()
            .frame(height: 180)
            
            HStack(spacing: 12) {
                Button(L10n.cancel) {
                    withAnimation(.easeInOut(duration: 0.22)) { isYearPickerPresented = false }
                    syncOverlayState()
                }
                .overlayButton(style: .cancel)
                
                Button(L10n.ok) {
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
    
    var planEditorOverlay: some View {
        VStack(spacing: 12) {
            Text(L10n.enterValue)
                .font(.playfairDisplay(24, weight: .semibold))
                .foregroundStyle(.black)
            
            TextField("0", text: Binding(
                get: { viewModel.formattedAmountInput(planEditingDraft) },
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
                Button(L10n.cancel) { closeAllPopups() }.overlayButton(style: .cancel)
                Button(L10n.ok) {
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
                
                HStack(spacing: 12) {
                    Button(L10n.cancel) { closeAllPopups() }.overlayButton(style: .cancel)
                    Button(L10n.ok) {
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
}
