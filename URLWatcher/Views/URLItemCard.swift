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
                .fill(Color.clear)
                .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
        )
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }
}

#Preview {
    let monitor = URLMonitor()
    let item = URLItem(urlString: "https://example.com", interval: 10, isPaused: false)
    return URLItemCard(item: item, monitor: monitor, onEdit: {})
        .frame(width: 600)
} 
