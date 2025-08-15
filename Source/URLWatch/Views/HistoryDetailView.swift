import SwiftUI

struct HistoryDetailView: View {
    let requestResult: RequestResult
    let isMarked: Bool?
    let markerAction: (() -> Void)?
    
    init(
        requestResult: RequestResult,
        isMarked: Bool? = false,
        markerAction: (() -> Void)? = nil
    ) {
        self.requestResult = requestResult
        self.isMarked = isMarked
        self.markerAction = markerAction
    }

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
                HStack(spacing: 4) {
                    Text(requestResult.date.formatted(date: .abbreviated, time: .standard))
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    if let isMarked {
                        if let markerAction {
                            Button(action: {
                                markerAction()
                            }) {
                                Image(systemName: "circle.fill")
                                    .font(.caption)
                                    .foregroundColor(isMarked ? .red : .gray.opacity(0.5))
                            }
                            .buttonStyle(.plain)
                            .help(isMarked ? "Marked – Click to remove marking" : "Click to mark entry")
                        } else {
                            Image(systemName: "circle.fill")
                                .font(.caption)
                                .foregroundColor(isMarked ? .red : .gray)
                        }
                    }
                }
            }
        
            Divider()
        
            // Technische Details
            VStack(alignment: .leading, spacing: 12) {
                Text("Technical Details")
                    .font(.subheadline)
                    .fontWeight(.semibold)
            
                HStack {
                    DetailRow(label: "HTTP Status", value: requestResult.statusCode?.toString())
                    Spacer()
                    DetailRow(label: "Method", value: requestResult.method)
                    Spacer()
                    DetailRow(label: "Size", value: requestResult.dataSize?.formattedBytes())
                    Spacer()
                    DetailRow(label: "Duration", value: requestResult.transferDuration?.formattedDuration())
                }
            }
        
            // HTTP-Header Details
            if let headers = requestResult.headers, !headers.isEmpty {
                Divider()
            
                VStack(alignment: .leading, spacing: 12) {
                    Text("HTTP Header")
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
                    Text("Changes")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                
                    ScrollView {
                        VStack(alignment: .leading, spacing: 4) {
                            ForEach(diffInfo.changedLines, id: \.lineNumber) { changedLine in
                                ChangedLineView(changedLine: changedLine)
                            }
                        
                            if diffInfo.changedLines.count < diffInfo.totalChangedLines {
                                if diffInfo.totalChangedLines - diffInfo.changedLines.count == 1 {
                                    Text("... and 1 more change")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .italic()
                                } else {
                                    Text("... and \(diffInfo.totalChangedLines - diffInfo.changedLines.count) further changes")
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
                    Text("Content unchanged")
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
            return "Unknown"
        case .some(.transferError):
            return "Transmission Error"
        case .some(.clientError):
            return "Client Error"
        case .some(.serverError):
            return "Server Error"
        case .some(.informational):
            return "Information"
        case .some(.success(true)):
            return "Content changed"
        case .some(.success):
            return "Success"
        case .some(.redirection):
            return "Redirection"
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
    let label: LocalizedStringKey
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
            return "Lines \(changedLine.lineNumber)-\(lastLineNumber)"
        } else {
            // Einzelne Zeile
            return "Line \(changedLine.lineNumber)"
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
