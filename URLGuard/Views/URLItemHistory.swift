import Combine
import SwiftUI

struct URLItemHistory: View {
    let item: URLItem
    @ObservedObject var monitor: URLMonitor
    let ns: Namespace.ID?
    
    @State private var visibleHistory: [HistoryEntry] = []

    init(item: URLItem, monitor: URLMonitor, ns: Namespace.ID? = nil) {
        self.item = item
        self.monitor = monitor
        self.ns = ns
    }
    
    var body: some View {
        let view = HStack(alignment: .center, spacing: 12) {
            GeometryReader { geo in
                HStack(spacing: 4) {
                    HStack(spacing: 1) {
                        ForEach(Array(visibleHistory.enumerated()), id: \.element.id) { index, entry in
                            HistoryEntryView(item: item, entry: .constant(entry), monitor: monitor)
                        }
                    }
                    
                    CountdownView(item: item, monitor: monitor)
                }
                .frame(height: 24)
                .frame(maxWidth: .infinity, alignment: .leading)
                .onAppear {
                    updateVisibleHistory(for: geo.size.width)
                }
                .onChange(of: geo.size.width) {
                    updateVisibleHistory(for: geo.size.width)
                }
                .onChange(of: item.history) {
                    updateVisibleHistory(for: geo.size.width)
                }
                .onChange(of: item.isEnabled) {
                    updateVisibleHistory(for: geo.size.width)
                }
            }
            
            let markedCount = item.history.markedCount

            if markedCount > 0 {
                Button(action: {
                    guard monitor.items.contains(where: { $0.id == item.id }) else { return }
                    monitor.unmarkAll(for: item)
                }) {
                    Text("\(markedCount)")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.red)
                        )
                        .frame(height: 16)
                        .fixedSize()
                }
                .buttonStyle(PlainButtonStyle())
                .help("Alle Markierungen entfernen")
            }
        }
        .frame(height: 24)

        if let ns {
            view.matchedGeometryEffect(id: "item history", in: ns)
        } else {
            view
        }
    }
    
    /// Aktualisiert die sichtbare Historie basierend auf der verfügbaren Breite
    private func updateVisibleHistory(for width: CGFloat) {
        let availableWidth = width - "\(Int(item.interval))".width(using: .caption) - 4
        let entryWidth: CGFloat = 11 // Breite eines History-Eintrags
        let maxVisibleEntries = max(1, Int(availableWidth / entryWidth))
        
        visibleHistory = item.history.reducedToMaxSizeIncludingGaps(maxVisibleEntries)
    }
}

struct CountdownView: View {
    let item: URLItem
    @ObservedObject var monitor: URLMonitor

    var body: some View {
        if item.isEnabled {
            if monitor.isWaiting(for: item.id) {
                // ProgressView während Request
                ProgressView()
                    .scaleEffect(0.3)
                    .frame(width: 10, height: 10)
            } else if monitor.getRemainingTime(for: item.id) > 0 {
                // Countdown zwischen Requests - klickbar für sofortigen Request
                Button(action: {
                    guard monitor.items.contains(where: { $0.id == item.id }) else { return }
                    monitor.setRemainingTime(0, for: item.id)
                }) {
                    Text("\(Int(monitor.getRemainingTime(for: item.id)))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .help("Klicken für sofortigen Request")
            }
        } else {
            Image(systemName: "pause.fill")
                .font(.caption)
                .opacity(0.5)
        }
    }
}

#Preview {
    let monitor = URLMonitor()
    let item = URLItem(url: URL(string: "https://example.com")!, interval: 10)
    URLItemHistory(item: item, monitor: monitor)
        .frame(width: 600, height: 200)
}

private extension HistoryEntry {
    var id: UUID {
        switch self {
        case .requestResult(let id, _, _):
            return id
        case .gap:
            return UUID() // Gap-Elemente haben keine echte ID
        }
    }
}
