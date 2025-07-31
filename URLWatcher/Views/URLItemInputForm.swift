import SwiftUI

struct URLItemInputForm: View {
    let item: URLItem
    let monitor: URLMonitor
    let onSave: (String, Double, Set<URLItem.NotificationType>) -> Void // Callback mit aktuellen Werten
    @FocusState private var focusedItemID: UUID?
    
    // Kopie des kompletten Items für lokale Bearbeitung
    @State private var localItem: URLItem
    @State private var hasBeenEdited: Bool = false
    
    init(item: URLItem, monitor: URLMonitor, onSave: @escaping (String, Double, Set<URLItem.NotificationType>) -> Void) {
        self.item = item
        self.monitor = monitor
        self.onSave = onSave
        // Erstelle eine Kopie des Items für lokale Bearbeitung
        var initialItem = item
        // Wenn es ein neuer Eintrag ist und die URL leer ist, "https://" voreintragen
        if item.isNewItem && item.urlString.isEmpty {
            initialItem.urlString = "https://"
        }
        self._localItem = State(initialValue: initialItem)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // URL, Intervall und Benachrichtigungen nebeneinander
            HStack(alignment: .top, spacing: 12) {
                // URL und Intervall links untereinander
                VStack(alignment: .leading, spacing: 12) {
                    // URL Input
                    VStack(alignment: .leading, spacing: 4) {
                        Text("URL")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        TextField("https://example.com", text: $localItem.urlString)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .focused($focusedItemID, equals: item.id)
                            .onChange(of: focusedItemID) { oldValue, newValue in
                                // Validierung nur bei onBlur (wenn Fokus verloren geht)
                                if oldValue == item.id && newValue != item.id {
                                    hasBeenEdited = true
                                    validateLocalURL()
                                }
                            }
                            .onSubmit {
                                // Automatisch "Fertig" bestätigen bei Return
                                onSave(localItem.urlString, localItem.interval, localItem.enabledNotifications)
                            }
                        
                        // URL-Fehlermeldung mit fester Höhe
                        if hasBeenEdited, let urlError = localItem.urlError {
                            Text(urlError)
                                .font(.caption)
                                .foregroundColor(.red)
                                .frame(height: 16, alignment: .topLeading)
                        } else {
                            // Platzhalter für konsistente Höhe
                            Color.clear
                                .frame(height: 16)
                        }
                    }
                    
                    // Interval Input
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Intervall (Sekunden)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        HStack {
                            TextField("5", value: $localItem.interval, formatter: NumberFormatter())
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .frame(width: 60)
                                .onChange(of: focusedItemID) { oldValue, newValue in
                                    // Validierung nur bei onBlur (wenn Fokus verloren geht)
                                    if oldValue == item.id && newValue != item.id {
                                        hasBeenEdited = true
                                        validateLocalInterval()
                                    }
                                }
                            
                            Stepper("", value: $localItem.interval, in: 1...3600, step: 1)
                                .labelsHidden()
                        }
                        
                        // Interval-Fehlermeldung mit fester Höhe
                        if hasBeenEdited, let intervalError = localItem.intervalError {
                            Text(intervalError)
                                .font(.caption)
                                .foregroundColor(.red)
                                .frame(height: 16, alignment: .topLeading)
                        } else {
                            // Platzhalter für konsistente Höhe
                            Color.clear
                                .frame(height: 16)
                        }
                    }
                }
                
                // Notification-Einstellungen rechts
                VStack(alignment: .leading, spacing: 4) {
                    Text("Benachrichtigungen")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 16)
                    
                    NotificationSettingsView(
                        item: localItem, 
                        monitor: monitor,
                        enabledNotifications: $localItem.enabledNotifications
                    )
                }
            }
        }
        .onAppear {
            // Fokussiere automatisch bei neuen Einträgen beim App-Start
            if item.isNewItem {
                focusedItemID = item.id
            }
        }
    }
    
    private func validateLocalURL() {
        let trimmedURL = localItem.urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if trimmedURL.isEmpty {
            localItem.urlError = "URL darf nicht leer sein"
        } else {
            let correctedURL = monitor.correctURL(trimmedURL)
            if let url = URL(string: correctedURL) {
                if !monitor.isValidURL(url) {
                    localItem.urlError = "Ungültige URL-Struktur"
                } else {
                    localItem.urlError = nil
                }
            } else {
                localItem.urlError = "Ungültige URL"
            }
        }
    }
    
    private func validateLocalInterval() {
        let interval = localItem.interval
        
        if interval < 1 {
            localItem.intervalError = "Intervall muss mindestens 1 Sekunde betragen"
        } else if interval > 3600 {
            localItem.intervalError = "Intervall darf maximal 3600 Sekunden (1 Stunde) betragen"
        } else {
            localItem.intervalError = nil
        }
    }
}

#Preview {
    let monitor = URLMonitor()
    let item = URLItem(urlString: "https://example.com", interval: 10, isEditing: true)
    return URLItemInputForm(item: item, monitor: monitor, onSave: {})
        .frame(width: 600)
}

#Preview("Invalid URL") {
    let monitor = URLMonitor()
    let item = URLItem(urlString: "invalid-url", interval: 10, isEditing: true, urlError: "Ungültige URL-Struktur")
    return URLItemInputForm(item: item, monitor: monitor, onSave: {})
        .frame(width: 600)
} 
