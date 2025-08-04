import SwiftUI

struct URLItemHeader: View {
    let item: URLItem
    let monitor: URLMonitor
    let onEdit: () -> Void

    var body: some View {
        HStack {
            IconButton(
                icon: item.isEnabled ? "play.circle.fill" : "pause.circle.fill",
                color: item.isEnabled ? .green : .orange,
                helpText: item.isEnabled ? "Pausieren" : "Starten",
            ) {
                guard monitor.items.contains(where: { $0.id == item.id }) else { return }
                monitor.togglePause(for: item)
            }
            
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
            
            Spacer()
            
            VStack {
                HStack(spacing: 8) {
                    ActionButton(
                        icon: "pencil",
                        title: "Bearbeiten",
                        color: .blue,
                    ) {
                        onEdit()
                    }
                    
                    ActionButton(
                        icon: "plus.square.on.square",
                        title: "Duplizieren",
                        color: .secondary,
                    ) {
                        guard monitor.items.contains(where: { $0.id == item.id }) else { return }
                        monitor.duplicate(item: item)
                    }
                    
                    ActionButton(
                        icon: "trash",
                        title: "Löschen",
                        color: .red,
                    ) {
                        guard monitor.items.contains(where: { $0.id == item.id }) else { return }
                        monitor.remove(item: item)
                    }
                }
            }
            .offset(x: 8, y: -6)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .onTapGesture(count: 2) {
            onEdit()
        }
        .onTapGesture {
            monitor.togglePause(for: item)
        }
        .contextMenu {
            Button(item.isEnabled ? "Pausieren" : "Starten") {
                monitor.togglePause(for: item)
            }
            
            Divider()
            
            Button("Bearbeiten") {
                onEdit()
            }
            
            Button("Duplizieren") {
                monitor.duplicate(item: item)
            }
            
            Divider()
            
            Button("Löschen") {
                monitor.remove(item: item)
            }
            .foregroundColor(.red)
        }
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

