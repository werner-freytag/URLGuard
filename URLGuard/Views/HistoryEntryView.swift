import SwiftUI

struct HistoryEntryView: View {
    let item: URLItem
    let entryIndex: Int
    @State private var showPopover = false
    @ObservedObject var monitor: URLMonitor

    private var entry: HistoryEntry {
        item.history[entryIndex]
    }

    var body: some View {
        if case .gap = entry {
            // Gap-Element anzeigen
            VStack(spacing: 2) {
                Circle()
                    .fill(Color.clear)
                    .frame(width: 3, height: 3)
                Text("…")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .frame(width: 10, height: 10)
                Spacer(minLength: 3)
            }
        }
        else if case .requestResult(_, let requestResult, let isMarked) = entry {
            // Normaler History-Eintrag
            Button(action: {
                showPopover = true
            }) {
                VStack(spacing: 2) {
                    Circle()
                        .fill(isMarked ? Color.red : Color.clear)
                        .frame(width: 3, height: 3)
                    RoundedRectangle(cornerRadius: 2)
                        .fill(requestResult.statusColor)
                        .frame(width: 10, height: 10)
                    Spacer(minLength: 3)
                }
            }
            .buttonStyle(.plain)
            .popover(isPresented: $showPopover, attachmentAnchor: .rect(.bounds), arrowEdge: .bottom) {
                HistoryDetailView(requestResult: requestResult, isMarked: isMarked, markerAction: { monitor.toggleHistoryEntryMark(for: item, at: entryIndex) })
                    .frame(width: 400, height: calculatePopoverHeight(for: requestResult))
                    .presentationBackground(Color.controlBackgroundColor)
                    .presentationCornerRadius(0)
            }
        }
    }
}

// Hilfsfunktionen für Popover-Größe
private func calculatePopoverHeight(for entry: RequestResult) -> CGFloat {
    var height: CGFloat = 156 // Basis-Höhe für technische Details

    if entry.status == .success(hasChanges: false) {
        height += 44
    }
    
    // Zusätzliche Höhe für Diff-Informationen
    if let diffInfo = entry.diffInfo, diffInfo.totalChangedLines > 0 {
        height += 200
    }

    // Zusätzliche Höhe für Header
    if let headers = entry.headers, !headers.isEmpty {
        let headerHeight = min(CGFloat(headers.count) * 17, 200)
        height += headerHeight + 50
    }

    return height
}
