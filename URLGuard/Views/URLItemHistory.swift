import SwiftUI
import Combine

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
                        ForEach(item.history) { entry in
                            HistoryEntryView(entry: entry)
                        }

                        CountdownView(item: .constant(item), monitor: monitor)
                            .id("countdown")
                    }
                    .padding(.trailing, 8) // Abstand am Ende für bessere Optik
                }
                .frame(height: 12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .onChange(of: item.history) { oldCount, newCount in
                    withAnimation(.easeInOut(duration: 0.3)) {
                        proxy.scrollTo("countdown", anchor: .trailing)
                    }
                }
            }
            
            Spacer()
            
            Button(action: {
                guard monitor.items.contains(where: { $0.id == item.id }) else { return }
                monitor.resetHistory(for: item)
            }) {
                Image(systemName: "arrow.clockwise")
                    .font(.caption)
            }
            .buttonStyle(PlainButtonStyle())
            .help("Historie leeren")
        }
        .padding(16)
        .opacity(item.isEnabled ? 1.0 : 0.5)
    }
}

struct CountdownView: View {
    @Binding var item: URLItem
    @ObservedObject var monitor: URLMonitor
    
    var body: some View {
        if item.isEnabled {
            if monitor.isWaiting(for: item.id) {
                // ProgressView während Request
                ProgressView()
                    .scaleEffect(0.3)
                    .frame(width: 10, height: 10)
                    .padding(.horizontal, 2)
            } else if monitor.getRemainingTime(for: item.id) > 0 {
                // Countdown zwischen Requests
                Text("\(Int(monitor.getRemainingTime(for: item.id)))")
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


private extension URLItem.HistoryEntry {
    var statusColor: Color {
        switch status {
        case .success: return .green
        case .changed: return .blue
        case .error: return .red
        }
    }
}

struct HistoryEntryView: View {
    @State var entry: URLItem.HistoryEntry
    @State private var showPopover = false

    var body: some View {
        Button(action: {
            showPopover = true
        }) {
            RoundedRectangle(cornerRadius: 2)
                .fill(entry.statusColor)
                .frame(width: 10, height: 10)
        }
        .buttonStyle(.plain)
        .popover(isPresented: $showPopover, attachmentAnchor: .rect(.bounds), arrowEdge: .bottom) {
            HistoryDetailView(entry: entry)
                .frame(width: 400, height: entry.status == .changed ? 400 : 200)
                .presentationBackground(Color(.controlBackgroundColor))
                .presentationCornerRadius(0)
        }
    }
}

#Preview {
    let monitor = URLMonitor()
    let item = URLItem(url: URL(string: "https://example.com")!, interval: 10)
    URLItemHistory(item: item, monitor: monitor)
        .frame(width: 600, height: 200)
}

