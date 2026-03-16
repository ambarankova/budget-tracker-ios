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
