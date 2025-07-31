import Foundation
import Combine

class URLMonitor: ObservableObject {
    @Published var items: [URLItem] = []
    private var timers: [UUID: Timer] = [:]
    private var countdownTimers: [UUID: Timer] = [:]
    private let saveKey = "URLMonitorItems"
    private var lastResponses: [UUID: Data] = [:]
    
    init() {
        load()
        // Sofort alle nicht-pausierten Items starten
        DispatchQueue.main.async { [weak self] in
            self?.startAll()
        }
    }
    
    func startAll() {
        for item in items where !item.isPaused && !item.urlString.isEmpty {
            schedule(item: item)
        }
    }
    
    func schedule(item: URLItem) {
        cancel(item: item)
        guard !item.isPaused, !item.urlString.isEmpty else { return }
        let timer = Timer.scheduledTimer(withTimeInterval: item.interval, repeats: true) { [weak self] _ in
            self?.check(itemID: item.id)
        }
        timers[item.id] = timer
        // Sofort ersten Check auslösen
        check(itemID: item.id)
        // Countdown starten
        startCountdown(for: item)
    }
    
    func startCountdown(for item: URLItem) {
        guard let index = items.firstIndex(where: { $0.id == item.id }) else { return }
        
        // Countdown stoppen falls bereits läuft
        countdownTimers[item.id]?.invalidate()
        
        // Verbleibende Zeit auf Intervall setzen
        items[index].remainingTime = item.interval
        
        // Countdown-Timer starten
        let countdownTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            guard let currentIndex = self.items.firstIndex(where: { $0.id == item.id }) else { return }
            
            if self.items[currentIndex].remainingTime > 0 {
                self.items[currentIndex].remainingTime -= 1.0
            } else {
                // Countdown beendet, auf Intervall zurücksetzen
                self.items[currentIndex].remainingTime = self.items[currentIndex].interval
            }
        }
        countdownTimers[item.id] = countdownTimer
    }
    
    func stopCountdown(for item: URLItem) {
        countdownTimers[item.id]?.invalidate()
        countdownTimers.removeValue(forKey: item.id)
        
        if let index = items.firstIndex(where: { $0.id == item.id }) {
            items[index].remainingTime = 0
        }
    }
    
    func rescheduleTimer(for item: URLItem) {
        cancel(item: item)
        guard !item.isPaused, !item.urlString.isEmpty else { return }
        let timer = Timer.scheduledTimer(withTimeInterval: item.interval, repeats: true) { [weak self] _ in
            self?.check(itemID: item.id)
        }
        timers[item.id] = timer
        // Sofortigen Check auslösen bei Timer-Reschedule
        check(itemID: item.id)
        // Countdown neu starten
        startCountdown(for: item)
    }
    
    func cancel(item: URLItem) {
        timers[item.id]?.invalidate()
        timers.removeValue(forKey: item.id)
        lastResponses.removeValue(forKey: item.id)
        stopCountdown(for: item)
    }
    
    func togglePause(for item: URLItem) {
        if let index = items.firstIndex(where: { $0.id == item.id }) {
            items[index].isPaused.toggle()
            save()
            if items[index].isPaused {
                cancel(item: items[index])
            } else {
                schedule(item: items[index])
            }
        }
    }
    
    func remove(item: URLItem) {
        // Sicherer Remove mit Timer-Cleanup
        cancel(item: item)
        items.removeAll { $0.id == item.id }
        save()
    }
    
    func addNewItem() {
        print("addNewItem() aufgerufen")
        // Immer einen neuen Eintrag erstellen
        let newItem = URLItem(isPaused: true, isEditing: true, isNewItem: true)
        items.insert(newItem, at: 0) // Am Anfang hinzufügen statt am Ende
        print("Neuer Eintrag hinzugefügt, ID: \(newItem.id)")
        print("Aktuelle Items Anzahl: \(items.count)")
        save()
        print("Items gespeichert")
    }
    
    func validateItem(_ item: URLItem) -> (isValid: Bool, urlError: String?, intervalError: String?) {
        var urlError: String? = nil
        var intervalError: String? = nil
        
        // URL-Validierung
        let trimmedURL = item.urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedURL.isEmpty {
            urlError = "URL darf nicht leer sein"
        } else {
            let correctedURL = correctURL(trimmedURL)
            if let url = URL(string: correctedURL) {
                // Nur formelle URL-Validierung
                if !isValidURL(url) {
                    urlError = "Ungültige URL-Struktur"
                }
            } else {
                urlError = "Ungültige URL"
            }
        }
        
        // Interval-Validierung
        if item.interval < 1 {
            intervalError = "Intervall muss mindestens 1 Sekunde betragen"
        }
        
        let isValid = urlError == nil && intervalError == nil
        return (isValid, urlError, intervalError)
    }
    
    func testURL(_ urlString: String, completion: @escaping (Bool, String?) -> Void) {
        let correctedURL = correctURL(urlString)
        guard let url = URL(string: correctedURL) else {
            completion(false, "Ungültige URL")
            return
        }
        
        var request = URLRequest(url: url)
        request.timeoutInterval = 10.0 // 10 Sekunden Timeout
        request.httpMethod = "HEAD" // Nur Header abrufen, nicht den ganzen Inhalt
        
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    completion(false, "URL nicht erreichbar: \(error.localizedDescription)")
                } else if let httpResponse = response as? HTTPURLResponse {
                    if httpResponse.statusCode >= 200 && httpResponse.statusCode < 400 {
                        completion(true, nil)
                    } else {
                        completion(false, "HTTP-Fehler: \(httpResponse.statusCode)")
                    }
                } else {
                    completion(false, "Keine Antwort von der URL")
                }
            }
        }
        task.resume()
    }
    
    func isValidURL(_ url: URL) -> Bool {
        // Prüfe, ob die URL gültige Komponenten hat
        guard let scheme = url.scheme?.lowercased() else { return false }
        guard let host = url.host, !host.isEmpty else { return false }
        
        // Erlaubte Protokolle mit Regex (http oder https)
        let schemePattern = #"^https?$"#
        guard scheme.range(of: schemePattern, options: .regularExpression) != nil else { return false }
        
        // Port-Validierung (falls vorhanden)
        if let port = url.port {
            guard port > 0 && port <= 65535 else { return false }
        }
        
        // Pfad- und Query-Validierung (optional)
        let invalidCharacters = CharacterSet(charactersIn: "<>\"|")
        
        // Pfad-Validierung
        if !url.path.isEmpty {
            if url.path.rangeOfCharacter(from: invalidCharacters) != nil {
                return false
            }
        }
        
        // Query-Parameter-Validierung
        if let query = url.query, !query.isEmpty {
            if query.rangeOfCharacter(from: invalidCharacters) != nil {
                return false
            }
        }
        
        return true
    }
    
    func correctURL(_ urlString: String) -> String {
        var correctedURL = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Protokoll hinzufügen falls fehlend
        if !correctedURL.lowercased().hasPrefix("http://") && !correctedURL.lowercased().hasPrefix("https://") {
            correctedURL = "https://" + correctedURL
        }
        
        // URL mit URLComponents parsen und korrigieren
        guard var components = URLComponents(string: correctedURL) else {
            return correctedURL // Fallback bei ungültiger URL
        }
        
        // Protokoll normalisieren
        if let scheme = components.scheme?.lowercased() {
            components.scheme = scheme == "http" ? "http" : "https"
        }
        
        // Host normalisieren (kleinbuchstaben)
        if let host = components.host {
            components.host = host.lowercased()
        }
        
        // Pfad normalisieren (doppelte Slashes entfernen)
        if let path = components.path.isEmpty ? nil : components.path {
            let normalizedPath = path.replacingOccurrences(of: "//", with: "/")
            components.path = normalizedPath
        }
        
        // Stelle sicher, dass ein Pfad vorhanden ist
        if components.path.isEmpty {
            components.path = "/"
        }
        
        return components.url?.absoluteString ?? correctedURL
    }
    
    func confirmNewItemWithValues(for item: URLItem, urlString: String, interval: Double, enabledNotifications: Set<URLItem.NotificationType>? = nil) {
        if let index = items.firstIndex(where: { $0.id == item.id }) {
            // URL automatisch korrigieren
            let correctedURL = correctURL(urlString)
            
            // Prüfen, ob sich die URL geändert hat
            let urlChanged = items[index].urlString != correctedURL
            
            // Lokale Werte übernehmen
            items[index].urlString = correctedURL
            items[index].interval = interval
            
            // Benachrichtigungseinstellungen übernehmen falls angegeben
            if let enabledNotifications = enabledNotifications {
                items[index].enabledNotifications = enabledNotifications
            }
            
            let validation = validateItem(items[index])
            
            // Fehler setzen
            items[index].urlError = validation.urlError
            items[index].intervalError = validation.intervalError
            
            if validation.isValid {
                // Historie löschen, wenn sich die URL geändert hat
                if urlChanged {
                    print("🔄 URL changed from '\(item.urlString)' to '\(correctedURL)' - clearing history and status")
                    items[index].history.removeAll()
                    items[index].currentStatus = nil
                    lastResponses.removeValue(forKey: item.id)
                }
                
                // Nur bestätigen wenn gültig
                items[index].isNewItem = false
                items[index].isEditing = false
                items[index].urlError = nil
                items[index].intervalError = nil
                // Wenn URL nicht leer ist, starten
                if !items[index].urlString.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    items[index].isPaused = false
                    schedule(item: items[index])
                }
            }
            save()
        }
    }
    
    func confirmEditingWithValues(for item: URLItem, urlString: String, interval: Double, enabledNotifications: Set<URLItem.NotificationType>? = nil) {
        if let index = items.firstIndex(where: { $0.id == item.id }) {
            // URL automatisch korrigieren
            let correctedURL = correctURL(urlString)
            
            // Prüfen, ob sich die URL geändert hat
            let urlChanged = items[index].urlString != correctedURL
            
            // Lokale Werte übernehmen
            items[index].urlString = correctedURL
            items[index].interval = interval
            
            // Benachrichtigungseinstellungen übernehmen falls angegeben
            if let enabledNotifications = enabledNotifications {
                items[index].enabledNotifications = enabledNotifications
            }
            
            // Beim Beenden des Edit-Modus validieren
            let validation = validateItem(items[index])
            
            // Fehler setzen
            items[index].urlError = validation.urlError
            items[index].intervalError = validation.intervalError
            
            if validation.isValid {
                // Historie löschen, wenn sich die URL geändert hat
                if urlChanged {
                    print("🔄 URL changed from '\(item.urlString)' to '\(correctedURL)' - clearing history and status")
                    items[index].history.removeAll()
                    items[index].currentStatus = nil
                    lastResponses.removeValue(forKey: item.id)
                }
                
                // Nur beenden wenn gültig
                items[index].isEditing = false
                items[index].urlError = nil
                items[index].intervalError = nil
                // Historie ausgeblendet lassen
                items[index].isCollapsed = true
            }
            save()
        }
    }
    
    func confirmNewItem(for item: URLItem) {
        if let index = items.firstIndex(where: { $0.id == item.id }) {
            let validation = validateItem(item)
            
            // Fehler setzen
            items[index].urlError = validation.urlError
            items[index].intervalError = validation.intervalError
            
            if validation.isValid {
                // URL automatisch korrigieren und speichern
                let correctedURL = correctURL(items[index].urlString)
                items[index].urlString = correctedURL
                
                // Nur bestätigen wenn gültig
                items[index].isNewItem = false
                items[index].isEditing = false
                items[index].urlError = nil
                items[index].intervalError = nil
                // Backup-Werte löschen
                // Wenn URL nicht leer ist, starten
                if !items[index].urlString.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    items[index].isPaused = false
                    schedule(item: items[index])
                }
            }
            save()
        }
    }
    
    func cancelNewItem(for item: URLItem) {
        if let index = items.firstIndex(where: { $0.id == item.id }) {
            items.remove(at: index)
            save()
        }
    }
    
    func removeAllItems() {
        // Alle Timer stoppen
        for (_, timer) in timers {
            timer.invalidate()
        }
        timers.removeAll()
        lastResponses.removeAll()
        
        // Alle Items löschen
        items.removeAll()
        save()
    }
    
    func resetHistory(for item: URLItem) {
        if let index = items.firstIndex(where: { $0.id == item.id }) {
            // Aktuellen Status speichern, bevor Historie geleert wird
            if let lastEntry = items[index].history.first {
                items[index].currentStatus = lastEntry.status
            }
            
            // Historie komplett löschen
            items[index].history.removeAll()
            
            // Letzten Response für Vergleichszwecke behalten
            // lastResponses wird NICHT gelöscht, damit der letzte Zustand erhalten bleibt
            save()
        }
    }
    
    func moveItems(from source: IndexSet, to destination: Int) {
        items.move(fromOffsets: source, toOffset: destination)
        save()
    }
    
    func pauseAllItems() {
        for index in items.indices {
            if !items[index].isPaused {
                items[index].isPaused = true
                cancel(item: items[index])
            }
        }
        save()
    }
    
    func resetAllHistories() {
        for index in items.indices {
            // Aktuellen Status speichern, bevor Historie geleert wird
            if let lastEntry = items[index].history.first {
                items[index].currentStatus = lastEntry.status
            }
            
            // Historie komplett löschen
            items[index].history.removeAll()
        }
        // Letzte Responses für Vergleichszwecke behalten
        // lastResponses wird NICHT gelöscht, damit die letzten Zustände erhalten bleiben
        save()
    }
    
    func toggleCollapse(for item: URLItem) {
        if let index = items.firstIndex(where: { $0.id == item.id }) {
            items[index].isCollapsed.toggle()
            save()
        }
    }
    
    func toggleEditing(for item: URLItem) {
        if let index = items.firstIndex(where: { $0.id == item.id }) {
            if items[index].isEditing {
                // Beim Beenden des Edit-Modus validieren
                let validation = validateItem(items[index])
                
                // Fehler setzen
                items[index].urlError = validation.urlError
                items[index].intervalError = validation.intervalError
                
                if validation.isValid {
                    // URL automatisch korrigieren und speichern
                    let correctedURL = correctURL(items[index].urlString)
                    items[index].urlString = correctedURL
                    
                    // Nur beenden wenn gültig
                    items[index].isEditing = false
                    items[index].isModalEditing = false
                    items[index].urlError = nil
                    items[index].intervalError = nil
                }
            } else {
                // Beim Starten des Edit-Modus Fehler löschen und Historie ausblenden
                items[index].urlError = nil
                items[index].intervalError = nil
                items[index].isEditing = true
                items[index].isModalEditing = true
                items[index].isCollapsed = true // Historie ausblenden
            }
            save()
        }
    }
    
    func cancelEditing(for item: URLItem) {
        if let index = items.firstIndex(where: { $0.id == item.id }) {
            // Edit-Modus beenden ohne Änderungen zu speichern
            items[index].isEditing = false
            items[index].isModalEditing = false
            // Fehler löschen
            items[index].urlError = nil
            items[index].intervalError = nil
            // Historie ausgeblendet lassen
            items[index].isCollapsed = true
            save()
        }
    }
    
    func removeEmptyItems() {
        // Entferne leere Einträge, aber behalte immer mindestens einen
        let emptyItems = items.filter { $0.urlString.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        if items.count > 1 && items.count > emptyItems.count {
            items.removeAll { $0.urlString.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        }
        // Kein automatisches Speichern hier
    }
    
    func findFirstEmptyItem() -> URLItem? {
        return items.first { $0.urlString.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }
    
    func ensureMinimumOneItem() {
        // Stelle sicher, dass immer mindestens ein Eintrag existiert
        if items.isEmpty {
            // Erstelle einen neuen Eintrag im Edit-Modus
            let newItem = URLItem(isPaused: true, isEditing: true, isNewItem: true)
            items.append(newItem)
        }
    }
    
    func cleanupAndSave() {
        removeEmptyItems()
        save()
    }
    
    func check(itemID: UUID) {
        guard let index = items.firstIndex(where: { $0.id == itemID }) else { return }
        let item = items[index]
        guard !item.urlString.isEmpty else { return }
        
        // Wartezustand setzen
        items[index].isWaiting = true
        save()
        
        let correctedURLString = correctURL(item.urlString)
        guard let url = URL(string: correctedURLString) else { 
            // Wartezustand löschen bei ungültiger URL
            items[index].isWaiting = false
            save()
            return 
        }
        
        URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
            DispatchQueue.main.async {
                guard let self = self else { return }
                // Prüfen, ob das Item noch existiert
                guard let currentIndex = self.items.firstIndex(where: { $0.id == itemID }) else { return }
                
                // Wartezustand löschen
                self.items[currentIndex].isWaiting = false
                
                var status: URLItem.Status = .error
                var httpStatusCode: Int? = nil
                
                if let httpResponse = response as? HTTPURLResponse {
                    httpStatusCode = httpResponse.statusCode
                    
                    // Log HTTP-Code
                    print("🔍 URL Check: \(item.urlString)")
                    print("📊 HTTP Status Code: \(httpStatusCode)")
                    
                    if let data = data, error == nil {
                        // Log Content-Länge und Preview
                        let contentLength = data.count
                        let contentPreview = String(data: data.prefix(200), encoding: .utf8) ?? "Binary data"
                        
                        print("📄 Content Length: \(contentLength) bytes")
                        print("📝 Content Preview: \(contentPreview)")
                        
                        if let lastData = self.lastResponses[itemID], lastData != data {
                            status = .changed
                            print("🔄 Status: CHANGED (Content differs from last check)")
                        } else {
                            status = .success
                            print("✅ Status: SUCCESS (Content unchanged)")
                        }
                        self.lastResponses[itemID] = data
                    } else {
                        print("❌ Error: No data received or network error")
                    }
                } else if let data = data, error == nil {
                    // Non-HTTP response
                    print("🔍 URL Check: \(item.urlString)")
                    print("📊 Response Type: Non-HTTP")
                    
                    let contentLength = data.count
                    let contentPreview = String(data: data.prefix(200), encoding: .utf8) ?? "Binary data"
                    
                    print("📄 Content Length: \(contentLength) bytes")
                    print("📝 Content Preview: \(contentPreview)")
                    
                    if let lastData = self.lastResponses[itemID], lastData != data {
                        status = .changed
                        print("🔄 Status: CHANGED (Content differs from last check)")
                    } else {
                        status = .success
                        print("✅ Status: SUCCESS (Content unchanged)")
                    }
                    self.lastResponses[itemID] = data
                } else {
                    print("🔍 URL Check: \(item.urlString)")
                    print("❌ Error: \(error?.localizedDescription ?? "Unknown error")")
                }
                
                self.items[currentIndex].history.insert(URLItem.HistoryEntry(date: Date(), status: status, httpStatusCode: httpStatusCode), at: 0)
                if self.items[currentIndex].history.count > 100 { 
                    self.items[currentIndex].history.removeLast() 
                }
                
                // Aktuellen Status aktualisieren
                self.items[currentIndex].currentStatus = status
                
                // Notification senden, falls konfiguriert
                NotificationManager.shared.notifyIfNeeded(for: self.items[currentIndex], status: status, httpStatusCode: httpStatusCode)
                
                self.save()
            }
        }.resume()
    }
    
    func save() {
        if let data = try? JSONEncoder().encode(items) {
            UserDefaults.standard.set(data, forKey: saveKey)
        }
    }
    
    func load() {
        if let data = UserDefaults.standard.data(forKey: saveKey),
           let decoded = try? JSONDecoder().decode([URLItem].self, from: data) {
            self.items = decoded
        }
    }
}
