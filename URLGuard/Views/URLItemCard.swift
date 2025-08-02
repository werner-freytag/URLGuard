import SwiftUI

struct URLItemCard: View {
    let item: URLItem
    let monitor: URLMonitor
    let onEdit: () -> Void
    
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
            RoundedRectangle(cornerRadius: 12)
                .fill(item.isEnabled ? Color.white : Color.gray.opacity(0.05))
                .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
        )
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .opacity(monitor.isGlobalPaused ? 0.5 : 1.0)
    }
}

#Preview {
    let monitor = URLMonitor()
            let item = URLItem(url: URL(string: "https://example.com")!, interval: 10, isEnabled: true)
    return URLItemCard(item: item, monitor: monitor, onEdit: {})
        .frame(width: 600)
} 
