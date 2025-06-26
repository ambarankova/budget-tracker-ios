
import SwiftUI

struct ExpensesView: View {
    var body: some View {
        VStack {
            HStack {
                Spacer()
                
                Button(action: {
                    // TODO: - Go to settings
                }) {
                    Image(systemName: "gearshape")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 20)
                        .foregroundColor(.mainGreen)
                }
            }
            
            Text ("delta".localized)
                .font(.playfairDisplay(30, weight: .bold))
                .foregroundStyle(Color.mainGreen)
        }
    }
}

#Preview {
    ExpensesView()
}
