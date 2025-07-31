import SwiftUI

struct ModalEditorView: View {
    let item: URLItem
    let monitor: URLMonitor
    @Environment(\.dismiss) private var dismiss
    @State private var hasValidationErrors: Bool = false
    @State private var currentUrlString: String
    @State private var currentInterval: Double
    @State private var currentEnabledNotifications: Set<URLItem.NotificationType>
    
    init(item: URLItem, monitor: URLMonitor) {
        self.item = item
        self.monitor = monitor
        self._currentUrlString = State(initialValue: item.urlString)
        self._currentInterval = State(initialValue: item.interval)
        self._currentEnabledNotifications = State(initialValue: item.enabledNotifications)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text(item.isNewItem ? "Neuen URL-Eintrag erstellen" : "URL-Eintrag bearbeiten")
                    .font(.headline)
                    .fontWeight(.medium)
                
                Spacer()
            }
            .padding()
            .background(Color(.controlBackgroundColor))
            
            Divider()
            
            // Content
            ScrollView {
                VStack(spacing: 20) {
                    // Editor Content
                    URLItemInputForm(
                        item: item, 
                        monitor: monitor,
                        onSave: { urlString, interval, enabledNotifications in
                            if saveChanges(urlString: urlString, interval: interval, enabledNotifications: enabledNotifications) {
                                dismiss()
                            }
                        },
                        onValuesChanged: { urlString, interval, enabledNotifications in
                            // Aktualisiere die aktuellen Werte bei jeder Änderung
                            currentUrlString = urlString
                            currentInterval = interval
                            currentEnabledNotifications = enabledNotifications
                        },
                        onValidationRequested: { urlString, interval in
                            // Validiere die Werte und gib Fehler zurück
                            var tempItem = item
                            tempItem.urlString = urlString
                            tempItem.interval = interval
                            let validation = monitor.validateItem(tempItem)
                            return (validation.urlError, validation.intervalError)
                        }
                    )
                    .padding()
                    .onAppear {
                        // Initialisierung erfolgt bereits im init
                    }
                }
                .padding(.vertical)
            }
            
            Divider()
            
            // Footer mit Buttons
            HStack {
                Spacer()
                
                Button("Abbrechen") {
                    // Wenn es ein neuer Eintrag ist, diesen löschen
                    if item.isNewItem {
                        monitor.remove(item: item)
                    }
                    dismiss()
                }
                .buttonStyle(.bordered)
                
                Button("Fertig") {
                    // Verwende die aktuellen Werte aus den State-Variablen
                    if saveChanges(urlString: currentUrlString, interval: currentInterval, enabledNotifications: currentEnabledNotifications) {
                        dismiss()
                    }
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.return, modifiers: [])
            }
            .padding()
            .background(Color(.controlBackgroundColor))
        }
        .frame(minWidth: 600)
        .background(Color.white)
        .preferredColorScheme(.light)
    }
    
    private func saveChanges(urlString: String, interval: Double, enabledNotifications: Set<URLItem.NotificationType>) -> Bool {
        // Speichern (Validierung erfolgt bereits in URLItemInputForm)
        if item.isNewItem {
            monitor.confirmNewItemWithValues(for: item, urlString: urlString, interval: interval, enabledNotifications: enabledNotifications)
        } else if item.isEditing {
            monitor.confirmEditingWithValues(for: item, urlString: urlString, interval: interval, enabledNotifications: enabledNotifications)
        } else {
            // Fallback: Direkt speichern mit URL-Änderungsprüfung
            if let index = monitor.items.firstIndex(where: { $0.id == item.id }) {
                let correctedURL = monitor.correctURL(urlString)
                let urlChanged = monitor.items[index].urlString != correctedURL
                
                // Historie löschen, wenn sich die URL geändert hat
                if urlChanged {
                    print("🔄 URL changed from '\(monitor.items[index].urlString)' to '\(correctedURL)' - clearing history and status")
                    monitor.items[index].history.removeAll()
                    monitor.items[index].currentStatus = nil
                    // lastResponses ist private, daher können wir es hier nicht direkt löschen
                }
                
                monitor.items[index].urlString = correctedURL
                monitor.items[index].interval = interval
                monitor.items[index].enabledNotifications = enabledNotifications
                monitor.save()
            }
        }
        return true
    }
}

#Preview {
    let monitor = URLMonitor()
    let item = URLItem(urlString: "https://example.com", interval: 10, isEditing: true, isModalEditing: true)
    return ModalEditorView(item: item, monitor: monitor)
} 