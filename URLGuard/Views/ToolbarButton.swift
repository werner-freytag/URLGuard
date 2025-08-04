import SwiftUI

struct ToolbarButton: View {
    let icon: String
    let title: String
    let color: Color
    let action: () -> Void
    
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
            HStack(spacing: 6) {
                Image(systemName: icon)
                Text(title)
                    .frame(minWidth: 60)
            }
            .foregroundColor(color)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(color.opacity(0.1))
                    .stroke(color.opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    VStack(spacing: 16) {
        ToolbarButton(
            icon: "play.circle.fill",
            title: "Starten",
            color: .green
        ) {
            print("Starten")
        }
        
        ToolbarButton(
            icon: "pause.circle.fill",
            title: "Pausieren",
            color: .orange
        ) {
            print("Pausieren")
        }
        
        ToolbarButton(
            icon: "plus.circle.fill",
            title: "Neuer Eintrag",
            color: .blue
        ) {
            print("Neuer Eintrag")
        }
    }
    .padding()
} 