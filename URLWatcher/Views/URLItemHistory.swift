import SwiftUI

struct URLItemHistory: View {
    let item: URLItem
    let monitor: URLMonitor
    @State private var scrollToEnd = false
    @State private var selectedEntry: URLItem.HistoryEntry? = nil
    @State private var showingDetailPopover = false
    
    var body: some View {

        HStack(alignment: .top, spacing: 12) {

            ScrollViewReader { proxy in
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 1) {
                        ForEach(item.history.reversed()) { entry in
                            RoundedRectangle(cornerRadius: 2)
                                .fill(color(for: entry.status))
                                .frame(width: 10, height: 10)
                                .opacity(item.isEnabled ? 1.0 : 0.6) // Kräftiger wenn aktiviert
                                .cornerRadius(3)
                                .border(showingDetailPopover && entry == selectedEntry ? Color.black : .clear)
                                .onHover { hovering in
                                    if hovering {
                                        showingDetailPopover = true
                                        selectedEntry = entry
                                    }
                                }
                                .id(entry.date)
                        }
                        .popover(item: $selectedEntry, attachmentAnchor: .rect(.bounds)) { entry in
                            if let entry = selectedEntry {
                                HistoryDetailView(entry: entry)
                                    .frame(width: 400, height: 300)
                                    .presentationBackground(Color(.controlBackgroundColor))
                                    .presentationCornerRadius(0)
                            }
                        }

                        CountdownView(item: item)
                    }
                    .padding(.trailing, 8) // Abstand am Ende für bessere Optik
                }
                .frame(height: 12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .onChange(of: item.history) { oldCount, newCount in
                    if let firstEntry = item.history.first {
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
}

struct CountdownView: View {
    @State var item: URLItem
    
    var body: some View {
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
            Text("Angehalten")
                .font(.caption)
                .foregroundColor(.secondary.opacity(0.5))
                .padding(.horizontal, 4)
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
