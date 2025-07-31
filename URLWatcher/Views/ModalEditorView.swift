import SwiftUI

struct ModalEditorView: View {
    let item: URLItem
    let monitor: URLMonitor
    let isNewItem: Bool
    let onSave: ((URLItem) -> Void)?
    @Environment(\.dismiss) private var dismiss
    @State private var hasValidationErrors: Bool = false
    @State private var currentUrlString: String
    @State private var currentTitle: String?
    @State private var currentInterval: Double
    @State private var currentEnabledNotifications: Set<URLItem.NotificationType>
    
    init(item: URLItem, monitor: URLMonitor, isNewItem: Bool = false, onSave: ((URLItem) -> Void)? = nil) {
        self.item = item
        self.monitor = monitor
        self.isNewItem = isNewItem
        self.onSave = onSave
        self._currentUrlString = State(initialValue: item.urlString)
        self._currentTitle = State(initialValue: item.title)
        self._currentInterval = State(initialValue: item.interval)
        self._currentEnabledNotifications = State(initialValue: item.enabledNotifications)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text(isNewItem ? "Neuen URL-Eintrag erstellen" : "URL-Eintrag bearbeiten")
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
                        onSave: { urlString, title, interval, enabledNotifications in
                            if saveChanges(urlString: urlString, title: title, interval: interval, enabledNotifications: enabledNotifications) {
                                dismiss()
                            }
                        },
                        onValuesChanged: { urlString, title, interval, enabledNotifications in
                            // Aktualisiere die aktuellen Werte bei jeder Änderung
                            currentUrlString = urlString
                            currentTitle = title
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
                    // Bei neuen Items wird nichts gelöscht, da sie nicht gespeichert sind
                    dismiss()
                }
                .buttonStyle(.bordered)
                
                Button("Fertig") {
                    // Verwende die aktuellen Werte aus den State-Variablen
                    if saveChanges(urlString: currentUrlString, title: currentTitle, interval: currentInterval, enabledNotifications: currentEnabledNotifications) {
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
    
    private func saveChanges(urlString: String, title: String?, interval: Double, enabledNotifications: Set<URLItem.NotificationType>) -> Bool {
        // URL korrigieren
        let correctedURL = monitor.correctURL(urlString)
        
        if isNewItem {
            // Neues Item erstellen und über Callback zurückgeben
            var newItem = item
            newItem.urlString = correctedURL
            newItem.title = title
            newItem.interval = interval
            newItem.enabledNotifications = enabledNotifications
            
            // Validiere das Item
            let validation = monitor.validateItem(newItem)
            if validation.isValid {
                onSave?(newItem)
                return true
            } else {
                return false
            }
        } else {
            // Existierendes Item bearbeiten - finde das aktuelle Item im Monitor
            if let currentItem = monitor.items.first(where: { $0.id == item.id }) {
                monitor.confirmEditingWithValues(for: currentItem, urlString: correctedURL, title: title, interval: interval, enabledNotifications: enabledNotifications)
                return true
            } else {
                print("❌ Item nicht im Monitor gefunden: \(item.id)")
                return false
            }
        }
    }
}

#Preview {
    let monitor = URLMonitor()
    let item = URLItem(urlString: "https://example.com", interval: 10, isEditing: true, isModalEditing: true)
    return ModalEditorView(
        item: item, 
        monitor: monitor, 
        isNewItem: false,
        onSave: { _ in }
    )
} 