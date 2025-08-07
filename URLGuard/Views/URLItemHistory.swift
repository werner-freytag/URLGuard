import Combine
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
                        ForEach(Array(item.history.enumerated()), id: \.element.id) { index, entry in
                            HistoryEntryView(entryIndex: index, monitor: monitor, item: item)
                        }

                        CountdownView(item: item, monitor: monitor)
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

            let unreadCount = item.history.filter { $0.isUnread && $0.hasNotification }.count

            if unreadCount > 0 {
                Button(action: {
                    guard monitor.items.contains(where: { $0.id == item.id }) else { return }
                    monitor.markAllAsRead(for: item)
                }) {
                    ZStack {
                        Circle()
                            .fill(Color.red)
                            .frame(width: 16, height: 16)

                        Text("\(unreadCount)")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.white)
                    }
                }
                .buttonStyle(PlainButtonStyle())
                .help("Alle als gelesen markieren")
            } else {
                Rectangle()
                    .fill(Color.clear)
                    .frame(height: 16)
            }
        }
        .frame(height: 24)
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
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
                    .padding(.horizontal, 2)
            } else if monitor.getRemainingTime(for: item.id) > 0 {
                // Countdown zwischen Requests - klickbar für sofortigen Request
                Button(action: {
                    guard monitor.items.contains(where: { $0.id == item.id }) else { return }
                    monitor.setRemainingTime(0, for: item.id)
                }) {
                    Text("\(Int(monitor.getRemainingTime(for: item.id)))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 4)
                }
                .buttonStyle(.plain)
                .help("Klicken für sofortigen Request")
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
    let item = URLItem(url: URL(string: "https://example.com")!, interval: 10)
    URLItemHistory(item: item, monitor: monitor)
        .frame(width: 600, height: 200)
}
