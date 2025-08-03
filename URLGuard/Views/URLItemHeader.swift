import SwiftUI

struct URLItemHeader: View {
    let item: URLItem
    let monitor: URLMonitor
    let onEdit: () -> Void
    
    var body: some View {
        HStack {
            Button(action: {
                guard monitor.items.contains(where: { $0.id == item.id }) else { return }
                monitor.togglePause(for: item)
            }) {
                Image(systemName: item.isEnabled ? "pause.circle.fill" : "play.circle.fill")
                    .font(.title)
                    .foregroundColor(.blue)
            }
            .buttonStyle(PlainButtonStyle())
            .help(item.isEnabled ? "Pause" : "Start")
            
            VStack(alignment: .leading, spacing: 4) {
                // Haupttitel
                if let title = item.title, !title.isEmpty {
                    // Benutzerdefinierter Titel
                    Text(title)
                        .font(.headline)
                        .fontWeight(.bold)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .foregroundColor(item.isEnabled ? .primary : .secondary)
                } else if let host = item.url.host {
                    // URL-Komponenten anzeigen
                    HStack(spacing: 4) {
                        Text(host)
                            .font(.headline)
                            .fontWeight(.bold)
                            .foregroundColor(item.isEnabled ? .primary : .secondary)
                        
                        if !item.url.lastPathComponent.isEmpty {
                            Text(" – ")
                                .font(.headline)
                                .fontWeight(.regular)
                                .foregroundColor(item.isEnabled ? .primary.opacity(0.6) : .secondary.opacity(0.6))
                            
                            Text(item.url.lastPathComponent)
                                .font(.headline)
                                .fontWeight(.regular)
                                .foregroundColor(item.isEnabled ? .primary.opacity(0.6) : .secondary.opacity(0.6))
                        }
                    }
                    .lineLimit(1)
                    .truncationMode(.middle)
                } else {
                    // Fallback
                    Text(item.url.absoluteString)
                        .font(.headline)
                        .fontWeight(.bold)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .foregroundColor(item.isEnabled ? .primary : .secondary)
                }
                
                // URL und Intervall als Untertitel
                HStack(spacing: 4) {
                    if item.title != nil {
                        Text(item.url.absoluteString)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    } else {
                        Text(item.url.absoluteString)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                    
                    HStack(spacing: 2) {
                        Image(systemName: "clock")
                        Text("\(Int(item.interval))s")
                    }
                    
                    if !notificationTypesText.isEmpty {
                        HStack(spacing: 2) {
                            Image(systemName: "bell")
                            Text(notificationTypesText)
                        }
                    }
                }
                .font(.caption)
                .foregroundColor(.secondary)
            }
            .onTapGesture(count: 2) {
                // Doppelklick zum Bearbeiten
                onEdit()
            }
            
            Spacer()
            
            
            URLItemActionButtons(item: item, monitor: monitor, onEdit: onEdit)
            
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
    
    private var notificationTypesText: String {
        let types = item.enabledNotifications.map { notificationType in
            switch notificationType {
            case .success:
                return "Erfolg"
            case .error:
                return "Fehler"
            case .change:
                return "Änderung"
            case .httpCode(let code):
                return "HTTP \(code)"
            }
        }
        return types.joined(separator: ", ")
    }

}

#Preview {
    let monitor = URLMonitor()
    let item = URLItem(
        url: URL(string: "https://example.com")!,
        interval: 10,
        isEnabled: true,
        history: [
            URLItem.HistoryEntry(date: Date(), status: .success, httpStatusCode: 200),
            URLItem.HistoryEntry(date: Date().addingTimeInterval(-60), status: .changed, httpStatusCode: 200),
            URLItem.HistoryEntry(date: Date().addingTimeInterval(-120), status: .error, httpStatusCode: 404)
        ]
    )
    URLItemHeader(item: item, monitor: monitor, onEdit: {})
        .frame(width: 600)
}

