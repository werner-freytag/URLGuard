import SwiftUI

struct HistoryDetailView: View {
    let entry: URLItem.HistoryEntry
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header mit Status und Datum
            HStack {
                Image(systemName: entry.statusIconName)
                    .font(.title2)
                    .foregroundColor(entry.statusColor)
                Text(entry.statusTitle)
                    .font(.headline)
                    .foregroundColor(entry.statusColor)
                Spacer()
                Text(entry.date.formatted(date: .abbreviated, time: .standard))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Divider()
            
            // Technische Details
            VStack(alignment: .leading, spacing: 12) {
                Text("Technische Details")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                HStack {
                    DetailRow(label: "Größe", value: entry.responseSize?.formattedBytes())
                    Spacer()
                    DetailRow(label: "HTTP Status", value: entry.httpStatusCode?.toString())
                    Spacer()
                    DetailRow(label: "Übertragungsdauer", value: entry.responseTime?.formattedDuration())
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
                                    .foregroundColor(diffLineColor(for: line))
                                    .padding(EdgeInsets(top: 1, leading: 4, bottom: 1, trailing: 4))
                                    .background(diffLineBackgroundColor(for: line))
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
                    .frame(maxHeight: .infinity)
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
        }
        .padding(20)
    }
}

private func diffLineColor(for line: String) -> Color {
    if line.hasPrefix("+") {
        return .green
    } else if line.hasPrefix("-") {
        return .red
    } else {
        return .primary
    }
}

private func diffLineBackgroundColor(for line: String) -> Color {
    if line.hasPrefix("+") {
        return Color.green.opacity(0.1)
    } else if line.hasPrefix("-") {
        return Color.red.opacity(0.1)
    } else {
        return Color.clear
    }
}

private extension URLItem.HistoryEntry {
    var statusIconName: String {
        switch status {
        case .success: return "checkmark.circle.fill"
        case .changed: return "arrow.trianglehead.2.clockwise.rotate.90.circle.fill"
        case .error: return "exclamationmark.triangle.fill"
        }
    }
    
    var statusTitle: String {
        switch status {
        case .success: return "Erfolgreich"
        case .changed: return "Geändert"
        case .error: return "Fehler"
        }
    }
    
    var statusColor: Color {
        switch status {
        case .success: return .green
        case .changed: return .blue
        case .error: return .red
        }
    }
}

private extension Int {
    func formattedBytes() -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .memory
        return formatter.string(fromByteCount: Int64(self))
    }
}

private extension Int {
    func toString() -> String {
        return "\(self)"
    }
}

private extension Double {
    func formattedDuration() -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        return "\(formatter.string(from: NSNumber(value: self)) ?? String(format: "%.2f", self))s"
    }
}

struct DetailRow: View {
    let label: String
    let value: String?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
            Text(value ?? "-")
                .font(.body)
                .fontWeight(.medium)
        }
    }
}

#Preview("HistoryDetailView - Erfolg") {
    let successEntry = URLItem.HistoryEntry(
        date: Date(),
        status: .success,
        httpStatusCode: 200,
        responseSize: 15420,
        responseTime: 0.85
    )
    
    return HistoryDetailView(entry: successEntry)
        .frame(width: 400, height: 300)
}

#Preview("HistoryDetailView - Änderung") {
    let diffInfo = URLItem.DiffInfo(
        totalChangedLines: 25,
        previewLines: [
            "- <title>Alte Seite</title>",
            "+ <title>Neue Seite</title>",
            "- <meta name=\"description\" content=\"Alte Beschreibung\">",
            "+ <meta name=\"description\" content=\"Neue Beschreibung\">",
            "- <div class=\"old-content\">",
            "+ <div class=\"new-content\">",
            "  <p>Gemeinsamer Inhalt</p>",
            "-  <p>Entfernter Text</p>",
            "+  <p>Hinzugefügter Text</p>",
            "  <p>Weiterer gemeinsamer Inhalt</p>",
            "- </div>",
            "+ </div>"
        ]
    )
    
    let changedEntry = URLItem.HistoryEntry(
        date: Date().addingTimeInterval(-300),
        status: .changed,
        httpStatusCode: 200,
        diffInfo: diffInfo,
        responseSize: 18250,
        responseTime: 1.23
    )
    
    return HistoryDetailView(entry: changedEntry)
        .frame(width: 400, height: 400)
}

#Preview("HistoryDetailView - Fehler") {
    let errorEntry = URLItem.HistoryEntry(
        date: Date().addingTimeInterval(-600),
        status: .error,
    )
    
    return HistoryDetailView(entry: errorEntry)
        .frame(width: 400, height: 250)
}

#Preview("HistoryDetailView - Alle Szenarien") {
    VStack(spacing: 20) {
        // Erfolg
        let successEntry = URLItem.HistoryEntry(
            date: Date(),
            status: .success,
            httpStatusCode: 200,
            responseSize: 15420,
            responseTime: 0.85
        )
        
        // Änderung
        let diffInfo = URLItem.DiffInfo(
            totalChangedLines: 8,
            previewLines: [
                "- <title>Alte Seite</title>",
                "+ <title>Neue Seite</title>",
                "- <meta name=\"description\" content=\"Alte Beschreibung\">",
                "+ <meta name=\"description\" content=\"Neue Beschreibung\">"
            ]
        )
        
        let changedEntry = URLItem.HistoryEntry(
            date: Date().addingTimeInterval(-300),
            status: .changed,
            httpStatusCode: 200,
            diffInfo: diffInfo,
            responseSize: 18250,
            responseTime: 1.23
        )
        
        // Fehler
        let errorEntry = URLItem.HistoryEntry(
            date: Date().addingTimeInterval(-600),
            status: .error,
            httpStatusCode: 404,
            responseSize: 0,
            responseTime: 2.45
        )
        
        VStack(spacing: 16) {
            Text("HistoryDetailView - Alle Szenarien")
                .font(.headline)
                .padding(.bottom, 8)
            
            HStack(spacing: 16) {
                VStack {
                    Text("Erfolg")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    HistoryDetailView(entry: successEntry)
                        .frame(width: 300, height: 200)
                }
                
                VStack {
                    Text("Änderung")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    HistoryDetailView(entry: changedEntry)
                        .frame(width: 300, height: 200)
                }
                
                VStack {
                    Text("Fehler")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    HistoryDetailView(entry: errorEntry)
                        .frame(width: 300, height: 200)
                }
            }
        }
        .padding()
    }
}
