import SwiftUI

struct URLItemCard: View {
    let item: URLItem
    let monitor: URLMonitor
    let onEdit: () -> Void
    
    @Namespace private var ns
    
    private var isExpanded: Bool { item.isExpanded }

    var body: some View {
        VStack(alignment: .leading, spacing: isExpanded ? 4 : 0) {
            URLItemHeader(item: item, monitor: monitor, onEdit: onEdit, isExpanded: Binding(
                get: { item.isExpanded },
                set: { newValue in
                    if let index = monitor.items.firstIndex(where: { $0.id == item.id }) {
                        monitor.items[index].isExpanded = newValue
                        monitor.save()
                    }
                }
            ), ns: ns)
            
            // Trennlinie nur anzeigen, wenn der Header ausgeklappt ist
            if isExpanded {
                Rectangle()
                    .fill(Color.secondary.opacity(0.2))
                    .frame(height: 1)
                    .transition(.opacity)
                
                URLItemHistory(item: item, monitor: monitor, ns: ns)
                    .offset(isExpanded ? .zero : CGSize(width: 0, height: -16))
                    .padding(.horizontal, 16)
                    .padding(.vertical, isExpanded ? 8 : 0)
            }
        }
        .background(backgroundView)
        .overlay(highlightOverlay)
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .opacity(monitor.isGlobalPaused ? 0.5 : 1.0)
        .contextMenu {
            Button(item.isEnabled ? "Pausieren" : "Starten") {
                monitor.togglePause(for: item)
            }
            
            Divider()
            
            Button("Bearbeiten") {
                onEdit()
            }
            
            Button("Duplizieren") {
                monitor.duplicate(item: item)
            }
            
            Divider()
            
            Button("URL kopieren") {
                #if os(macOS)
                    let pb = NSPasteboard.general
                    pb.clearContents()
                    pb.setString(item.url.absoluteString, forType: .URL)
                    pb.setString(item.url.absoluteString, forType: .string)
                #else
                    UIPasteboard.general.url = item.url
                    UIPasteboard.general.string = item.url.absoluteString
                #endif
            }
            
            Divider()
            
            Button("Löschen") {
                monitor.remove(item: item)
            }
            .foregroundColor(.red)
        }
    }
    
    private var backgroundView: some View {
        RoundedRectangle(cornerRadius: 16)
            .fill(item.isEnabled ? Color.white : Color.gray.opacity(0.05))
            .stroke(.gray.opacity(0.2))
            .shadow(color: .black.opacity(0.08), radius: 4, x: 0, y: 3)
    }
    
    private var highlightOverlay: some View {
        RoundedRectangle(cornerRadius: 16)
            .stroke(
                monitor.highlightedItemID == item.id ? Color.orange : Color.clear,
                lineWidth: 3
            )
            .animation(.easeInOut(duration: 0.3), value: monitor.highlightedItemID)
    }
}

#Preview {
    let monitor = URLMonitor()
    let item = URLItem(url: URL(string: "https://example.com")!, interval: 10, isEnabled: true)
    return URLItemCard(item: item, monitor: monitor, onEdit: {})
        .frame(width: 600)
}
