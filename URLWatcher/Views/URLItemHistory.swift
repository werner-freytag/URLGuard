import SwiftUI

struct URLItemHistory: View {
    let item: URLItem
    let monitor: URLMonitor
    @State private var scrollToEnd = false
    
    var body: some View {
            // Historie-Container mit Padding
            HStack(alignment: .top, spacing: 12) {
                // Historie-Visualisierung (einzeilig mit Scroll)
                ScrollViewReader { proxy in
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 1) {
                            ForEach(Array(item.history.reversed()), id: \.date) { entry in
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(color(for: entry.status))
                                    .frame(width: 10, height: 10)
                                    .opacity(item.isEnabled ? 1.0 : 0.6) // Kräftiger wenn aktiviert
                                    .help(tooltipText(for: entry))
                                    .id(entry.date) // ID für ScrollViewReader
                            }
                            
                            // Countdown oder Progress (nur wenn nicht pausiert)
                            if item.isEnabled {
                                if item.isWaiting {
                                    // ProgressView während Request
                                    ProgressView()
                                        .scaleEffect(0.3)
                                        .frame(width: 10, height: 10)
                                        .padding(.horizontal, 2)
                                } else if item.remainingTime > 0 {
                                    // Countdown zwischen Requests
                                    Text("\(Int(item.remainingTime))")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .padding(.horizontal, 4)
                                }
                            } else {
                                // Pausiert-Indikator
                                Text("Angehalten")
                                    .font(.caption)
                                    .foregroundColor(.secondary.opacity(0.5))
                                    .padding(.horizontal, 4)
                            }
                        }
                        .padding(.trailing, 8) // Abstand am Ende für bessere Optik
                    }
                    .frame(height: 12) // Feste Höhe für einzeilige Anzeige
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .onChange(of: item.history.count) { oldCount, newCount in
                        // Bei neuen Einträgen zum Ende scrollen
                        if newCount > oldCount, let firstEntry = item.history.first {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                proxy.scrollTo(firstEntry.date, anchor: .trailing)
                            }
                        }
                    }
                }
                
                Spacer()
                
                // Reset-Button für Historie (nur Icon)
                Button(action: {
                    guard monitor.items.contains(where: { $0.id == item.id }) else { return }
                    monitor.resetHistory(for: item)
                }) {
                    Image(systemName: "arrow.clockwise")
                        .font(.caption)
                        .foregroundColor(.secondary.opacity(item.isEnabled ? 1.0 : 0.5))
                }
                .buttonStyle(PlainButtonStyle())
                .help("Historie leeren")
            }
        .padding(16)
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
            tooltip += "\nHTTP \(httpCode)"
        }
        
        if let responseSize = entry.responseSize {
            let formatter = NumberFormatter()
            formatter.numberStyle = .decimal
            formatter.groupingSeparator = "."
            let formattedSize = formatter.string(from: NSNumber(value: responseSize)) ?? "\(responseSize)"
            tooltip += "\nGröße: \(formattedSize) Bytes"
        }
        
        if let responseTime = entry.responseTime {
            let formatter = NumberFormatter()
            formatter.numberStyle = .decimal
            formatter.minimumFractionDigits = 2
            formatter.maximumFractionDigits = 2
            let formattedTime = formatter.string(from: NSNumber(value: responseTime)) ?? String(format: "%.2f", responseTime)
            tooltip += "\nÜbertragungsdauer: \(formattedTime)s"
        }
        
        if let diffInfo = entry.diffInfo {
            tooltip += "\n\n\(diffInfo.totalChangedLines) Zeilen geändert:"
            
            for line in diffInfo.previewLines {
                tooltip += "\n\(line)"
            }
            
            if diffInfo.totalChangedLines > 20 {
                tooltip += "\n..."
            }
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
                httpStatusCode: status == .error ? 404 : 200,
                diffInfo: status == .changed ? URLItem.DiffInfo(
                    totalChangedLines: 2,
                    previewLines: ["- Zeile 1: Alter Text", "+ Zeile 1: Neuer Text"]
                ) : nil,
                responseSize: 1024,
                responseTime: 0.5
            )
        }
    )
    return URLItemHistory(item: item, monitor: monitor)
        .frame(width: 600, height: 200)
} 
