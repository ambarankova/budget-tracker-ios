import SwiftUI

struct ExpensesView: View {
    var delta: String {
        let number = 1
        let sign = number >= 0 ? "+" : "-"
        return sign + String(abs(number))
    }
    
    var body: some View {
        VStack {
            HStack {
                Spacer()
                
                SettingsButton {
                    print("Go to settings")
                    // TODO: - Go to settings
                }
            }
            
            HStack {
                Text(L10n.delta)
                    .font(.playfairDisplay(36, weight: .bold))
                    .foregroundStyle(Color(.green))
                
                Text(String(delta))
                    .font(.playfairDisplay(36, weight: .bold))
                    .foregroundStyle(Color(.green))
                
                Spacer()
            }
            .padding(.horizontal)
            
            HStack {
                Text(L10n.expense)
                    .font(.playfairDisplay(30, weight: .semibold))
                    .foregroundStyle(Color(.green))
                
                Spacer()
            }
            .padding(.horizontal)
            
            Spacer()
        }
        .background(Color(.beige))
    }
}

#Preview {
    ExpensesView()
}
