import SwiftUI

struct URLItemCard: View {
    let item: URLItem
    let monitor: URLMonitor
    let onEdit: () -> Void
    
    @State private var isHovered = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header immer anzeigen
            URLItemHeader(item: item, monitor: monitor, onEdit: onEdit)
            
            // Historie immer anzeigen
            // Trennlinie zwischen Header und Historie
            Rectangle()
                .fill(Color.secondary.opacity(0.2))
                .frame(height: 1)

            URLItemHistory(item: item, monitor: monitor)
        }
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(item.isEnabled ? Color.white : Color.gray.opacity(0.05))
                .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 4)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(
                    item.isEnabled ? Color.blue.opacity(0.1) : Color.gray.opacity(0.2), 
                    lineWidth: 1
                )
        )
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .opacity(monitor.isGlobalPaused ? 0.5 : 1.0)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.2)) {
                isHovered = hovering
            }
        }
    }
}

#Preview {
    let monitor = URLMonitor()
            let item = URLItem(url: URL(string: "https://example.com")!, interval: 10, isEnabled: true)
    return URLItemCard(item: item, monitor: monitor, onEdit: {})
        .frame(width: 600)
} 
