import SwiftUI

struct HistoryEntryView: View {
    private let item: URLItem
    @Binding private var entry: HistoryEntry
    private let monitor: URLMonitor

    @State private var isPopoverOpen: Bool
    private let onPopoverChange: ((Bool) -> Void)?

    init(item: URLItem, entry: Binding<HistoryEntry>, monitor: URLMonitor, isPopoverOpen: Bool = false, onPopoverChange: ((Bool) -> Void)? = nil) {
        self.item = item
        self._entry = entry
        self.monitor = monitor
        self.isPopoverOpen = isPopoverOpen
        self.onPopoverChange = onPopoverChange
    }

    private var entryIndex: Int? {
        item.history.firstIndex(of: entry)
    }

    var body: some View {
        if case .gap = entry {
            // Gap-Element anzeigen
            VStack(spacing: 2) {
                Spacer()
                    .frame(height: 3)
                Text("…")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .frame(height: 10)
                Spacer()
                    .frame(height: 3)
            }
        }
        else if case .requestResult(_, let requestResult, var isMarked) = entry {
            // Normaler History-Eintrag
            Button(action: {
                isPopoverOpen = true
                onPopoverChange?(true)
            }) {
                VStack(spacing: 2) {
                    Circle()
                        .fill(isMarked ? Color.red : Color.clear)
                        .frame(width: 3, height: 3)
                    RoundedRectangle(cornerRadius: 2)
                        .fill(requestResult.statusColor)
                        .frame(width: 10, height: 10)
                    Spacer()
                        .frame(height: 3)
                }
            }
            .buttonStyle(.plain)
            .popover(isPresented: $isPopoverOpen, attachmentAnchor: .rect(.bounds), arrowEdge: .bottom) {
                HistoryDetailView(requestResult: requestResult, isMarked: isMarked, markerAction: {
                    if let entryIndex {
                        monitor.toggleHistoryEntryMark(for: item, at: entryIndex)
                    }
                })
                .frame(width: 400, height: calculatePopoverHeight(for: requestResult))
                .presentationBackground(Color.controlBackgroundColor)
                .presentationCornerRadius(0)
                .onDisappear {
                    onPopoverChange?(false)
                }
            }
        }
    }
}

// Hilfsfunktionen für Popover-Größe
private func calculatePopoverHeight(for entry: RequestResult) -> CGFloat {
    var height: CGFloat = 156 // Basis-Höhe für technische Details

    if entry.status == .success(hasChanges: false) || entry.errorDescription != nil {
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
