
import SwiftUI

struct ContentView: View {
    @State private var selectedMenuItem: BottomMenuItem = .expense

    var body: some View {
        VStack(spacing: 0) {
            Group {
                switch selectedMenuItem {
                case .income:
                    FinanceDashboardView(mode: .income)
                case .expense:
                    FinanceDashboardView(mode: .expense)
                case .analytics:
                    PlaceholderScreen(title: "Аналитика")
                case .goals:
                    PlaceholderScreen(title: "Цели")
                }
            }

            BottomMenuBar(selectedMenuItem: $selectedMenuItem)
        }
    }
}

private enum BottomMenuItem {
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
        .padding(.top, 10)
        .padding(.bottom, 6)
        .background(.white)
    }

    private func menuItem(item: BottomMenuItem, symbol: String, title: String) -> some View {
        let isSelected = selectedMenuItem == item

        return Button {
            selectedMenuItem = item
        } label: {
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
        .buttonStyle(.plain)
    }
}

private struct PlaceholderScreen: View {
    let title: String

    var body: some View {
        ZStack {
            Color(.beige).ignoresSafeArea()
            Text(title)
                .font(.playfairDisplay(42, weight: .semibold))
                .foregroundStyle(Color(.green))
        }
    }
}

#Preview {
    ContentView()
}
