import SwiftUI

// MARK: - Delta bars chart

struct DeltaBarsChartView: View {
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
