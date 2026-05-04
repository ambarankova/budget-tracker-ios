import SwiftUI

struct BottomMenuBar: View {
    @Binding var selectedTab: BottomMenuItem

    var body: some View {
        HStack(spacing: 6) {
            tab(.income,    symbol: "arrow.up",                    title: L10n.income)
            tab(.expense,   symbol: "creditcard",                  title: L10n.expense)
            tab(.analytics, symbol: "chart.bar.fill",              title: L10n.analytics)
            tab(.goals,     symbol: "checkmark.rectangle.stack",   title: L10n.goals)
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
        .accessibilityLabel(title)
        .accessibilityAddTraits(selected ? [.isButton, .isSelected] : .isButton)
    }
}
