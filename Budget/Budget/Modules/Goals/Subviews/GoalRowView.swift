import SwiftUI

// MARK: - Goal row

struct GoalRowView: View {
    let goal: Goal
    var onHistoryTap: () -> Void
    var onReplenishTap: () -> Void

    private var progress: Double {
        guard goal.targetAmount > 0 else { return 0 }
        return min(Double(goal.savedAmount) / Double(goal.targetAmount), 1)
    }
    private var percentage: Int { Int((progress * 100).rounded()) }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(goal.title)
                .font(.playfairDisplay(22, weight: .semibold))
                .foregroundStyle(.black)

            Text("\(format(goal.savedAmount)) из \(format(goal.targetAmount)) скоплено")
                .font(.playfairDisplay(12))
                .foregroundStyle(.black)

            GeometryReader { proxy in
                let full = proxy.size.width
                let filled = full * progress
                ZStack(alignment: .leading) {
                    Rectangle().fill(Color(.gray).opacity(0.5)).frame(height: 32)
                    Rectangle().fill(Color(.green)).frame(width: filled, height: 32)
                    if progress > 0.18 {
                        Text("\(percentage) %").font(.playfairDisplay(18)).foregroundStyle(.white).padding(.leading, 18)
                    } else {
                        HStack {
                            Spacer()
                            Text("\(percentage) %").font(.playfairDisplay(18)).foregroundStyle(.black).padding(.trailing, 14)
                        }
                    }
                }
            }
            .frame(height: 32)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(goal.title)
            .accessibilityValue("\(percentage)%")

            HStack(spacing: 12) {
                Button(L10n.history) { onHistoryTap() }
                    .font(.playfairDisplay(20)).foregroundStyle(.black)
                    .frame(maxWidth: .infinity).frame(height: 56)
                    .background(Color(.beige))
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color(.green).opacity(0.5), lineWidth: 1))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .accessibilityLabel("\(L10n.history): \(goal.title)")

                Button(L10n.replenish) { onReplenishTap() }
                    .font(.playfairDisplay(20)).foregroundStyle(.white)
                    .frame(maxWidth: .infinity).frame(height: 56)
                    .background(Color(.green))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .accessibilityLabel("\(L10n.replenish): \(goal.title)")
            }
            .padding(.top, 2)
        }
        .padding(.vertical, 8)
    }

    private static let amountFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.groupingSeparator = " "
        f.maximumFractionDigits = 0
        return f
    }()

    private func format(_ value: Int) -> String {
        Self.amountFormatter.string(from: NSNumber(value: value)) ?? "\(value)"
    }
}
