import SwiftUI

struct ContentView: View {

    // ViewModels live here so they survive tab switches.
    @StateObject private var expenseVM = FinanceDashboardViewModel(mode: .expense)
    @StateObject private var incomeVM  = FinanceDashboardViewModel(mode: .income)
    @StateObject private var analyticsVM = AnalyticsViewModel()
    @StateObject private var goalsVM   = GoalsViewModel()

    @State private var selectedTab: BottomMenuItem = .expense
    @State private var isAnyOverlayPresented = false
    @State private var isBottomGreenFillPresented = false

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

// MARK: - Bottom bar

private struct BottomMenuBar: View {
    @Binding var selectedTab: BottomMenuItem

    var body: some View {
        HStack(spacing: 6) {
            tab(.income,    symbol: "arrow.up",                    title: "Доход")
            tab(.expense,   symbol: "creditcard",                  title: "Расход")
            tab(.analytics, symbol: "chart.bar.fill",              title: "Аналитика")
            tab(.goals,     symbol: "checkmark.rectangle.stack",   title: "Цели")
        }
        .padding(.top, 8)
        .padding(.bottom, 6)
        .background(Color(.beige))
    }

    private func tab(_ item: BottomMenuItem, symbol: String, title: String) -> some View {
        let selected = selectedTab == item
        return Button { selectedTab = item } label: {
            VStack(spacing: 6) {
                Image(systemName: symbol)
                    .font(.system(size: 21))
                    .foregroundStyle(selected ? Color(.green) : Color(.gray))
                Text(title)
                    .font(.playfairDisplay(13))
                    .foregroundStyle(selected ? .black : Color(.gray))
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    ContentView()
}
