import SwiftUI

struct SettingsButton: View {
    
    var action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Image(systemName: "gearshape")
                .font(.system(size: 26, weight: .regular))
                .foregroundStyle(Color(.green))
        }
        .padding(.horizontal)
    }
}

struct AppSettingsView: View {
    var onBack: () -> Void

    @State private var selectedCurrency = AppSettingsCurrency.loadBaseCurrencyCode()
    @State private var currencyDraft = AppSettingsCurrency.loadBaseCurrencyCode()
    @State private var isCurrencyPickerPresented = false

    var body: some View {
        ZStack {
            Color(.beige).ignoresSafeArea()

            VStack(spacing: 0) {
                HStack {
                    Button {
                        onBack()
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 24, weight: .medium))
                            Text(L10n.back)
                                .font(.playfairDisplay(24, weight: .semibold))
                        }
                        .foregroundStyle(Color(.green))
                    }
                    .buttonStyle(.plain)

                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.top, 4)

                HStack {
                    Text(L10n.settings)
                        .font(.playfairDisplay(40, weight: .semibold))
                        .foregroundStyle(Color(.green))
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.top, 4)

                VStack(spacing: 18) {
                    settingsRow(
                        title: L10n.currency,
                        subtitle: AppCurrency.displayName(for: selectedCurrency),
                        action: {
                            currencyDraft = selectedCurrency
                            withAnimation(.easeInOut(duration: 0.22)) {
                                isCurrencyPickerPresented = true
                            }
                        }
                    )

                    settingsRow(title: L10n.share,      subtitle: nil, action: nil)
                    settingsRow(title: L10n.rateApp,    subtitle: nil, action: nil)
                    settingsRow(title: L10n.buyPremium, subtitle: nil, action: nil)
                }
                .padding(.horizontal, 20)
                .padding(.top, 26)

                Spacer()
            }

            if isCurrencyPickerPresented {
                Color.black.opacity(0.2)
                    .ignoresSafeArea()
                    .onTapGesture { closeCurrencyPicker() }

                VStack(spacing: 12) {
                    Picker(L10n.currency, selection: $currencyDraft) {
                        ForEach(AppCurrency.mainCurrencies) { currency in
                            Text("\(currency.displayName) (\(currency.rawValue))").tag(currency.rawValue)
                        }
                    }
                    .pickerStyle(.wheel)
                    .labelsHidden()
                    .frame(height: 180)

                    HStack(spacing: 12) {
                        Button(L10n.cancel) { closeCurrencyPicker() }
                            .font(.playfairDisplay(20, weight: .semibold))
                            .foregroundStyle(.black)
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(Color(.systemGray5))
                            .clipShape(RoundedRectangle(cornerRadius: 10))

                        Button(L10n.ok) {
                            selectedCurrency = currencyDraft
                            AppSettingsCurrency.saveBaseCurrencyCode(selectedCurrency)
                            closeCurrencyPicker()
                        }
                        .font(.playfairDisplay(20, weight: .semibold))
                        .foregroundStyle(Color(.green))
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                }
                .padding(16)
                .background(.white)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .padding(.horizontal, 20)
            }
        }
    }

    @ViewBuilder
    private func settingsRow(title: String, subtitle: String?, action: (() -> Void)?) -> some View {
        Button {
            action?()
        } label: {
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.playfairDisplay(22))
                        .foregroundStyle(.black)
                        .lineLimit(2)
                    if let subtitle {
                        Text(subtitle)
                            .font(.playfairDisplay(16))
                            .foregroundStyle(.black)
                    }
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(Color(.green))
            }
            .contentShape(Rectangle())
            .padding(.vertical, 6)
        }
        .buttonStyle(.plain)
    }

    private func closeCurrencyPicker() {
        withAnimation(.easeInOut(duration: 0.22)) {
            isCurrencyPickerPresented = false
        }
    }

}
