import SwiftUI

// MARK: - Donut chart

struct DonutChartView: View {
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
