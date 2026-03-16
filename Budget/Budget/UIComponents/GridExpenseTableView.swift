import SwiftUI

struct TotalTableView: View {
    let categories: [ExpenseCategory]
    let totalPlan: Int
    let totalFact: Int

    var body: some View {
        VStack(spacing: 0) {
            tableHeader
                .padding(.horizontal, 20)
                .padding(.vertical, 8)

            Divider()
                .overlay(Color(.gray).opacity(0.3))

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    ForEach(categories) { category in
                        row(
                            title: category.category,
                            plan: category.plan,
                            fact: category.fact,
                            isTotal: false
                        )
                        .padding(.horizontal, 20)
                        .padding(.vertical, 8)

                        Divider()
                            .overlay(Color(.gray).opacity(0.3))
                    }
                }
            }

            Spacer(minLength: 10)

            row(title: "Итого", plan: totalPlan, fact: totalFact, isTotal: true)
                .padding(.horizontal, 20)
                .padding(.vertical, 8)
        }
    }
}

private extension TotalTableView {
    var tableHeader: some View {
        HStack(spacing: 12) {
            Text("Категория")
                .font(.playfairDisplay(20))
                .frame(maxWidth: .infinity, alignment: .leading)

            Text("План")
                .font(.playfairDisplay(20))
                .frame(width: 110, alignment: .leading)

            Text("Факт")
                .font(.playfairDisplay(20))
                .frame(width: 110, alignment: .leading)
        }
    }

    @ViewBuilder
    func row(title: String, plan: Int, fact: Int, isTotal: Bool) -> some View {
        HStack(spacing: 12) {
            Text(title)
                .lineLimit(1)
                .truncationMode(.tail)
                .font(.playfairDisplay(20, weight: isTotal ? .bold : .regular))
                .frame(maxWidth: .infinity, alignment: .leading)

            Text(formatAmount(plan))
                .lineLimit(1)
                .font(.playfairDisplay(20, weight: isTotal ? .bold : .regular))
                .frame(width: 110, alignment: .leading)

            Text(formatAmount(fact))
                .lineLimit(1)
                .font(.playfairDisplay(20, weight: isTotal ? .bold : .regular))
                .foregroundStyle(fact > plan ? Color(.red) : .primary)
                .frame(width: 110, alignment: .leading)
        }
    }

    func formatAmount(_ value: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = " "
        formatter.maximumFractionDigits = 0

        let number = NSNumber(value: value)
        return (formatter.string(from: number) ?? "\(value)") + " ₽"
    }
}
