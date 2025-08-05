import SwiftUI

struct URLItemCard: View {
    let item: URLItem
    let monitor: URLMonitor
    let onEdit: () -> Void
    
    @State private var isHovered = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            URLItemHeader(item: item, monitor: monitor, onEdit: onEdit)
            
            Rectangle()
                .fill(Color.secondary.opacity(0.2))
                .frame(height: 1)

            URLItemHistory(item: item, monitor: monitor)
        }
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(item.isEnabled ? Color.white : Color.gray.opacity(0.05))
                .shadow(color: .black.opacity(0.08), radius: 4, x: 0, y: 3)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(
                    item.isEnabled ? Color.blue.opacity(0.1) : Color.gray.opacity(0.2), 
                    lineWidth: 1
                )
        )
        .overlay(
            // Highlighting Overlay
            RoundedRectangle(cornerRadius: 16)
                .stroke(
                    monitor.highlightedItemID == item.id ? Color.orange : Color.clear,
                    lineWidth: 3
                )
                .animation(.easeInOut(duration: 0.3), value: monitor.highlightedItemID)
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
