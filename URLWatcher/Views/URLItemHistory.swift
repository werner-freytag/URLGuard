import SwiftUI

struct URLItemHistory: View {
    let item: URLItem
    let monitor: URLMonitor
    @State private var scrollToEnd = false
    @State private var selectedEntry: URLItem.HistoryEntry? = nil
    @State private var showingDetailPopover = false
    
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
                                    .onTapGesture {
                                        selectedEntry = entry
                                        showingDetailPopover = true
                                    }
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
            .popover(isPresented: $showingDetailPopover, arrowEdge: .top) {
                if let entry = selectedEntry {
                    HistoryDetailView(entry: entry)
                        .frame(width: 400, height: 300)
                }
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
}

struct HistoryDetailView: View {
    let entry: URLItem.HistoryEntry
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header mit Status und Datum
            HStack {
                statusIcon
                VStack(alignment: .leading, spacing: 4) {
                    Text(statusTitle)
                        .font(.headline)
                        .foregroundColor(statusColor)
                    Text(entry.date.formatted(date: .abbreviated, time: .shortened))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
            }
            
            Divider()
            
            // Technische Details
            VStack(alignment: .leading, spacing: 12) {
                Text("Technische Details")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 8) {
                    if let httpCode = entry.httpStatusCode {
                        DetailRow(label: "HTTP Status", value: "\(httpCode)")
                    }
                    
                    if let responseSize = entry.responseSize {
                        DetailRow(label: "Größe", value: formatBytes(responseSize))
                    }
                    
                    if let responseTime = entry.responseTime {
                        DetailRow(label: "Übertragungsdauer", value: formatTime(responseTime))
                    }
                }
            }
            
            // Diff-Informationen
            if let diffInfo = entry.diffInfo {
                Divider()
                
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Änderungen")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                        Spacer()
                        Text("\(diffInfo.totalChangedLines) Zeilen")
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(4)
                    }
                    
                    ScrollView {
                        VStack(alignment: .leading, spacing: 4) {
                            ForEach(diffInfo.previewLines, id: \.self) { line in
                                Text(line)
                                    .font(.system(.caption, design: .monospaced))
                                    .foregroundColor(lineColor(for: line))
                                    .padding(EdgeInsets(top: 1, leading: 4, bottom: 1, trailing: 4))
                                    .background(lineBackgroundColor(for: line))
                                    .cornerRadius(2)
                            }
                            
                            if diffInfo.totalChangedLines > 20 {
                                Text("... und \(diffInfo.totalChangedLines - 20) weitere Änderungen")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .italic()
                            }
                        }
                    }
                    .frame(maxHeight: 120)
                }
            } else if entry.status == .success {
                Divider()
                
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("Inhalt nicht geändert")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
        }
        .padding(20)
        .background(Color(.controlBackgroundColor))
    }
    
    private var statusIcon: some View {
        Image(systemName: statusIconName)
            .font(.title2)
            .foregroundColor(statusColor)
    }
    
    private var statusIconName: String {
        switch entry.status {
        case .success: return "checkmark.circle.fill"
        case .changed: return "arrow.triangle.2.circlepath"
        case .error: return "exclamationmark.triangle.fill"
        }
    }
    
    private var statusTitle: String {
        switch entry.status {
        case .success: return "Erfolgreich"
        case .changed: return "Geändert"
        case .error: return "Fehler"
        }
    }
    
    private var statusColor: Color {
        switch entry.status {
        case .success: return .green
        case .changed: return .blue
        case .error: return .red
        }
    }
    
    private func formatBytes(_ bytes: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = "."
        return "\(formatter.string(from: NSNumber(value: bytes)) ?? "\(bytes)") Bytes"
    }
    
    private func formatTime(_ time: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        return "\(formatter.string(from: NSNumber(value: time)) ?? String(format: "%.2f", time))s"
    }
    
    private func lineColor(for line: String) -> Color {
        if line.hasPrefix("+") {
            return .green
        } else if line.hasPrefix("-") {
            return .red
        } else {
            return .primary
        }
    }
    
    private func lineBackgroundColor(for line: String) -> Color {
        if line.hasPrefix("+") {
            return Color.green.opacity(0.1)
        } else if line.hasPrefix("-") {
            return Color.red.opacity(0.1)
        } else {
            return Color.clear
        }
    }
}

struct DetailRow: View {
    let label: String
    let value: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
            Text(value)
                .font(.body)
                .fontWeight(.medium)
        }
    }
}

#Preview {
    let monitor = URLMonitor()
    let item = URLItem(
        url: URL(string: "https://example.com")!,
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
    URLItemHistory(item: item, monitor: monitor)
        .frame(width: 600, height: 200)
} 
