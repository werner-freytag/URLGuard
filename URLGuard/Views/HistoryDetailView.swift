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
                    DetailRow(label: "HTTP Status", value: entry.httpStatusCode?.toString())
                    Spacer()
                    DetailRow(label: "Methode", value: entry.httpMethod)
                    Spacer()
                    DetailRow(label: "Größe", value: entry.responseSize?.formattedBytes())
                    Spacer()
                    DetailRow(label: "Dauer", value: entry.responseTime?.formattedDuration())
                }
            }
            
            // HTTP-Header Details
            if let headers = entry.headers, !headers.isEmpty {
                Divider()
                
                VStack(alignment: .leading, spacing: 12) {
                    Text("HTTP-Header")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    
                    LazyVGrid(columns: [
                        GridItem(.fixed(80), alignment: .topLeading),
                        GridItem(.flexible(), alignment: .leading)
                    ]) {
                        ForEach(Array(headers.enumerated()), id: \.offset) { _, header in
                            HeaderRow(label: header.key, value: header.value)
                        }
                    }
                    .textSelection(.enabled)
                }
            }
            
            // Diff-Informationen
            if entry.status == .changed, let diffInfo = entry.diffInfo {
                Divider()
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Änderungen")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    
                    ScrollView {
                        VStack(alignment: .leading, spacing: 4) {
                            ForEach(diffInfo.changedLines, id: \.lineNumber) { changedLine in
                                ChangedLineView(changedLine: changedLine)
                            }
                            
                            if diffInfo.changedLines.count < diffInfo.totalChangedLines {
                                if diffInfo.totalChangedLines - diffInfo.changedLines.count == 1 {
                                    Text("... und 1 weitere Änderung")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .italic()
                                } else {
                                    Text("... und \(diffInfo.totalChangedLines - diffInfo.changedLines.count) weitere Änderungen")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .italic()
                                }
                            }
                        }
                    }
                    .frame(maxHeight: 200)
                }
            } else if entry.status == .success {
                Divider()
                
                HStack {
                    Image(systemName: entry.statusIconName)
                        .foregroundColor(entry.statusColor)
                    Text("Inhalt nicht geändert")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            } else if entry.status == .error, let errorDescription = entry.errorDescription {
                Divider()
                
                HStack {
                    Image(systemName: entry.statusIconName)
                        .foregroundColor(entry.statusColor)
                    Text(errorDescription)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .lineLimit(2)
                }
            }
        }
        .padding(20)
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
        let measurement = Measurement(value: self, unit: UnitDuration.seconds)

        let formatter = MeasurementFormatter()
        formatter.unitStyle = .short
        formatter.numberFormatter.maximumFractionDigits = 3

        return formatter.string(from: measurement)
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

struct HeaderRow: View {
    let label: String
    let value: String
    
    var body: some View {
        Text("\(label):")
            .font(.caption2)
            .foregroundColor(.secondary)
        Text(value)
            .font(.caption)
            .fontWeight(.medium)
            .lineLimit(2)
            .truncationMode(.tail)
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
    let changedLines = [
        ChangedLine(
            lineNumber: 1,
            oldContent: "<title>Alte Seite</title>",
            newContent: "<title>Neue Seite</title>",
            changeType: .modified
        ),
        ChangedLine(
            lineNumber: 2,
            oldContent: "<meta name=\"description\" content=\"Alte Beschreibung\">",
            newContent: "<meta name=\"description\" content=\"Neue Beschreibung\">",
            changeType: .modified
        ),
        ChangedLine(
            lineNumber: 3,
            oldContent: "<div class=\"old-content\">",
            newContent: "<div class=\"new-content\">",
            changeType: .modified
        ),
        ChangedLine(
            lineNumber: 5,
            oldContent: "  <p>Entfernter Text</p>",
            newContent: "",
            changeType: .removed
        ),
        ChangedLine(
            lineNumber: 6,
            oldContent: "",
            newContent: "  <p>Hinzugefügter Text</p>",
            changeType: .added
        )
    ]
    
    let diffInfo = DiffInfo(
        totalChangedLines: 5,
        changedLines: changedLines
    )
    
    let changedEntry = URLItem.HistoryEntry(
        date: Date().addingTimeInterval(-300),
        status: .changed,
        httpStatusCode: 200,
        diffInfo: diffInfo,
        responseSize: 18250,
        responseTime: 1.23
    )
    
    HistoryDetailView(entry: changedEntry)
        .frame(width: 400, height: 400)
}

#Preview("HistoryDetailView - Fehler") {
    let errorEntry = URLItem.HistoryEntry(
        date: Date().addingTimeInterval(-600),
        status: .error
    )
    
    HistoryDetailView(entry: errorEntry)
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
        let changedLines = [
            ChangedLine(
                lineNumber: 1,
                oldContent: "<title>Alte Seite</title>",
                newContent: "<title>Neue Seite</title>",
                changeType: .modified
            ),
            ChangedLine(
                lineNumber: 2,
                oldContent: "<meta name=\"description\" content=\"Alte Beschreibung\">",
                newContent: "<meta name=\"description\" content=\"Neue Beschreibung\">",
                changeType: .modified
            )
        ]
        
        let diffInfo = DiffInfo(
            totalChangedLines: 2,
            changedLines: changedLines
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

// MARK: - Helper Views

struct ChangedLineView: View {
    let changedLine: ChangedLine
    
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(lineNumberText)
                    .font(.caption2)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
            }
            
            if changedLine.changeType == .added {
                ForEach(changedLine.newContent.components(separatedBy: .newlines), id: \.self) { line in
                    if !line.isEmpty {
                        Text("+ \(line)")
                            .font(.system(.caption, design: .monospaced))
                            .foregroundColor(.green)
                            .padding(.leading, 8)
                    }
                }
            } else if changedLine.changeType == .removed {
                ForEach(changedLine.oldContent.components(separatedBy: .newlines), id: \.self) { line in
                    if !line.isEmpty {
                        Text("- \(line)")
                            .font(.system(.caption, design: .monospaced))
                            .foregroundColor(.red)
                            .padding(.leading, 8)
                    }
                }
            } else {
                VStack(alignment: .leading, spacing: 1) {
                    ForEach(changedLine.oldContent.components(separatedBy: .newlines), id: \.self) { line in
                        if !line.isEmpty {
                            Text("- \(line)")
                                .font(.system(.caption, design: .monospaced))
                                .foregroundColor(.red)
                                .padding(.leading, 8)
                        }
                    }
                    ForEach(changedLine.newContent.components(separatedBy: .newlines), id: \.self) { line in
                        if !line.isEmpty {
                            Text("+ \(line)")
                                .font(.system(.caption, design: .monospaced))
                                .foregroundColor(.green)
                                .padding(.leading, 8)
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(.gray.opacity(0.05))
        .cornerRadius(4)
    }
    
    private var lineNumberText: String {
        let oldLines = changedLine.oldContent.components(separatedBy: .newlines).filter { !$0.isEmpty }
        let newLines = changedLine.newContent.components(separatedBy: .newlines).filter { !$0.isEmpty }
        
        if oldLines.count > 1 || newLines.count > 1 {
            // Mehrere Zeilen - zeige Bereich an
            let lastLineNumber = changedLine.lineNumber + max(oldLines.count, newLines.count) - 1
            return "Zeilen \(changedLine.lineNumber)-\(lastLineNumber)"
        } else {
            // Einzelne Zeile
            return "Zeile \(changedLine.lineNumber)"
        }
    }
    
    private var changeTypeColor: Color {
        switch changedLine.changeType {
        case .added:
            return .green
        case .removed:
            return .red
        case .modified:
            return .orange
        }
    }
}
