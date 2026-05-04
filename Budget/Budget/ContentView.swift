import SwiftUI

struct ContentView: View {
    @StateObject private var expenseVM:   FinanceDashboardViewModel
    @StateObject private var incomeVM:    FinanceDashboardViewModel
    @StateObject private var analyticsVM: AnalyticsViewModel
    @StateObject private var goalsVM:     GoalsViewModel

    @State private var selectedTab: BottomMenuItem = .expense
    @State private var isAnyOverlayPresented = false
    @State private var isBottomGreenFillPresented = false

    init(dependencies: AppDependencies = .live) {
        _expenseVM = StateObject(wrappedValue: FinanceDashboardViewModel(
            mode: .expense,
            transactionRepo: dependencies.transactionRepo,
            currencyService: dependencies.currencyService
        ))
        _incomeVM = StateObject(wrappedValue: FinanceDashboardViewModel(
            mode: .income,
            transactionRepo: dependencies.transactionRepo,
            currencyService: dependencies.currencyService
        ))
        _analyticsVM = StateObject(wrappedValue: AnalyticsViewModel(
            transactionRepo: dependencies.transactionRepo,
            currencyService: dependencies.currencyService
        ))
        _goalsVM = StateObject(wrappedValue: GoalsViewModel(
            repo: dependencies.goalRepo
        ))
    }

    var body: some View {
        VStack(spacing: 0) {
            Group {
                switch selectedTab {
                case .income:
                    FinanceDashboardView(
                        viewModel: incomeVM,
                        isOverlayPresented: $isAnyOverlayPresented,
                        isBottomGreenFillPresented: $isBottomGreenFillPresented
                    )
                case .expense:
                    FinanceDashboardView(
                        viewModel: expenseVM,
                        isOverlayPresented: $isAnyOverlayPresented,
                        isBottomGreenFillPresented: $isBottomGreenFillPresented
                    )
                case .analytics:
                    AnalyticsView(
                        viewModel: analyticsVM,
                        isOverlayPresented: $isAnyOverlayPresented
                    )
                case .goals:
                    GoalsView(
                        viewModel: goalsVM,
                        isOverlayPresented: $isAnyOverlayPresented,
                        isBottomGreenFillPresented: $isBottomGreenFillPresented
                    )
                }
            }

            if !isBottomGreenFillPresented {
                BottomMenuBar(selectedTab: $selectedTab)
                    .overlay {
                        if isAnyOverlayPresented {
                            Color.black.opacity(0.2).ignoresSafeArea(edges: .bottom)
                        }
                    }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.22), value: isBottomGreenFillPresented)
        .onChange(of: selectedTab) { _ in
            isAnyOverlayPresented = false
            isBottomGreenFillPresented = false
        }
    }
}

// MARK: - Tab enum

enum BottomMenuItem {
    case income, expense, analytics, goals
}

#Preview {
    ContentView(dependencies: .preview)
}
