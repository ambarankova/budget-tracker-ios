import SwiftUI

struct IncomeView: View {
    @State private var selectedReportMonth = Calendar.current.component(.month, from: Date())
    @State private var selectedReportYear = Calendar.current.component(.year, from: Date())

    var body: some View {
        FinanceDashboardView(
            mode: .income,
            selectedReportMonth: $selectedReportMonth,
            selectedReportYear: $selectedReportYear
        )
    }
}

#Preview {
    IncomeView()
}
