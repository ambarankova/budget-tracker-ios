import SwiftUI

struct TotalTableView: View {
    
    @State private var totalPlan = 0
    @State private var totalFact = 0
    
    let expensesCategory: [ExpenseCategory] = [
        .init(category: "Еда", plan: 40000, fact: 27458),
        .init(category: "Красота", plan: 5500, fact: 2100),
        .init(category: "Путешествия", plan: 0, fact: 22700)
    ]

    var body: some View {
        Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 8) {
            GridRow {
                Text(L10n.category)
                    .font(.playfairDisplay(20))
                Text(L10n.plan)
                    .font(.playfairDisplay(20))
                Text(L10n.fact)
                    .font(.playfairDisplay(20))
            }
            Divider().gridCellColumns(3)

            ForEach(expensesCategory) { category in
                GridRow {
                    Text(category.category)
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .font(.playfairDisplay(20))
                    Text(String(category.plan))
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .font(.playfairDisplay(20))
                    Text(String(category.fact))
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .font(.playfairDisplay(20))
                        .foregroundColor(category.fact > category.plan ? .red : .primary)
                }
                Divider().gridCellColumns(3)
            }

            GridRow {
                Text(L10n.total)
                    .font(.playfairDisplay(20, weight: .bold))
                Text(String(totalPlan))
                    .font(.playfairDisplay(20, weight: .bold))
                Text(String(totalFact))
                    .font(.playfairDisplay(20, weight: .bold))
                    .foregroundColor(totalFact > totalPlan ? .red : .primary)
            }
        }
        .padding()
        .font(.system(size: 16))
        .onAppear {
            for category in expensesCategory {
                totalFact += category.fact
                totalPlan += category.plan
            }
        }
    }
}
