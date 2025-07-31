import SwiftUI

struct URLItemHeader: View {
    let item: URLItem
    let monitor: URLMonitor
    let onEdit: () -> Void
    @State private var rotationAngle: Double = 0
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                // Haupttitel
                if let title = item.title, !title.isEmpty {
                    // Benutzerdefinierter Titel
                    Text(title)
                        .font(.headline)
                        .fontWeight(.bold)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .foregroundColor(item.isPaused ? .secondary : .primary)
                } else if let components = urlComponents {
                    // URL-Komponenten anzeigen
                    HStack(spacing: 4) {
                        Text(components.host)
                            .font(.headline)
                            .fontWeight(.bold)
                            .foregroundColor(item.isPaused ? .secondary : .primary)
                        
                        if let lastPathComponent = components.lastPathComponent {
                            Text(" – ")
                                .font(.headline)
                                .fontWeight(.regular)
                                .foregroundColor(item.isPaused ? .secondary.opacity(0.6) : .primary.opacity(0.6))
                            
                            Text(lastPathComponent)
                                .font(.headline)
                                .fontWeight(.regular)
                                .foregroundColor(item.isPaused ? .secondary.opacity(0.6) : .primary.opacity(0.6))
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
                        .foregroundColor(item.isPaused ? .secondary : .primary)
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
            
            // Disclosure-Pfeil + Status (klickbar für Historie ein-/ausblenden)
            Button(action: {
                guard monitor.items.contains(where: { $0.id == item.id }) else { return }
                monitor.toggleCollapse(for: item)
            }) {
                HStack(spacing: 4) {
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .frame(width: 16, height: 16, alignment: .center)
                        .rotationEffect(.degrees(rotationAngle))
                    
                    Circle()
                        .fill(statusColor(for: item))
                        .frame(width: 8, height: 8)
                    Text(statusText(for: item))
                        .font(.caption)
                        .foregroundColor(statusColor(for: item).opacity(item.isPaused ? 0.6 : 1.0))
                }
            }
            .buttonStyle(PlainButtonStyle())
            .help(item.isCollapsed ? "Historie anzeigen" : "Historie ausblenden")
            
            // Pause-Button hinter dem Status (nur Icon)
            Button(action: {
                guard monitor.items.contains(where: { $0.id == item.id }) else { return }
                monitor.togglePause(for: item)
            }) {
                Image(systemName: item.isPaused ? "play.circle.fill" : "pause.circle.fill")
                    .font(.title3)
                    .foregroundColor(item.isPaused ? .green : .orange)
            }
            .buttonStyle(PlainButtonStyle())
            .help(item.isPaused ? "Start" : "Pause")
            
            
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
        .onAppear {
            // Initiale Rotation setzen
            rotationAngle = item.isCollapsed ? 0 : 90
        }
        .onChange(of: item.isCollapsed) { oldValue, newValue in
            // Rotation bei Änderung animieren
            withAnimation(.easeInOut(duration: 0.3)) {
                rotationAngle = newValue ? 0 : 90
            }
        }
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
    
    func statusColor(for item: URLItem) -> Color {
        if let lastEntry = item.history.first {
            return color(for: lastEntry.status)
        } else if let currentStatus = item.currentStatus {
            return color(for: currentStatus)
        }
        return .gray
    }
    
    func statusText(for item: URLItem) -> String {
        if let lastEntry = item.history.first {
            return lastEntry.status.rawValue.capitalized
        } else if let currentStatus = item.currentStatus {
            return currentStatus.rawValue.capitalized
        }
        return "Unbekannt"
    }
    
    func color(for status: URLItem.Status) -> Color {
        switch status {
        case .success: return .green
        case .changed: return .yellow
        case .error: return .red
        }
    }
}

#Preview {
    let monitor = URLMonitor()
    let item = URLItem(
        urlString: "https://example.com", 
        interval: 10, 
        isPaused: false,
        history: [
            URLItem.HistoryEntry(date: Date(), status: .success, httpStatusCode: 200),
            URLItem.HistoryEntry(date: Date().addingTimeInterval(-60), status: .changed, httpStatusCode: 200),
            URLItem.HistoryEntry(date: Date().addingTimeInterval(-120), status: .error, httpStatusCode: 404)
        ]
    )
    return URLItemHeader(item: item, monitor: monitor, onEdit: {})
        .frame(width: 600)
} 
