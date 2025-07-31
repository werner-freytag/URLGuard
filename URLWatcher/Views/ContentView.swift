import SwiftUI

struct ContentView: View {
    @ObservedObject var monitor: URLMonitor
    @State private var searchText = ""
    @State private var editingItem: URLItem? = nil
    
    var filteredItems: [URLItem] {
        // Filtere zuerst isNewItem Einträge heraus
        let nonNewItems = monitor.items.filter { !$0.isNewItem }
        
        if searchText.isEmpty {
            return nonNewItems
        } else {
            return nonNewItems.filter { item in
                item.urlString.localizedCaseInsensitiveContains(searchText)
            }
        }
    }
    
    var hasAnyItems: Bool {
        // Prüfe ob überhaupt Einträge vorhanden sind (ohne Filter)
        return !monitor.items.filter { !$0.isNewItem }.isEmpty
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
                        // Neuen Eintrag hinzufügen und sofort bearbeiten
                        monitor.addNewItem()
                        if let newItem = monitor.items.first {
                            editingItem = newItem
                        }
                    })
                }
            } else {
                List {
                    ForEach(filteredItems) { item in
                        URLItemCard(item: item, monitor: monitor, onEdit: {
                            editingItem = item
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
            ModalEditorView(item: item, monitor: monitor)
        }
        .onChange(of: monitor.items) { oldItems, newItems in
            // Wenn ein neuer Eintrag hinzugefügt wurde, öffne das Modal
            if newItems.count > oldItems.count {
                if let newItem = newItems.first(where: { $0.isNewItem }) {
                    editingItem = newItem
                }
            }
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
                print("Eintrag erstellen Button geklickt")
                onNewItem()
                print("Neue Items Anzahl: \(monitor.items.count)")
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
