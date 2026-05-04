import SwiftUI

// MARK: - Shared overlay modifiers

extension View {
    func overlayCard() -> some View {
        self
            .padding(16)
            .background(.white)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .padding(.horizontal, 20)
    }
}

// MARK: - Overlay button style

enum OverlayButtonStyle { case cancel, confirm }

extension Button {
    @ViewBuilder
    func overlayButton(style: OverlayButtonStyle) -> some View {
        self
            .font(.playfairDisplay(20, weight: .semibold))
            .foregroundStyle(style == .cancel ? .black : Color(.green))
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(style == .cancel ? Color(.systemGray5) : .white)
            .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}
