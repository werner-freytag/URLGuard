import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @ObservedObject var monitor: URLMonitor
    @State private var searchText = ""
    @State private var editingItem: URLItem? = nil
    @State private var itemToDuplicate: URLItem? = nil
    @State private var dropTargetID: UUID? = nil
    @State private var dropInsertBefore: Bool = true
    @State private var rowHeights: [UUID: CGFloat] = [:]
    
    var filteredItems: [URLItem] {
        if searchText.isEmpty {
            return monitor.items
        }
        
        return monitor.items.filter { item in
            item.url.absoluteString.localizedCaseInsensitiveContains(searchText) || item.title?.localizedCaseInsensitiveContains(searchText) == true
        }
    }
    
    private var dropLineY: CGFloat? {
        guard let targetID = dropTargetID,
              let targetIndex = filteredItems.firstIndex(where: { $0.id == targetID }) else {
            return nil
        }
        
        let baseY: CGFloat
        if dropInsertBefore {
            // Linie vor dem Item - Summe aller vorherigen Höhen
            baseY = filteredItems.prefix(targetIndex).reduce(0) { sum, item in
                sum + (rowHeights[item.id] ?? 0)
            }
        } else {
            // Linie nach dem Item - Summe aller vorherigen Höhen + Höhe des aktuellen Items
            baseY = filteredItems.prefix(targetIndex + 1).reduce(0) { sum, item in
                sum + (rowHeights[item.id] ?? 0)
            }
        }
        // Zentriere die 2pt-Linie genau auf der Grenze
        return baseY - 1
    }
    
    var body: some View {
        ZStack {
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(filteredItems) { item in
                        DraggableRow(
                            item: item,
                            monitor: monitor,
                            onEdit: {
                                if let currentItem = monitor.items.first(where: { $0.id == item.id }) {
                                    editingItem = currentItem
                                } else {
                                    LoggerManager.app.error("Item nicht im Monitor gefunden für Bearbeitung: \(item.id)")
                                }
                            },
                            onDuplicate: { itemToDuplicate in
                                self.itemToDuplicate = itemToDuplicate
                            },
                            dropTargetID: $dropTargetID,
                            dropInsertBefore: $dropInsertBefore,
                            rowHeight: Binding(
                                get: { rowHeights[item.id] ?? 0 },
                                set: { rowHeights[item.id] = $0 }
                            )
                        )
                    }
                }
                .overlay(
                    Group {
                        if let lineY = dropLineY {
                            Rectangle()
                                .fill(Color.accentColor)
                                .frame(height: 2)
                                .frame(maxWidth: .infinity)
                                .offset(y: lineY)
                        }
                    }
                    .allowsHitTesting(false),
                    alignment: .topLeading
                )
            }
            .searchable(text: $searchText)
            .disabled(monitor.items.isEmpty)

            if filteredItems.isEmpty {
                if !monitor.items.isEmpty {
                    EmptyStateView(
                        title: "No entries found",
                        subtitle: "Unfortunately, no matches were found."
                    )
                } else {
                    EmptyStateView(
                        title: "No Entries Present",
                        subtitle: "Create your first entry to monitor URLs"
                    ) {
                        Button {
                            editingItem = monitor.createNewItem()
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "plus.circle")
                                Text("New Entry")
                            }
                            .padding(6)
                        }
                    }
                }
            }
        }
        .animation(.default, value: filteredItems.isEmpty)
        .frame(minWidth: 420, minHeight: 200)
        .onChange(of: monitor.maxHistoryItems) {
            monitor.trimAllHistories(to: monitor.maxHistoryItems)
        }
        .sheet(item: $editingItem) { item in
            let isNewItem = !monitor.items.contains { $0.id == item.id }
            
            ModalEditorView(
                item: item,
                monitor: monitor,
                isNewItem: isNewItem,
                onSave: { newItem in
                    monitor.addItem(newItem)
                }
            )
        }
        .sheet(item: $itemToDuplicate) { item in
            let duplicatedItem = monitor.duplicate(item: item)
            ModalEditorView(
                item: duplicatedItem,
                monitor: monitor,
                isNewItem: true,
                onSave: { newItem in
                    monitor.addItem(newItem, after: item)
                }
            )
        }
    }
}

// MARK: - DnD mit Einfügemarkierung

private struct DraggableRow: View {
    let item: URLItem
    let monitor: URLMonitor
    let onEdit: () -> Void
    let onDuplicate: (URLItem) -> Void
    @Binding var dropTargetID: UUID?
    @Binding var dropInsertBefore: Bool
    @Binding var rowHeight: CGFloat
    
    var body: some View {
        URLItemCard(item: item, monitor: monitor, onEdit: onEdit, onDuplicate: onDuplicate)
            .background(
                GeometryReader { geo in
                    Color.clear
                        .onAppear {
                            rowHeight = geo.size.height
                        }
                        .onChange(of: geo.size.height) {
                            rowHeight = geo.size.height
                        }
                }
            )
            .onDrag { NSItemProvider(object: item.id.uuidString as NSString) }
            .onDrop(
                of: [UTType.text],
                delegate: ItemDropDelegate(
                    item: item,
                    monitor: monitor,
                    rowHeight: rowHeight,
                    dropTargetID: $dropTargetID,
                    dropInsertBefore: $dropInsertBefore
                )
            )
    }
}

private struct ItemDropDelegate: DropDelegate {
    let item: URLItem
    let monitor: URLMonitor
    let rowHeight: CGFloat
    @Binding var dropTargetID: UUID?
    @Binding var dropInsertBefore: Bool
    
    func dropEntered(info: DropInfo) {
        updateIndicators(info: info)
    }
    
    func dropUpdated(info: DropInfo) -> DropProposal? {
        updateIndicators(info: info)
        return DropProposal(operation: .move)
    }
    
    func dropExited(info: DropInfo) {
        dropTargetID = nil
    }
    
    func performDrop(info: DropInfo) -> Bool {
        defer {
            dropTargetID = nil
        }
        guard let provider = info.itemProviders(for: [UTType.text]).first else { return false }
        provider.loadObject(ofClass: NSString.self) { object, _ in
            // Alle Zugriffe auf monitor.items auf den Main Thread verschieben
            DispatchQueue.main.async {
                guard let uuidString = object as? String,
                      let draggedId = UUID(uuidString: uuidString),
                      let draggedItem = monitor.items.first(where: { $0.id == draggedId }),
                      let fromIndex = monitor.items.firstIndex(of: draggedItem),
                      let baseIndex = monitor.items.firstIndex(of: item) else { return }
                
                // Konsistente Logik mit Dead Zone
                let deadZoneHeight: CGFloat = 8
                let middleY = rowHeight / 2
                let lowerBound = middleY + deadZoneHeight / 2
                
                let insertAfter = info.location.y > lowerBound
                
                // Berechne den Zielindex
                var destination: Int
                if insertAfter {
                    destination = baseIndex + 1
                } else {
                    destination = baseIndex
                }
                
                // Stelle sicher, dass der Zielindex gültig ist
                destination = max(0, min(destination, monitor.items.count))
                
                withAnimation { monitor.moveItems(from: IndexSet(integer: fromIndex), to: destination) }
            }
        }
        return true
    }
    
    private func updateIndicators(info: DropInfo) {
        // Dead Zone um die Mitte herum für stabilere Markierung
        let deadZoneHeight: CGFloat = 8 // 4 Pixel oben und unten von der Mitte
        let middleY = rowHeight / 2
        let upperBound = middleY - deadZoneHeight / 2
        let lowerBound = middleY + deadZoneHeight / 2
        
        // Nur ändern wenn wir deutlich außerhalb der Dead Zone sind
        let insertAfter = info.location.y > lowerBound
        let insertBefore = info.location.y < upperBound
        
        // Markierung nur ändern wenn wir eindeutig außerhalb der Dead Zone sind
        if insertBefore {
            dropTargetID = item.id
            dropInsertBefore = true
        } else if insertAfter {
            dropTargetID = item.id
            dropInsertBefore = false
        }
        // In der Dead Zone: Markierung bleibt unverändert
    }
}
