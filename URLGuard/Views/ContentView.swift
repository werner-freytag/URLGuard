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
        VStack {
            if filteredItems.isEmpty {
                if !monitor.items.isEmpty {
                    EmptyStateView(
                        icon: "magnifyingglass",
                        title: "Keine Einträge gefunden",
                        subtitle: "Für '\(searchText)' wurden keine Übereinstimmung gefunden"
                    )
                } else {
                    EmptyStateView(
                        icon: "plus.circle",
                        title: "Keine Einträge vorhanden",
                        subtitle: "Erstellen Sie Ihren ersten Eintrag, um URLs zu überwachen"
                    ) {
                        IconButton(
                            icon: "plus",
                            title: "Neuer Eintrag",
                            color: .blue
                        ) {
                            editingItem = monitor.createNewItem()
                        }
                    }
                }
            } else {
                List {
                    ForEach(filteredItems) { item in
                        URLItemCard(item: item, monitor: monitor, onEdit: {
                            if let currentItem = monitor.items.first(where: { $0.id == item.id }) {
                                editingItem = currentItem
                            } else {
                                print("Item nicht im Monitor gefunden für Bearbeitung: \(item.id)")
                            }
                        })
                        .listRowSeparator(.hidden)
                    }
                    .onMove { from, to in
                        monitor.moveItems(from: from, to: to)
                    }
                }
                .listStyle(PlainListStyle())
            }
        }
        .frame(minWidth: 420, minHeight: 200)
        .searchable(text: $searchText, prompt: "URLs durchsuchen...")
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
