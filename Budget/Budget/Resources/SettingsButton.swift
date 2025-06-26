import SwiftUI

struct SettingsButton: View {
    
    var action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Image(systemName: "gearshape")
                .resizable()
                .scaledToFit()
                .fontWeight(.bold)
                .frame(width: 24)
                .foregroundColor(Color(.green))
        }
        .padding(.horizontal)
    }
}
