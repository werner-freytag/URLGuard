import SwiftUI

struct URLItemHeader: View {
    let item: URLItem
    let monitor: URLMonitor
    let onEdit: () -> Void
    
    var body: some View {
        HStack {
            // Start/Pause Button ganz links und groß
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
                } else if let components = urlComponents {
                    // URL-Komponenten anzeigen
                    HStack(spacing: 4) {
                        Text(components.host)
                            .font(.headline)
                            .fontWeight(.bold)
                            .foregroundColor(item.isEnabled ? .primary : .secondary)
                        
                        if let lastPathComponent = components.lastPathComponent {
                            Text(" – ")
                                .font(.headline)
                                .fontWeight(.regular)
                                .foregroundColor(item.isEnabled ? .primary.opacity(0.6) : .secondary.opacity(0.6))
                            
                            Text(lastPathComponent)
                                .font(.headline)
                                .fontWeight(.regular)
                                .foregroundColor(item.isEnabled ? .primary.opacity(0.6) : .secondary.opacity(0.6))
                        }
                    }
                    .lineLimit(1)
                    .truncationMode(.middle)
                } else {
                    // Fallback
                    Text(displayTitle)
                        .font(.headline)
                        .fontWeight(.bold)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .foregroundColor(item.isEnabled ? .primary : .secondary)
                }
                
                // URL und Intervall als Untertitel
                HStack(spacing: 4) {
                    if item.title != nil && !item.urlString.isEmpty {
                        Text(item.urlString)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    } else if !item.urlString.isEmpty {
                        Text(item.urlString)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                    
                    if !item.urlString.isEmpty {
                        Text("•")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("Intervall: \(Int(item.interval))s")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .onTapGesture(count: 2) {
                // Doppelklick zum Bearbeiten
                onEdit()
            }
            
            Spacer()
            
            
            // Bearbeiten-Button
            Button(action: {
                onEdit()
            }) {
                Text("Bearbeiten")
                    .font(.caption)
                    .foregroundColor(.blue)
            }
            .buttonStyle(.bordered)
            
            // Duplizieren-Button
            Button(action: {
                guard monitor.items.contains(where: { $0.id == item.id }) else { return }
                monitor.duplicate(item: item)
            }) {
                Text("Duplizieren")
                    .font(.caption)
                    .foregroundColor(.green)
            }
            .buttonStyle(.bordered)
            
            // Löschen-Button
            Button(action: {
                guard monitor.items.contains(where: { $0.id == item.id }) else { return }
                monitor.remove(item: item)
            }) {
                Text("Löschen")
                    .font(.caption)
                    .foregroundColor(.red)
            }
            .buttonStyle(.bordered)
            
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
    
    private var displayTitle: String {
        if let title = item.title, !title.isEmpty {
            return title
        } else if !item.urlString.isEmpty {
            return item.urlString
        } else {
            return "Keine URL"
        }
    }
    
    private var urlComponents: (host: String, path: String, lastPathComponent: String?)? {
        guard !item.urlString.isEmpty else { return nil }
        
        // URL korrigieren falls nötig
        let correctedURL = item.urlString.hasPrefix("http") ? item.urlString : "https://" + item.urlString
        
        guard let url = URL(string: correctedURL),
              let host = url.host else { return nil }
        
        let path = url.path.isEmpty ? "" : url.path
        
        // Letzte Pfadkomponente extrahieren
        let lastPathComponent: String?
        if !path.isEmpty && path != "/" {
            let pathComponents = path.components(separatedBy: "/").filter { !$0.isEmpty }
            lastPathComponent = pathComponents.last
        } else {
            lastPathComponent = nil
        }
        
        return (host: host, path: path, lastPathComponent: lastPathComponent)
    }
    

}

#Preview {
    let monitor = URLMonitor()
    let item = URLItem(
        urlString: "https://example.com", 
        interval: 10, 
                    isEnabled: true,
        history: [
            URLItem.HistoryEntry(date: Date(), status: .success, httpStatusCode: 200),
            URLItem.HistoryEntry(date: Date().addingTimeInterval(-60), status: .changed, httpStatusCode: 200),
            URLItem.HistoryEntry(date: Date().addingTimeInterval(-120), status: .error, httpStatusCode: 404)
        ]
    )
    return URLItemHeader(item: item, monitor: monitor, onEdit: {})
        .frame(width: 600)
} 
