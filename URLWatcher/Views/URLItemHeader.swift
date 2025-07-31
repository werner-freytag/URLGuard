import SwiftUI

struct URLItemHeader: View {
    let item: URLItem
    let monitor: URLMonitor
    let onEdit: () -> Void
    
    var body: some View {
        Button(action: {
            guard monitor.items.contains(where: { $0.id == item.id }) else { return }
            monitor.toggleCollapse(for: item)
        }) {
            HStack {
                // Titel: URL - Dauer
                HStack(spacing: 4) {
                    Text(item.urlString.isEmpty ? "Keine URL" : item.urlString)
                        .font(.headline)
                        .fontWeight(.bold)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Text("–")
                        .font(.headline)
                    Text("\(Int(item.interval))s")
                        .font(.headline)
                        .fontWeight(.regular)
                }
                .foregroundColor(item.isPaused ? .secondary : .primary)
                
                // Bearbeiten-Button
                Button(action: {
                    onEdit()
                }) {
                    Text("Bearbeiten")
                        .font(.caption)
                        .foregroundColor(.blue)
                }
                .buttonStyle(.bordered)
                
                // Löschen-Button neben dem Bearbeiten-Button
                Button(action: {
                    guard monitor.items.contains(where: { $0.id == item.id }) else { return }
                    monitor.remove(item: item)
                }) {
                    Text("Löschen")
                        .font(.caption)
                        .foregroundColor(.red)
                }
                .buttonStyle(.bordered)
                
                Spacer()
                
                // Countdown links vom Status (nur wenn nicht pausiert)
                if item.isWaiting && !item.isPaused {
                    Text("\(Int(item.remainingTime))s")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.trailing, 4)
                }
                
                // Klickbare Status-Anzeige (Historie ein-/ausblenden)
                HStack(spacing: 4) {
                    Circle()
                        .fill(statusColor(for: item))
                        .frame(width: 8, height: 8)
                    Text(statusText(for: item))
                        .font(.caption)
                        .foregroundColor(statusColor(for: item).opacity(item.isPaused ? 0.6 : 1.0))
                }
                
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
                .disabled(item.isNewItem)
            }
        }
        .buttonStyle(PlainButtonStyle())
        .help(item.isCollapsed ? "Historie anzeigen" : "Historie ausblenden")
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
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