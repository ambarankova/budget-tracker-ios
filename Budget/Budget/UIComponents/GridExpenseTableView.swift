import SwiftUI

struct TotalTableView: View {
    let categories: [CategorySummary]
    let totalPlan: Int
    let totalFact: Int
    let isRedWhenFactLessThanPlan: Bool
    var onPlanTap: (String) -> Void
    var onCategoryTap: (String) -> Void
    var onDeleteCategory: ((String) -> Void)?

    var body: some View {
        VStack(spacing: 0) {
            tableHeader
                .padding(.horizontal, AppLayout.screenHorizontalPadding)
                .padding(.vertical, 8)

            Divider().overlay(Color(.gray).opacity(0.3))

            List {
                ForEach(categories) { category in
                    VStack(spacing: 0) {
                        row(name: category.name, plan: category.plan, fact: category.fact, isTotal: false)
                            .padding(.vertical, 8)
                        Divider().overlay(Color(.gray).opacity(0.3))
                    }
                    .padding(.horizontal, AppLayout.screenHorizontalPadding)
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color(.beige))
                    .listRowSeparator(.hidden)
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button(role: .destructive) {
                            onDeleteCategory?(category.name)
                        } label: {
                            Text(L10n.delete)
                        }
                    }
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .environment(\.defaultMinListRowHeight, 44)
            .frame(maxHeight: .infinity)

            Divider().overlay(Color(.gray).opacity(0.3))

            row(name: L10n.total, plan: totalPlan, fact: totalFact, isTotal: true)
                .padding(.horizontal, AppLayout.screenHorizontalPadding)
                .padding(.vertical, 8)
                .padding(.bottom, 10)
        }
    }

    private var tableHeader: some View {
        HStack(spacing: 12) {
            Text(L10n.category).font(.playfairDisplay(20)).frame(maxWidth: .infinity, alignment: .leading)
            Text(L10n.plan)    .font(.playfairDisplay(20)).frame(width: 110, alignment: .leading)
            Text(L10n.fact)    .font(.playfairDisplay(20)).frame(width: 110, alignment: .leading)
        }
    }

    @ViewBuilder
    private func row(name: String, plan: Int, fact: Int, isTotal: Bool) -> some View {
        HStack(spacing: 12) {
            Text(name)
                .lineLimit(1).truncationMode(.tail)
                .font(.playfairDisplay(20, weight: isTotal ? .bold : .regular))
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
                .onTapGesture { if !isTotal { onCategoryTap(name) } }

            Text(formatAmount(plan))
                .lineLimit(1)
                .font(.playfairDisplay(20, weight: isTotal ? .bold : .regular))
                .frame(width: 110, alignment: .leading)
                .contentShape(Rectangle())
                .onTapGesture { if !isTotal { onPlanTap(name) } }

            Text(formatAmount(fact))
                .lineLimit(1)
                .font(.playfairDisplay(20, weight: isTotal ? .bold : .regular))
                .foregroundStyle(factColor(plan: plan, fact: fact))
                .frame(width: 110, alignment: .leading)
        }
    }

    private func formatAmount(_ value: Int) -> String {
        let symbol = AppCurrency.symbol(for: AppSettingsCurrency.loadBaseCurrencyCode())
        return AppMoney.formatCentsForDisplay(value, currencySymbol: symbol)
    }

    private func factColor(plan: Int, fact: Int) -> Color {
        if isRedWhenFactLessThanPlan { return fact < plan ? Color(.red) : .primary }
        return fact > plan ? Color(.red) : .primary
    }
}
