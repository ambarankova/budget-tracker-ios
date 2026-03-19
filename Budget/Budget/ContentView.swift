import SwiftUI

struct ContentView: View {
    @State private var selectedMenuItem: BottomMenuItem = .expense
    @State private var isAnyOverlayPresented = false
    @State private var isBottomGreenFillPresented = false
    @State private var selectedReportMonth = Calendar.current.component(.month, from: Date())
    @State private var selectedReportYear = Calendar.current.component(.year, from: Date())

    var body: some View {
        VStack(spacing: 0) {
            Group {
                switch selectedMenuItem {
                case .income:
                    FinanceDashboardView(
                        mode: .income,
                        isOverlayPresented: $isAnyOverlayPresented,
                        isBottomGreenFillPresented: $isBottomGreenFillPresented,
                        selectedReportMonth: $selectedReportMonth,
                        selectedReportYear: $selectedReportYear
                    )
                case .expense:
                    FinanceDashboardView(
                        mode: .expense,
                        isOverlayPresented: $isAnyOverlayPresented,
                        isBottomGreenFillPresented: $isBottomGreenFillPresented,
                        selectedReportMonth: $selectedReportMonth,
                        selectedReportYear: $selectedReportYear
                    )
                case .analytics:
                    AnalyticsView(isOverlayPresented: $isAnyOverlayPresented)
                case .goals:
                    GoalsView(
                        isOverlayPresented: $isAnyOverlayPresented,
                        isBottomGreenFillPresented: $isBottomGreenFillPresented
                    )
                }
            }

            if !isBottomGreenFillPresented {
                BottomMenuBar(selectedMenuItem: $selectedMenuItem)
                    .overlay {
                        if isAnyOverlayPresented {
                            Color.black.opacity(0.2)
                                .ignoresSafeArea(edges: .bottom)
                        }
                    }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.22), value: isBottomGreenFillPresented)
        .onChange(of: selectedMenuItem) { _ in
            isAnyOverlayPresented = false
            isBottomGreenFillPresented = false
        }
    }
}

enum BottomMenuItem {
    case income
    case expense
    case analytics
    case goals
}

private struct BottomMenuBar: View {
    @Binding var selectedMenuItem: BottomMenuItem

    var body: some View {
        HStack(spacing: 6) {
            menuItem(item: .income, symbol: "arrow.up", title: "Доход")
            menuItem(item: .expense, symbol: "creditcard", title: "Расход")
            menuItem(item: .analytics, symbol: "chart.bar.fill", title: "Аналитика")
            menuItem(item: .goals, symbol: "checkmark.rectangle.stack", title: "Цели")
        }
        .padding(.top, 8)
        .padding(.bottom, 6)
        .background(Color(.beige))
    }

    private func menuItem(item: BottomMenuItem, symbol: String, title: String) -> some View {
        let isSelected = selectedMenuItem == item

        return Button {
            selectedMenuItem = item
        } label: {
            VStack(spacing: 6) {
                Image(systemName: symbol)
                    .font(.system(size: 21))
                    .foregroundStyle(isSelected ? Color(.green) : Color(.gray))

                Text(title)
                    .font(.playfairDisplay(13))
                    .foregroundStyle(isSelected ? .black : Color(.gray))
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
