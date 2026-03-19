import SwiftUI

struct TotalTableView: View {
    let categories: [ExpenseCategory]
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

            Divider()
                .overlay(Color(.gray).opacity(0.3))

            List {
                ForEach(categories) { category in
                    VStack(spacing: 0) {
                        row(
                            title: category.category,
                            plan: category.plan,
                            fact: category.fact,
                            isTotal: false
                        )
                        .padding(.vertical, 8)
                        Divider()
                            .overlay(Color(.gray).opacity(0.3))
                    }
                    .padding(.horizontal, AppLayout.screenHorizontalPadding)
                    .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                    .listRowBackground(Color(.beige))
                    .listRowSeparator(.hidden)
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button(role: .destructive) {
                            onDeleteCategory?(category.category)
                        } label: {
                            Text("Удалить")
                        }
                    }
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .environment(\.defaultMinListRowHeight, 44)
            .frame(maxHeight: .infinity)

            Divider()
                .overlay(Color(.gray).opacity(0.3))

            row(title: "Итого", plan: totalPlan, fact: totalFact, isTotal: true)
                .padding(.horizontal, AppLayout.screenHorizontalPadding)
                .padding(.vertical, 8)
                .padding(.bottom, 10)
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
                .contentShape(Rectangle())
                .onTapGesture {
                    if !isTotal {
                        onCategoryTap(title)
                    }
                }

            Text(formatAmount(plan))
                .lineLimit(1)
                .font(.playfairDisplay(20, weight: isTotal ? .bold : .regular))
                .frame(width: 110, alignment: .leading)
                .contentShape(Rectangle())
                .onTapGesture {
                    if !isTotal {
                        onPlanTap(title)
                    }
                }

            Text(formatAmount(fact))
                .lineLimit(1)
                .font(.playfairDisplay(20, weight: isTotal ? .bold : .regular))
                .foregroundStyle(factColor(plan: plan, fact: fact))
                .frame(width: 110, alignment: .leading)
        }
    }

    func formatAmount(_ value: Int) -> String {
        let symbol = AppCurrency.symbol(for: AppSettingsCurrency.loadBaseCurrencyCode())
        return AppMoney.formatCentsForDisplay(value, currencySymbol: symbol)
    }

    func factColor(plan: Int, fact: Int) -> Color {
        if isRedWhenFactLessThanPlan {
            return fact < plan ? Color(.red) : .primary
        }
        return fact > plan ? Color(.red) : .primary
    }
}
