import SwiftUI

struct HistoryDetailView: View {
    let requestResult: RequestResult
    
    var body: some View {
        // Normaler History-Eintrag
        VStack(alignment: .leading, spacing: 16) {
            // Header mit Status und Datum
            HStack {
                Image(systemName: requestResult.statusIconName)
                    .font(.title2)
                    .foregroundColor(requestResult.statusColor)
                Text(requestResult.statusTitle)
                    .font(.headline)
                    .foregroundColor(requestResult.statusColor)
                Spacer()
                Text(requestResult.date.formatted(date: .abbreviated, time: .standard))
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
                    DetailRow(label: "HTTP Status", value: requestResult.statusCode?.toString())
                    Spacer()
                    DetailRow(label: "Methode", value: requestResult.method)
                    Spacer()
                    DetailRow(label: "Größe", value: requestResult.dataSize?.formattedBytes())
                    Spacer()
                    DetailRow(label: "Dauer", value: requestResult.transferDuration?.formattedDuration())
                }
            }
        
            // HTTP-Header Details
            if let headers = requestResult.headers, !headers.isEmpty {
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
            if let diffInfo = requestResult.diffInfo, diffInfo.totalChangedLines > 0 {
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
            } else if let errorDescription = requestResult.errorDescription, !errorDescription.isEmpty {
                Divider()
            
                HStack {
                    Image(systemName: requestResult.statusIconName)
                        .foregroundColor(requestResult.statusColor)
                    Text(errorDescription)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .lineLimit(2)
                }
            } else if requestResult.status == .success(hasChanges: false) {
                Divider()
            
                HStack {
                    Image(systemName: requestResult.statusIconName)
                        .foregroundColor(requestResult.statusColor)
                    Text("Inhalt nicht geändert")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(20)
    }
}

extension RequestResult {
    var statusIconName: String {
        switch status {
        case .none:
            return "questionmark.circle.dashed"
        case .some(.informational):
            return "info.square.fill"
        case .some(.success(true)):
            return "arrow.trianglehead.2.clockwise.rotate.90.circle.fill"
        case .some(.success):
            return "checkmark.circle.fill"
        case .some(.redirection):
            return "arrowshape.turn.up.forward.circle.fill"
        case .some(.transferError), .some(.clientError), .some(.serverError):
            return "exclamationmark.triangle.fill"
        }
    }
    
    var statusTitle: String {
        switch status {
        case .none:
            return "Unbekannt"
        case .some(.transferError):
            return "Übertragungsfehler"
        case .some(.clientError):
            return "Clientfehler"
        case .some(.serverError):
            return "Serverfehler"
        case .some(.informational):
            return "Information"
        case .some(.success(true)):
            return "Inhalt geändert"
        case .some(.success):
            return "Erfolgreich"
        case .some(.redirection):
            return "Weiterleitung"
        }
    }

    var statusColor: Color {
        switch status {
        case .none:
            return .gray
        case .some(.transferError):
            return .red
        case .some(.clientError):
            return .purple
        case .some(.serverError):
            return .pink
        case .some(.informational):
            return .teal
        case .some(.success(true)):
            return .blue
        case .some(.success):
            return .green
        case .some(.redirection):
            return .brown
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
    let result = RequestResult(
        method: "GET",
        statusCode: 200,
        dataSize: 15420,
        transferDuration: 0.85
    )
    
    HistoryDetailView(requestResult: result)
        .frame(width: 400, height: 300)
}

#Preview("HistoryDetailView - Änderung") {
    let changedLines = [
        DiffInfo.ChangedLine(
            lineNumber: 1,
            oldContent: "<title>Alte Seite</title>",
            newContent: "<title>Neue Seite</title>",
            changeType: .modified
        ),
        DiffInfo.ChangedLine(
            lineNumber: 2,
            oldContent: "<meta name=\"description\" content=\"Alte Beschreibung\">",
            newContent: "<meta name=\"description\" content=\"Neue Beschreibung\">",
            changeType: .modified
        ),
        DiffInfo.ChangedLine(
            lineNumber: 3,
            oldContent: "<div class=\"old-content\">",
            newContent: "<div class=\"new-content\">",
            changeType: .modified
        ),
        DiffInfo.ChangedLine(
            lineNumber: 5,
            oldContent: "  <p>Entfernter Text</p>",
            newContent: "",
            changeType: .removed
        ),
        DiffInfo.ChangedLine(
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
    
    let result = RequestResult(
        date: Date().addingTimeInterval(-300),
        method: "GET",
        statusCode: 200,
        dataSize: 18250,
        transferDuration: 1.23,
        diffInfo: diffInfo
    )
    
    HistoryDetailView(requestResult: result)
        .frame(width: 400, height: 400)
}

#Preview("HistoryDetailView - Fehler") {
    let result = RequestResult(
        date: Date().addingTimeInterval(-600),
        method: "GET",
        statusCode: nil,
        errorDescription: "Connection failed"
    )
    
    HistoryDetailView(requestResult: result)
        .frame(width: 400, height: 250)
}

#Preview("HistoryDetailView - Alle Szenarien") {
    VStack(spacing: 20) {
        // Erfolg
        let successResult = RequestResult(
            method: "GET",
            statusCode: 200,
            dataSize: 15420,
            transferDuration: 0.85
        )
        
        // Änderung
        let changedLines = [
            DiffInfo.ChangedLine(
                lineNumber: 1,
                oldContent: "<title>Alte Seite</title>",
                newContent: "<title>Neue Seite</title>",
                changeType: .modified
            ),
            DiffInfo.ChangedLine(
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
        
        let changeResult = RequestResult(
            date: Date().addingTimeInterval(-300),
            method: "GET",
            statusCode: 200,
            dataSize: 18250,
            transferDuration: 1.23,
            diffInfo: diffInfo
        )
        
        // Fehler
        let errorResult = RequestResult(
            date: Date().addingTimeInterval(-600),
            method: "GET",
            statusCode: 404,
            dataSize: 0,
            transferDuration: 2.45,
            errorDescription: "Not Found"
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
                    HistoryDetailView(requestResult: successResult)
                        .frame(width: 300, height: 200)
                }
                
                VStack {
                    Text("Änderung")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    HistoryDetailView(requestResult: changeResult)
                        .frame(width: 300, height: 200)
                }
                
                VStack {
                    Text("Fehler")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    HistoryDetailView(requestResult: errorResult)
                        .frame(width: 300, height: 200)
                }
            }
        }
        .padding()
    }
}

// MARK: - Helper Views

struct ChangedLineView: View {
    let changedLine: DiffInfo.ChangedLine
    
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
