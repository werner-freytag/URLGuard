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
            item.url.absoluteString.localizedCaseInsensitiveContains(searchText)
        }
    }
    
    var hasAnyItems: Bool {
        // Prüfe ob überhaupt Einträge vorhanden sind
        return !monitor.items.isEmpty
    }
    
    var body: some View {
        VStack {
            // Hauptinhalt
            if filteredItems.isEmpty {
                if hasAnyItems {
                    // Einträge vorhanden, aber Filter zeigt keine Ergebnisse
                    NoSearchResultsView(searchText: searchText)
                } else {
                    // Keine Einträge vorhanden
                    EmptyStateView(monitor: monitor, onNewItem: {
                        editingItem = monitor.createNewItem()
                    })
                }
            } else {
                List {
                    ForEach(filteredItems) { item in
                        URLItemCard(item: item, monitor: monitor, onEdit: {
                            // Verwende das aktuelle Item aus dem Monitor
                            if let currentItem = monitor.items.first(where: { $0.id == item.id }) {
                                editingItem = currentItem
                            } else {
                                print("Item nicht im Monitor gefunden für Bearbeitung: \(item.id)")
                            }
                        })
                        .listRowInsets(EdgeInsets())
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                    }
                    .onMove { from, to in
                        monitor.moveItems(from: from, to: to)
                    }
                }
                .listStyle(PlainListStyle())
            }
        }
        .frame(minWidth: 600, minHeight: 400)
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

struct EmptyStateView: View {
    @ObservedObject var monitor: URLMonitor
    var onNewItem: () -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            // Icon
            Image(systemName: "plus.circle")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            
            // Text
            VStack(spacing: 8) {
                Text("Keine URL-Einträge vorhanden")
                    .font(.title2)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                
                Text("Erstellen Sie Ihren ersten Eintrag, um URLs zu überwachen")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            // Button
            Button(action: {
                onNewItem()
            }) {
                HStack(spacing: 8) {
                    Image(systemName: "plus.circle.fill")
                        .font(.title3)
                    Text("Eintrag erstellen")
                        .font(.body)
                }
                .foregroundColor(.blue)
            }
            .buttonStyle(.bordered)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.controlBackgroundColor))
    }
}

struct NoSearchResultsView: View {
    let searchText: String
    
    var body: some View {
        VStack(spacing: 20) {
            // Icon
            Image(systemName: "magnifyingglass")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            
            // Text
            VStack(spacing: 8) {
                Text("Keine Einträge gefunden")
                    .font(.title2)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                
                Text("Für '\(searchText)' wurden keine übereinstimmenden URLs gefunden")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.controlBackgroundColor))
    }
}
