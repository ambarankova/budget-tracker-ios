import SwiftUI

// MARK: - Chart view

struct AnalyticsChartView: View {
    @ObservedObject var viewModel: AnalyticsViewModel
    let initialMode: ChartMode
    var onDismiss: () -> Void

    @State private var chartMode: ChartMode
    @State private var selectedDeltaMonth: Int?
    @State private var isSettingsPresented = false

    init(viewModel: AnalyticsViewModel, initialMode: ChartMode, onDismiss: @escaping () -> Void) {
        self.viewModel = viewModel
        self.initialMode = initialMode
        self.onDismiss = onDismiss
        _chartMode = State(initialValue: initialMode)
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            Color(.beige)

            VStack(spacing: 0) {
                HStack {
                    Button {
                        onDismiss()
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "chevron.left").font(.system(size: 24, weight: .medium))
                            Text(L10n.back).font(.playfairDisplay(24, weight: .semibold))
                        }
                        .foregroundStyle(Color(.green))
                    }
                    .buttonStyle(.plain)
                    Spacer()
                    SettingsButton { isSettingsPresented = true }
                }
                .padding(.horizontal, 20)
                .padding(.top, 4)

                HStack {
                    Text(chartMode == .bar ? L10n.delta : viewModel.displayMode.screenTitle)
                        .font(.playfairDisplay(40, weight: .semibold))
                        .foregroundStyle(Color(.green))
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)

                if chartMode == .pie {
                    Spacer(minLength: 98)
                    DonutChartView(values: viewModel.chartValues, currencySymbol: viewModel.baseCurrencySymbol)
                        .frame(height: 198)
                        .padding(.horizontal, 42)
                        .padding(.top, 18)

                    ScrollView(.vertical, showsIndicators: true) {
                        VStack(alignment: .leading, spacing: 10) {
                            ForEach(viewModel.chartValues) { value in
                                HStack(spacing: 12) {
                                    RoundedRectangle(cornerRadius: 7)
                                        .fill(value.color)
                                        .frame(width: 28, height: 28)
                                    Text("\(value.category) (\(percent(for: value.amount))%)")
                                        .font(.playfairDisplay(18))
                                        .foregroundStyle(.black)
                                    Spacer()
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                    }
                    .padding(.top, 72)
                    .frame(maxHeight: .infinity)
                } else {
                    DeltaBarsChartView(
                        points: viewModel.deltaByMonth,
                        selectedMonth: $selectedDeltaMonth,
                        currencySymbol: viewModel.baseCurrencySymbol
                    )
                    .frame(maxWidth: .infinity)
                    .frame(maxHeight: .infinity)
                }

                HStack(spacing: 26) {
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) { chartMode = .pie; selectedDeltaMonth = nil }
                    } label: {
                        Image(systemName: "chart.pie.fill")
                            .font(.system(size: 36))
                            .foregroundStyle(chartMode == .pie ? Color(.green) : Color(.gray))
                    }
                    .buttonStyle(.plain)

                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) { chartMode = .bar }
                    } label: {
                        Image(systemName: "chart.bar")
                            .font(.system(size: 36))
                            .foregroundStyle(chartMode == .bar ? Color(.green) : Color(.gray))
                    }
                    .buttonStyle(.plain)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 86)
            }
        }
        .onAppear { chartMode = initialMode; selectedDeltaMonth = nil }
        .onChange(of: isSettingsPresented) { isPresented in
            guard !isPresented else { return }
            viewModel.onSettingsDismissed()
        }
        .fullScreenCover(isPresented: $isSettingsPresented) {
            AppSettingsView(onBack: { isSettingsPresented = false })
        }
    }

    private func percent(for amount: Int) -> Int {
        let total = max(viewModel.chartValues.reduce(0) { $0 + $1.amount }, 1)
        return Int((Double(amount) / Double(total) * 100).rounded())
    }
}

// MARK: - Chart mode

enum ChartMode: String, Identifiable {
    case pie, bar
    var id: String { rawValue }
}

