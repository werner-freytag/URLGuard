import SwiftUI

struct URLItemActionButtons: View {
    let item: URLItem
    let monitor: URLMonitor
    let onEdit: () -> Void
    
    var body: some View {
        HStack(spacing: 2) {
            // Bearbeiten-Button
            Button(action: onEdit) {
                Image(systemName: "pencil")
                    .font(.title3)
                    .foregroundColor(.black)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
            }
            .buttonStyle(.plain)
            .help("Bearbeiten")
            
            // Trennlinie
            Rectangle()
                .fill(Color.gray.opacity(0.3))
                .frame(width: 1, height: 20)
            
            // Duplizieren-Button
            Button(action: {
                guard monitor.items.contains(where: { $0.id == item.id }) else { return }
                monitor.duplicate(item: item)
            }) {
                Image(systemName: "plus.square.on.square")
                    .font(.title3)
                    .foregroundColor(.black)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
            }
            .buttonStyle(.plain)
            .help("Duplizieren")
            
            // Trennlinie
            Rectangle()
                .fill(Color.gray.opacity(0.3))
                .frame(width: 1, height: 20)
            
            // Löschen-Button
            Button(action: {
                guard monitor.items.contains(where: { $0.id == item.id }) else { return }
                monitor.remove(item: item)
            }) {
                Image(systemName: "trash")
                    .font(.title3)
                    .foregroundColor(.red)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
            }
            .buttonStyle(.plain)
            .help("Löschen")
        }
        .cornerRadius(6)
    }
}

#Preview {
    let monitor = URLMonitor()
    let item = URLItem(url: URL(string: "https://example.com")!, interval: 10, isEnabled: true)
    return URLItemActionButtons(item: item, monitor: monitor, onEdit: {})
        .padding()
} 
