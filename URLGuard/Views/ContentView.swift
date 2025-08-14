import SwiftUI

struct ContentView: View {
    @ObservedObject var monitor: URLMonitor
    @State private var searchText = ""
    @State private var editingItem: URLItem? = nil
    
    var filteredItems: [URLItem] {
        if searchText.isEmpty {
            return monitor.items
        }
        
        return monitor.items.filter { item in
            item.url.absoluteString.localizedCaseInsensitiveContains(searchText) || item.title?.localizedCaseInsensitiveContains(searchText) == true
        }
    }
    
    var body: some View {
        ZStack {
            List {
                ForEach(filteredItems) { item in
                    URLItemCard(item: item, monitor: monitor, onEdit: {
                        if let currentItem = monitor.items.first(where: { $0.id == item.id }) {
                            editingItem = currentItem
                        } else {
                            LoggerManager.app.error("Item nicht im Monitor gefunden für Bearbeitung: \(item.id)")
                        }
                    })
                    .listRowSeparator(.hidden)
                }
                .onMove { from, to in
                    monitor.moveItems(from: from, to: to)
                }
            }
            .listStyle(PlainListStyle())
            .searchable(text: $searchText)
            .disabled(monitor.items.isEmpty)

            if filteredItems.isEmpty {
                if !monitor.items.isEmpty {
                    EmptyStateView(
                        title: "Keine Einträge gefunden",
                        subtitle: "Leider wurden keine Übereinstimmung gefunden"
                    )
                } else {
                    EmptyStateView(
                        title: "Keine Einträge vorhanden",
                        subtitle: "Erstellen Sie Ihren ersten Eintrag, um URLs zu überwachen"
                    ) {
                        Button {
                            editingItem = monitor.createNewItem()
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "plus.circle")
                                Text("Neuer Eintrag")
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
            // Prüfe ob es ein neues Item ist (nicht in der Liste vorhanden)
            let isNewItem = !monitor.items.contains { $0.id == item.id }
            
            ModalEditorView(
                item: item, 
                monitor: monitor, 
                isNewItem: isNewItem,
                onSave: { newItem in
                    // Neues Item hinzufügen
                    monitor.addItem(newItem)
                }
            )
        }
    }
}

#Preview {
    ContentView(monitor: URLMonitor())
}
