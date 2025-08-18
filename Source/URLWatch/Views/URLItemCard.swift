import SwiftUI

struct URLItemCard: View {
    let item: URLItem
    let monitor: URLMonitor
    let onEdit: () -> Void
    
    @Namespace private var ns
    
    private var isExpanded: Bool { !monitor.isCompactViewMode }

    var body: some View {
        VStack(alignment: .leading, spacing: isExpanded ? 4 : 0) {
            URLItemHeader(item: item, monitor: monitor, onEdit: onEdit, ns: ns)
            
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
        .contextMenu {
            Button(item.isEnabled ? "Pause" : "Start") {
                monitor.togglePause(for: item)
            }
            
            Divider()
            
            Button("Edit") {
                onEdit()
            }
            
            Button("Duplicate") {
                monitor.duplicate(item: item)
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
            .fill(item.isEnabled ? Color.white : Color(white: 0.975))
            .stroke(true || isExpanded ? .gray.opacity(0.2) : .clear)
            .shadow(color: isExpanded ? Color.black.opacity(0.08) : .clear, radius: 4, x: 0, y: 3)
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
