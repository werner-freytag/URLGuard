import SwiftUI

struct EmptyStateView: View {
    let icon: String
    let title: String
    let subtitle: String
    let content: AnyView?
    
    init(
        icon: String,
        title: String,
        subtitle: String,
        @ViewBuilder content: () -> some View = { EmptyView() }
    ) {
        self.icon = icon
        self.title = title
        self.subtitle = subtitle
        self.content = AnyView(content())
    }
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: icon)
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            
            VStack(spacing: 8) {
                Text(title)
                    .font(.title2)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                
                Text(subtitle)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            if let content {
                content
            }
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.controlBackgroundColor)
    }
}

#Preview {
    VStack(spacing: 40) {
        EmptyStateView(
            icon: "plus.circle",
            title: "Keine Einträge vorhanden",
            subtitle: "Erstellen Sie Ihren ersten Eintrag, um URLs zu überwachen"
        ) {
            IconButton(
                icon: "plus",
                title: "Neuer Eintrag",
                color: .blue
            ) {
                print("Neuer Eintrag")
            }
        }
        
        EmptyStateView(
            icon: "magnifyingglass",
            title: "Keine Einträge gefunden",
            subtitle: "Für 'test' wurden keine Übereinstimmung gefunden"
        )
    }
    .padding()
} 
