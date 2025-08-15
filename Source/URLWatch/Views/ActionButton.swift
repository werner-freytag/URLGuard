import SwiftUI

struct ActionButton: View {
    let icon: String
    let title: LocalizedStringKey
    let color: Color
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.body)
                .foregroundColor(isHovered ? color : nil)
                .opacity(isHovered ? 1 : 0.6)
                .padding(4)
        }
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.2)) {
                isHovered = hovering
            }
        }
        .buttonStyle(.plain)
        .help(title)
    }
}
