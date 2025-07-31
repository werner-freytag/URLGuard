import SwiftUI

struct URLItemHistory: View {
    let item: URLItem
    let monitor: URLMonitor
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Abstand vor der Trennlinie
            Spacer()
                .frame(height: 16)
            
            // Trennlinie zwischen Header und Historie
            Rectangle()
                .fill(Color.secondary.opacity(0.2))
                .frame(height: 1)
            
            // Abstand nach der Trennlinie
            Spacer()
                .frame(height: 16)
            
            // Historie-Container mit Padding
            HStack(alignment: .top, spacing: 12) {
                // Historie-Visualisierung (einzeilig mit Scroll)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 1) {
                        ForEach(Array(item.history.prefix(300).reversed()), id: \.date) { entry in
                            RoundedRectangle(cornerRadius: 2)
                                .fill(color(for: entry.status))
                                .frame(width: 10, height: 10)
                                .help(tooltipText(for: entry))
                        }
                    }
                    .padding(.trailing, 8) // Abstand am Ende für bessere Optik
                }
                .frame(height: 12) // Feste Höhe für einzeilige Anzeige
                .frame(maxWidth: .infinity, alignment: .leading)
                
                Spacer()
                
                // Reset-Button für Historie (rechtsbündig)
                Button(action: {
                    guard monitor.items.contains(where: { $0.id == item.id }) else { return }
                    monitor.resetHistory(for: item)
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "trash")
                            .font(.caption)
                        Text("Historie leeren")
                            .font(.caption)
                    }
                    .foregroundColor(.secondary)
                }
                .buttonStyle(PlainButtonStyle())
                .help("Historie leeren")
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 16)
        .background(Color.white)
    }
    
    func color(for status: URLItem.Status) -> Color {
        switch status {
        case .success: return .green
        case .changed: return .blue
        case .error: return .red
        }
    }
    
    private func tooltipText(for entry: URLItem.HistoryEntry) -> String {
        let statusText = entry.status.rawValue
        let dateString = entry.date.formatted()
        var tooltip = "\(statusText) - \(dateString)"
        
        if let httpCode = entry.httpStatusCode {
            tooltip += " (HTTP \(httpCode))"
        }
        
        return tooltip
    }
}

#Preview {
    let monitor = URLMonitor()
    let item = URLItem(
        urlString: "https://example.com", 
        interval: 10,
        history: Array(0..<50).map { i in
            let status: URLItem.Status = i % 3 == 0 ? .success : (i % 3 == 1 ? .changed : .error)
            return URLItem.HistoryEntry(
                date: Date().addingTimeInterval(-Double(i * 60)), 
                status: status, 
                httpStatusCode: status == .error ? 404 : 200
            )
        }
    )
    return URLItemHistory(item: item, monitor: monitor)
        .frame(width: 600, height: 200)
} 
