import SwiftUI

struct URLItemHeader: View {
    let item: URLItem
    let monitor: URLMonitor
    let onEdit: () -> Void
    @Binding var isExpanded: Bool
    let ns: Namespace.ID
    
    var body: some View {
        HStack {
            Button {
                guard monitor.items.contains(where: { $0.id == item.id }) else { return }
                monitor.togglePause(for: item)
            } label: {
                Image(systemName: item.isEnabled ? "pause.circle.fill" : "play.circle.fill")
                    .foregroundColor(.secondary)
                    .font(.title2)
            }
            .buttonStyle(.plain)
            .padding(6)
            .help(item.isEnabled ? "Pausieren" : "Starten")

            VStack(alignment: .leading, spacing: isExpanded ? 4 : 8) {
                TitleView(item: item, isExpanded: $isExpanded)
                
                if isExpanded {
                    SublineView(item: item)
                } else {
                    URLItemHistory(item: item, monitor: monitor, ns: ns)
                }
            }
            
            Spacer()
            
            if isExpanded {
                HStack(spacing: 8) {
                    ActionButton(
                        icon: "square.and.pencil",
                        title: "Bearbeiten",
                        color: .blue
                    ) {
                        onEdit()
                    }
                    
                    ActionButton(
                        icon: "plus.square.on.square",
                        title: "Duplizieren",
                        color: .secondary
                    ) {
                        guard monitor.items.contains(where: { $0.id == item.id }) else { return }
                        monitor.duplicate(item: item)
                    }
                    
                    ActionButton(
                        icon: "trash",
                        title: "Löschen",
                        color: .red
                    ) {
                        guard monitor.items.contains(where: { $0.id == item.id }) else { return }
                        monitor.remove(item: item)
                    }
                }
                .offset(y: -6)
            }
        }
        .padding(12)
        .onTapGesture(count: 2) {
            onEdit()
        }
    }
}

private struct Title: View {
    let item: URLItem

    var body: some View {
        if let title = item.title, !title.isEmpty {
            // Benutzerdefinierter Titel
            Text(title)
                .font(.headline)
                .fontWeight(.bold)
                .lineLimit(1)
                .truncationMode(.middle)
                .foregroundColor(item.isEnabled ? .primary : .secondary)
        } else if let host = item.url.host {
            // URL-Komponenten anzeigen
            HStack(spacing: 4) {
                Text(host)
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(item.isEnabled ? .primary : .secondary)
                
                if !item.url.lastPathComponent.isEmpty {
                    Text(" – ")
                        .font(.headline)
                        .fontWeight(.regular)
                        .foregroundColor(item.isEnabled ? .primary.opacity(0.6) : .secondary.opacity(0.6))
                    
                    Text(item.url.lastPathComponent)
                        .font(.headline)
                        .fontWeight(.regular)
                        .foregroundColor(item.isEnabled ? .primary.opacity(0.6) : .secondary.opacity(0.6))
                }
            }
            .lineLimit(1)
            .truncationMode(.middle)
        } else {
            // Fallback
            Text(item.url.absoluteString)
                .font(.headline)
                .fontWeight(.bold)
                .lineLimit(1)
                .truncationMode(.middle)
                .foregroundColor(item.isEnabled ? .primary : .secondary)
        }
    }
}

private struct TitleView: View {
    let item: URLItem
    @Binding var isExpanded: Bool

    var body: some View {
        HStack(spacing: 4) {
            Title(item: item)
            
            Image(systemName: "chevron.down")
                .font(.caption)
                .foregroundColor(.secondary)
                .rotationEffect(.degrees(isExpanded ? 0 : -90))
                .animation(.easeInOut(duration: 0.3), value: isExpanded)
                .help(isExpanded ? "Einklappen" : "Ausklappen")
        }
        .onTapGesture {
            withAnimation(.easeInOut(duration: 0.3)) {
                isExpanded.toggle()
            }
        }
    }
}

private struct SublineView: View {
    let item: URLItem
    
    var body: some View {
        HStack(spacing: 4) {
            Text(item.url.absoluteString)
                .lineLimit(1)
                .truncationMode(.middle)
                .textSelection(.enabled)
            
            HStack(spacing: 2) {
                Image(systemName: "clock")
                Text("\(Int(item.interval))s")
            }
            
            let notificationTypesText = item.enabledNotifications.map(\.displayName).joined(separator: ", ")

            if !notificationTypesText.isEmpty {
                HStack(spacing: 2) {
                    Image(systemName: "bell")
                    Text(notificationTypesText)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
            }
        }
        .font(.caption)
        .foregroundColor(.secondary)
        .transition(.asymmetric(
            insertion: .opacity.combined(with: .move(edge: .top)),
            removal: .opacity.combined(with: .move(edge: .top))
        ))
    }
}

private extension URLItem.NotificationType {
    var displayName: String {
        switch self {
        case .success:
            return "Erfolg"
        case .error:
            return "Fehler"
        case .change:
            return "Änderung"
        case .httpCode(let code):
            return "HTTP \(code)"
        }
    }
}
