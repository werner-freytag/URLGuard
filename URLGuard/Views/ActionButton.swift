import SwiftUI

struct ActionButton: View {
    let icon: String
    let title: String
    let color: Color
    let action: () -> Void
    
    @State private var isHovered = false

    init(
        icon: String,
        title: String,
        color: Color,
        action: @escaping () -> Void
    ) {
        self.icon = icon
        self.title = title
        self.color = color
        self.action = action
    }
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.caption)
                if isHovered {
                    Text(title)
                        .font(.caption)
                        .fontWeight(.medium)
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .opacity(isHovered ? 1.0 : 0.0)
                }
            }
            .foregroundColor(color)
            .padding(.horizontal, isHovered ? 10 : 6)
            .padding(.vertical, 6)
            .opacity(isHovered ? 1.0 : 0.85)
            .frame(width: isHovered ? .infinity : 28, height: 28)
            .animation(.easeInOut(duration: 0.15), value: isHovered)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(color.opacity(0.1))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(color.opacity(0.3), lineWidth: 1)
                    )
            )
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

#Preview {
    VStack(spacing: 16) {
        ActionButton(
            icon: "pencil",
            title: "Bearbeiten",
            color: .blue
        ) {
            print("Bearbeiten")
        }
        
        ActionButton(
            icon: "plus.square.on.square",
            title: "Duplizieren",
            color: .green
        ) {
            print("Duplizieren")
        }
        
        ActionButton(
            icon: "trash",
            title: "Löschen",
            color: .red
        ) {
            print("Löschen")
        }
        
        // Ohne Titel
        ActionButton(
            icon: "pencil",
            title: "Bearbeiten",
            color: .blue,
        ) {
            print("Bearbeiten")
        }
    }
    .padding()
} 
