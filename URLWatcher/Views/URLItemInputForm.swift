import SwiftUI

struct URLItemInputForm: View {
    let item: URLItem
    let monitor: URLMonitor
    let onSave: (String, String?, Double, Bool, Set<URLItem.NotificationType>) -> Void // Callback mit aktuellen Werten
    let onValuesChanged: (String, String?, Double, Bool, Set<URLItem.NotificationType>) -> Void // Callback für Wertänderungen
    let onValidationRequested: (String, Double) -> (urlError: String?, intervalError: String?) // Callback für Validierung
    @FocusState private var focusedItemID: UUID?
    
    // Kopie des kompletten Items für lokale Bearbeitung
    @State private var localItem: URLItem
    @State private var hasBeenEdited: Bool = false
    
    // Lokale Fehlermeldungen
    @State private var urlError: String?
    @State private var intervalError: String?
    
    init(item: URLItem, monitor: URLMonitor, onSave: @escaping (String, String?, Double, Bool, Set<URLItem.NotificationType>) -> Void, onValuesChanged: @escaping (String, String?, Double, Bool, Set<URLItem.NotificationType>) -> Void, onValidationRequested: @escaping (String, Double) -> (urlError: String?, intervalError: String?)) {
        self.item = item
        self.monitor = monitor
        self.onSave = onSave
        self.onValuesChanged = onValuesChanged
        self.onValidationRequested = onValidationRequested
        // Erstelle eine Kopie des Items für lokale Bearbeitung
        var initialItem = item
                    // Wenn die URL leer ist, "https://" voreintragen
            if item.urlString.isEmpty {
                initialItem.urlString = "https://"
            }
        self._localItem = State(initialValue: initialItem)
    }
    
    private var titlePlaceholder: String {
        if !localItem.urlString.isEmpty && localItem.urlString != "https://" {
            // Host + letzte Pfadkomponente als Platzhalter verwenden
            let correctedURL = localItem.urlString.hasPrefix("http") ? localItem.urlString : "https://" + localItem.urlString
            
            if let url = URL(string: correctedURL), let host = url.host {
                let path = url.path
                if !path.isEmpty && path != "/" {
                    let pathComponents = path.components(separatedBy: "/").filter { !$0.isEmpty }
                    if let lastComponent = pathComponents.last {
                        return "\(host) - \(lastComponent)"
                    }
                }
                // Nur Host falls kein Pfad
                return host
            }
            
            // Fallback: URL verwenden
            return localItem.urlString
        } else {
            return "Titel eingeben..."
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // URL, Intervall und Benachrichtigungen nebeneinander
            HStack(alignment: .top, spacing: 12) {
                // URL, Titel und Intervall links untereinander
                VStack(alignment: .leading, spacing: 12) {
                    
                    
                    // Titel Input
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Titel (optional)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        TextField(titlePlaceholder, text: Binding(
                            get: { localItem.title ?? "" },
                            set: { localItem.title = $0.isEmpty ? nil : $0 }
                        ))
                        .onChange(of: localItem.urlString) { oldValue, newValue in
                            // Platzhalter wird automatisch aktualisiert durch titlePlaceholder
                        }
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .onChange(of: localItem.title) { oldValue, newValue in
                            // Benachrichtige über Wertänderung
                            onValuesChanged(localItem.urlString, localItem.title, localItem.interval, localItem.isEnabled, localItem.enabledNotifications)
                        }
                    }
                    
                    // URL Input
                    VStack(alignment: .leading, spacing: 4) {
                        Text("URL")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        TextField("https://example.com", text: $localItem.urlString)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .focused($focusedItemID, equals: item.id)
                            .onChange(of: localItem.urlString) { oldValue, newValue in
                                // Benachrichtige über Wertänderung
                                onValuesChanged(newValue, localItem.title, localItem.interval, localItem.isEnabled, localItem.enabledNotifications)
                            }
                            .onChange(of: focusedItemID) { oldValue, newValue in
                                // Validierung nur bei onBlur (wenn Fokus verloren geht)
                                if oldValue == item.id && newValue != item.id {
                                    hasBeenEdited = true
                                    validateLocalURL()
                                }
                            }
                            .onSubmit {
                                // Validiere vor dem Speichern
                                hasBeenEdited = true
                                validateLocalURL()
                                validateLocalInterval()
                                
                                // Nur speichern wenn keine Fehler vorhanden
                                if urlError == nil && intervalError == nil {
                                    onSave(localItem.urlString, localItem.title, localItem.interval, localItem.isEnabled, localItem.enabledNotifications)
                                } else {
                                    print("❌ Validierungsfehler verhindern Speicherung:")
                                    if let urlError = urlError {
                                        print("  URL-Fehler: \(urlError)")
                                    }
                                    if let intervalError = intervalError {
                                        print("  Intervall-Fehler: \(intervalError)")
                                    }
                                }
                            }
                        
                        // URL-Fehlermeldung mit fester Höhe
                        if hasBeenEdited, let urlError = urlError {
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
                                .onChange(of: localItem.interval) { oldValue, newValue in
                                    // Benachrichtige über Wertänderung
                                    onValuesChanged(localItem.urlString, localItem.title, newValue, localItem.isEnabled, localItem.enabledNotifications)
                                }
                                .onChange(of: focusedItemID) { oldValue, newValue in
                                    // Validierung nur bei onBlur (wenn Fokus verloren geht)
                                    if oldValue == item.id && newValue != item.id {
                                        hasBeenEdited = true
                                        validateLocalInterval()
                                    }
                                }
                            
                            Stepper("", value: $localItem.interval, in: 1...3600, step: 1)
                                .labelsHidden()
                                .onChange(of: localItem.interval) { oldValue, newValue in
                                    // Benachrichtige über Wertänderung
                                    onValuesChanged(localItem.urlString, localItem.title, newValue, localItem.isEnabled, localItem.enabledNotifications)
                                }
                        }
                        
                        // Interval-Fehlermeldung mit fester Höhe
                        if hasBeenEdited, let intervalError = intervalError {
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
                    
                    // isEnabled Toggle
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Status")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        HStack {
                            Toggle("URL-Überwachung aktiviert", isOn: $localItem.isEnabled)
                                .onChange(of: localItem.isEnabled) { oldValue, newValue in
                                    // Benachrichtige über Wertänderung
                                    onValuesChanged(localItem.urlString, localItem.title, localItem.interval, newValue, localItem.enabledNotifications)
                                }
                            Spacer()
                        }
                        .padding(.vertical, 4)
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
                    .onChange(of: localItem.enabledNotifications) { oldValue, newValue in
                        // Benachrichtige über Wertänderung
                        onValuesChanged(localItem.urlString, localItem.title, localItem.interval, localItem.isEnabled, newValue)
                    }
                }
            }
        }
        .onAppear {
            // Fokussiere automatisch beim App-Start
            focusedItemID = item.id
        }
    }
    
    private func validateLocalURL() {
        let validation = onValidationRequested(localItem.urlString, localItem.interval)
        urlError = validation.urlError
    }
    
    private func validateLocalInterval() {
        let validation = onValidationRequested(localItem.urlString, localItem.interval)
        intervalError = validation.intervalError
    }
}

#Preview {
    let monitor = URLMonitor()
            let item = URLItem(urlString: "https://example.com", interval: 10)
    return URLItemInputForm(item: item, monitor: monitor, onSave: { _, _, _, _, _ in }, onValuesChanged: { _, _, _, _, _ in }, onValidationRequested: { _, _ in (nil, nil) })
        .frame(width: 600)
}

#Preview("Invalid URL") {
    let monitor = URLMonitor()
            let item = URLItem(urlString: "invalid-url", interval: 10)
    return URLItemInputForm(item: item, monitor: monitor, onSave: { _, _, _, _, _ in }, onValuesChanged: { _, _, _, _, _ in }, onValidationRequested: { _, _ in (nil, nil) })
        .frame(width: 600)
} 
