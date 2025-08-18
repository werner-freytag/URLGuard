import SwiftUI

struct URLItemCard: View {
    let item: URLItem
    let monitor: URLMonitor
    let onEdit: () -> Void
    let onDuplicate: (URLItem) -> Void
    
    @Namespace private var ns
    
    private var isExpanded: Bool { !monitor.isCompactViewMode }

    var body: some View {
        VStack(alignment: .leading, spacing: isExpanded ? 4 : 0) {
            URLItemHeader(item: item, monitor: monitor, onEdit: onEdit, onDuplicate: onDuplicate, ns: ns)
            
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
        .padding(.horizontal, isExpanded ? 16 : 0)
        .padding(.vertical, isExpanded ? 8 : 0)
        .opacity(monitor.isGlobalPaused ? 0.5 : 1.0)
        .opacity(item.isEnabled ? 1 : 0.5)
        .contextMenu {
            Button(item.isEnabled ? "Pause" : "Start") {
                monitor.togglePause(for: item)
            }
            
            Divider()
            
            Button("Edit") {
                onEdit()
            }
            
            Button("Duplicate") {
                onDuplicate(item)
            }
            
            Divider()
            
            Button("Copy URL") {
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
            
            Button("Delete") {
                monitor.remove(item: item)
            }
            .foregroundColor(.red)
        }
    }
    
    private var backgroundView: some View {
        RoundedRectangle(cornerRadius: isExpanded ? 16 : 0)
            .fill(.white)
            .stroke(.gray.opacity(0.2))
    }
    
    private var highlightOverlay: some View {
        RoundedRectangle(cornerRadius: isExpanded ? 16 : 0)
            .inset(by: 1.5)
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
    return URLItemCard(item: item, monitor: monitor, onEdit: {}, onDuplicate: { _ in })
        .frame(width: 600)
}
