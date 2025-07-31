import Foundation
import Combine

class URLMonitor: ObservableObject {
    @Published var items: [URLItem] = []
    private var timers: [UUID: Timer] = [:]
    private var countdownTimers: [UUID: Timer] = [:]
    private let saveKey = "URLMonitorItems"
    private var lastResponses: [UUID: Data] = [:]
    
    init() {
        print("🚀 URLMonitor init() aufgerufen")
        load()
        print("📊 Items nach Load: \(items.count)")
        
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
        print("⏰ Schedule-Funktion aufgerufen für Item: \(item.id)")
        
        cancel(item: item)
        guard !item.isPaused, !item.urlString.isEmpty else { 
            print("⏰ Item ist pausiert oder URL ist leer - Timer nicht gestartet")
            return 
        }
        
        // Verbleibende Zeit auf Intervall setzen
        if let index = items.firstIndex(where: { $0.id == item.id }) {
            items[index].remainingTime = item.interval
            print("⏰ RemainingTime für Item \(item.id) auf \(item.interval) gesetzt")
        } else {
            print("❌ Item \(item.id) nicht in items-Array gefunden beim Schedule")
            return
        }
        
        // Einziger Timer für Countdown und Checks (jede Sekunde)
        let timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                guard let currentIndex = self.items.firstIndex(where: { $0.id == item.id }) else { 
                    print("❌ Item \(item.id) nicht in Timer-Callback gefunden - Timer wird gestoppt")
                    self.timers[item.id]?.invalidate()
                    self.timers.removeValue(forKey: item.id)
                    return 
                }
                
                // Countdown aktualisieren
                if self.items[currentIndex].remainingTime > 0 {
                    self.items[currentIndex].remainingTime -= 1.0
                }
                
                // Check auslösen wenn Countdown bei 0 ist
                if self.items[currentIndex].remainingTime <= 0 {
                    self.check(itemID: item.id)
                    // Countdown auf Intervall zurücksetzen
                    self.items[currentIndex].remainingTime = self.items[currentIndex].interval
                }
            }
        }
        timers[item.id] = timer
        print("⏰ Timer für Item \(item.id) erfolgreich gestartet")
    }
    
    // startCountdown und stopCountdown wurden entfernt - Countdown wird jetzt vom Haupt-Timer gehandhabt
    
    func rescheduleTimer(for item: URLItem) {
        cancel(item: item)
        guard !item.isPaused, !item.urlString.isEmpty else { return }
        
        // Verbleibende Zeit auf Intervall setzen
        if let index = items.firstIndex(where: { $0.id == item.id }) {
            items[index].remainingTime = item.interval
        }
        
        // Einziger Timer für Countdown und Checks (jede Sekunde)
        let timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                guard let currentIndex = self.items.firstIndex(where: { $0.id == item.id }) else { return }
                
                // Countdown aktualisieren
                if self.items[currentIndex].remainingTime > 0 {
                    self.items[currentIndex].remainingTime -= 1.0
                }
                
                // Check auslösen wenn Countdown bei 0 ist
                if self.items[currentIndex].remainingTime <= 0 {
                    self.check(itemID: item.id)
                    // Countdown auf Intervall zurücksetzen
                    self.items[currentIndex].remainingTime = self.items[currentIndex].interval
                }
            }
        }
        timers[item.id] = timer
    }
    
    func cancel(item: URLItem) {
        timers[item.id]?.invalidate()
        timers.removeValue(forKey: item.id)
        lastResponses.removeValue(forKey: item.id)
        
        // Countdown zurücksetzen
        if let index = items.firstIndex(where: { $0.id == item.id }) {
            items[index].remainingTime = 0
        }
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
    
    func duplicate(item: URLItem) {
        print("🔄 Duplicate-Funktion aufgerufen für Item: \(item.id)")
        print("📊 Aktuelle Anzahl Items vor Duplikation: \(items.count)")
        
        // Finde den Index des Original-Items
        guard let originalIndex = items.firstIndex(where: { $0.id == item.id }) else {
            print("❌ Original-Item nicht gefunden für Duplikation")
            return
        }
        
        print("✅ Original-Item gefunden an Index: \(originalIndex)")
        
        // Erstelle eine Kopie des Items mit neuer ID
        var duplicatedItem = item
        duplicatedItem.id = UUID() // Neue ID für das duplizierte Item
        
        // Sicherheitscheck: Stelle sicher, dass die ID wirklich eindeutig ist
        while items.contains(where: { $0.id == duplicatedItem.id }) {
            print("⚠️ ID-Kollision erkannt, generiere neue ID")
            duplicatedItem.id = UUID()
        }
        
        print("🆔 Neue ID für Duplikat: \(duplicatedItem.id)")
        
        // Historie und Status zurücksetzen
        duplicatedItem.history.removeAll()
        duplicatedItem.currentStatus = nil

        duplicatedItem.isPaused = true // Pausiert starten
        duplicatedItem.isEditing = false // Nicht im Edit-Modus
        duplicatedItem.isModalEditing = false // Nicht im Modal-Edit-Modus
        duplicatedItem.pendingRequests = 0 // Keine wartenden Requests
        duplicatedItem.remainingTime = 0 // Countdown auf 0 setzen da pausiert
        
        // Intelligenten Titel generieren
        if let originalTitle = duplicatedItem.title {
            let baseTitle = originalTitle.replacingOccurrences(of: #" \(Kopie\s*\d*\)$"#, with: "", options: .regularExpression)
            
            print("🔍 Titel-Generierung Debug:")
            print("  - Original-Titel: '\(originalTitle)'")
            print("  - Basistitel: '\(baseTitle)'")
            
            // Finde alle existierenden Titel mit dem gleichen Basistitel
            let existingTitles = items.compactMap { $0.title }
            print("  - Alle existierenden Titel: \(existingTitles)")
            
            // Suche nach allen Kopien des Basistitels
            var copyNumbers: [Int] = []
            
            // Prüfe auf "(Kopie)" ohne Nummer
            if existingTitles.contains("\(baseTitle) (Kopie)") {
                copyNumbers.append(1)
                print("  - Gefunden: '\(baseTitle) (Kopie)' -> Nummer 1")
            }
            
            // Prüfe auf "(Kopie X)" mit Nummer
            for title in existingTitles {
                if let range = title.range(of: #"\(Kopie\s*(\d+)\)$"#, options: .regularExpression) {
                    let copyPart = String(title[range])
                    if let numberRange = copyPart.range(of: #"\d+"#, options: .regularExpression) {
                        let number = Int(copyPart[numberRange]) ?? 0
                        copyNumbers.append(number)
                        print("  - Gefunden: '\(title)' -> Nummer \(number)")
                    }
                }
            }
            
            // Bestimme die nächste Kopien-Nummer
            let nextCopyNumber = copyNumbers.isEmpty ? 1 : (copyNumbers.max() ?? 0) + 1
            print("  - Nächste Kopien-Nummer: \(nextCopyNumber)")
            
            // Generiere den neuen Titel
            if nextCopyNumber == 1 {
                duplicatedItem.title = "\(baseTitle) (Kopie)"
            } else {
                duplicatedItem.title = "\(baseTitle) (Kopie \(nextCopyNumber))"
            }
            
            print("  - Generierter Titel: '\(duplicatedItem.title ?? "Kein Titel")'")
        }
        
        print("📝 Dupliziertes Item Titel: \(duplicatedItem.title ?? "Kein Titel")")
        print("📝 Titel-Generierung: Original='\(item.title ?? "Kein Titel")' -> Neuer Titel='\(duplicatedItem.title ?? "Kein Titel")'")
        
        // Validiere das duplizierte Item
        let validation = validateItem(duplicatedItem)
        if !validation.isValid {
            print("❌ Dupliziertes Item ist ungültig: \(validation.urlError ?? ""), \(validation.intervalError ?? "")")
            return
        }
        
        print("✅ Dupliziertes Item ist gültig")
        
        // Item direkt unterhalb des Originals einfügen
        let insertIndex = originalIndex + 1
        items.insert(duplicatedItem, at: insertIndex)
        
        // Force UI-Update durch explizite Benachrichtigung
        objectWillChange.send()
        
        print("📌 Duplikat eingefügt an Index: \(insertIndex)")
        print("📊 Anzahl Items nach Duplikation: \(items.count)")
        
        // Sofort speichern, bevor Timer gestartet wird
        save()
        print("💾 Items gespeichert vor Timer-Start")
        
        // Timer nur starten wenn nicht pausiert
        if !duplicatedItem.isPaused {
            schedule(item: duplicatedItem)
            print("⏰ Timer für Duplikat gestartet")
        } else {
            print("⏸️ Duplikat ist pausiert - kein Timer gestartet")
        }
        
        // Nochmal speichern nach Timer-Start
        save()
        print("💾 Items gespeichert nach Timer-Start")
        
        print("✅ Item dupliziert: \(item.id) -> \(duplicatedItem.id) an Position \(insertIndex)")
        
        // Debug: Alle Items auflisten
        print("📋 Alle Items nach Duplikation:")
        for (index, item) in items.enumerated() {
            print("  \(index): \(item.id) - \(item.title ?? item.urlString)")
        }
        
        // Zusätzliche Validierung: Prüfe ob das Duplikat wirklich in der Liste ist
        if let foundIndex = items.firstIndex(where: { $0.id == duplicatedItem.id }) {
            print("✅ Duplikat erfolgreich in Liste gefunden an Index: \(foundIndex)")
            
            // Zusätzliche Validierung: Prüfe ob das Item korrekt initialisiert ist
            let foundItem = items[foundIndex]
            print("🔍 Duplikat-Validierung:")
            print("  - ID: \(foundItem.id)")
            print("  - URL: \(foundItem.urlString)")
            print("  - Titel: \(foundItem.title ?? "Kein Titel")")
            print("  - Intervall: \(foundItem.interval)")
            print("  - Pausiert: \(foundItem.isPaused)")
            print("  - Edit-Modus: \(foundItem.isEditing)")
            print("  - Modal-Edit: \(foundItem.isModalEditing)")
            print("  - Pending Requests: \(foundItem.pendingRequests)")
            print("  - Remaining Time: \(foundItem.remainingTime)")
            print("  - Historie: \(foundItem.history.count) Einträge")
            
        } else {
            print("❌ Duplikat nicht in Liste gefunden!")
            print("🔍 Debug-Info:")
            print("  - Gesuchte ID: \(duplicatedItem.id)")
            print("  - Anzahl Items in Liste: \(items.count)")
            print("  - Alle IDs in Liste:")
            for (index, item) in items.enumerated() {
                print("    \(index): \(item.id)")
            }
        }
    }
    
    func createNewItem() -> URLItem {
        print("createNewItem() aufgerufen")
        // Erstelle ein temporäres Item für die EditView
        let newItem = URLItem(urlString: "https://", interval: 10, isPaused: true, isEditing: true)
        print("Temporäres Item erstellt, ID: \(newItem.id)")
        return newItem
    }
    
    func addItem(_ item: URLItem) {
        print("addItem() aufgerufen für Item: \(item.id)")
        // Validiere das Item vor dem Hinzufügen
        let validation = validateItem(item)
        
        if validation.isValid {
            // Item ist gültig - hinzufügen und starten
            var validItem = item
            validItem.isEditing = false
            validItem.isPaused = false
            validItem.urlError = nil
            validItem.intervalError = nil
            
            items.insert(validItem, at: 0)
            schedule(item: validItem)
            save()
            print("Item erfolgreich hinzugefügt und gestartet")
        } else {
            print("Item ist ungültig - nicht hinzugefügt")
        }
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
    
    // confirmNewItemWithValues wurde entfernt - neue Items werden über addItem() hinzugefügt
    
    func confirmEditingWithValues(for item: URLItem, urlString: String, title: String?, interval: Double, enabledNotifications: Set<URLItem.NotificationType>? = nil) {
        if let index = items.firstIndex(where: { $0.id == item.id }) {
            // URL automatisch korrigieren
            let correctedURL = correctURL(urlString)
            
            // Prüfen, ob sich die URL geändert hat
            let urlChanged = items[index].urlString != correctedURL
            
            // Lokale Werte übernehmen
            items[index].urlString = correctedURL
            items[index].title = title
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
            }
            save()
        }
    }
    
    // confirmNewItem und cancelNewItem wurden entfernt - neue Items werden über addItem() hinzugefügt
    
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
                // Beim Starten des Edit-Modus Fehler löschen
                items[index].urlError = nil
                items[index].intervalError = nil
                items[index].isEditing = true
                items[index].isModalEditing = true
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
        // Diese Funktion ist nicht mehr nötig, da neue Items nicht mehr automatisch erstellt werden
        // Neue Items werden nur über createNewItem() erstellt
    }
    
    func cleanupAndSave() {
        removeEmptyItems()
        save()
    }
    
    func check(itemID: UUID) {
        guard let index = items.firstIndex(where: { $0.id == itemID }) else { return }
        let item = items[index]
        guard !item.urlString.isEmpty else { return }
        
        // Pending Requests Counter erhöhen
        items[index].pendingRequests += 1
        save()
        
        let correctedURLString = correctURL(item.urlString)
        guard let url = URL(string: correctedURLString) else { 
            // Counter zurücksetzen bei ungültiger URL
            items[index].pendingRequests = max(0, items[index].pendingRequests - 1)
            save()
            return 
        }
        
        URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
            DispatchQueue.main.async {
                guard let self = self else { return }
                // Prüfen, ob das Item noch existiert
                guard let currentIndex = self.items.firstIndex(where: { $0.id == itemID }) else { return }
                
                // Pending Requests Counter verringern
                self.items[currentIndex].pendingRequests = max(0, self.items[currentIndex].pendingRequests - 1)
                
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
        print("💾 Save-Funktion aufgerufen")
        print("📊 Anzahl Items zum Speichern: \(items.count)")
        
        // Debug: Alle Items vor dem Speichern auflisten
        print("📋 Items vor dem Speichern:")
        for (index, item) in items.enumerated() {
            print("  \(index): \(item.id) - \(item.title ?? item.urlString)")
        }
        
        // Prüfe auf Duplikate in der Liste
        let duplicateIDs = Dictionary(grouping: items, by: { $0.id })
            .filter { $1.count > 1 }
            .keys
        
        if !duplicateIDs.isEmpty {
            print("⚠️ Warnung: Duplikate in der Items-Liste gefunden:")
            for duplicateID in duplicateIDs {
                let duplicates = items.filter { $0.id == duplicateID }
                print("  ID \(duplicateID): \(duplicates.count) mal vorhanden")
                for (index, duplicate) in duplicates.enumerated() {
                    print("    \(index): \(duplicate.title ?? duplicate.urlString)")
                }
            }
        }
        
        // Konvertiere zu PersistableURLItems (ohne Historie)
        let persistableItems = items.map { PersistableURLItem(from: $0) }
        
        if let data = try? JSONEncoder().encode(persistableItems) {
            UserDefaults.standard.set(data, forKey: saveKey)
            UserDefaults.standard.synchronize() // Sofort synchronisieren
            print("✅ Items erfolgreich gespeichert (ohne Historie)")
            
            // Debug: Speichergröße anzeigen
            print("📦 Speichergröße: \(data.count) bytes")
            
            // Validierung: Versuche die Daten sofort wieder zu laden
            if let savedData = UserDefaults.standard.data(forKey: saveKey),
               let decodedPersistableItems = try? JSONDecoder().decode([PersistableURLItem].self, from: savedData) {
                let decodedItems = decodedPersistableItems.map { $0.toURLItem() }
                print("✅ Validierung erfolgreich: \(decodedItems.count) Items geladen")
                if decodedItems.count != items.count {
                    print("⚠️ Warnung: Anzahl der gespeicherten Items (\(decodedItems.count)) stimmt nicht mit aktueller Anzahl (\(items.count)) überein")
                }
                
                // Prüfe auf Duplikate in den geladenen Daten
                let loadedDuplicateIDs = Dictionary(grouping: decodedItems, by: { $0.id })
                    .filter { $1.count > 1 }
                    .keys
                
                if !loadedDuplicateIDs.isEmpty {
                    print("⚠️ Warnung: Duplikate in den geladenen Daten gefunden:")
                    for duplicateID in loadedDuplicateIDs {
                        let duplicates = decodedItems.filter { $0.id == duplicateID }
                        print("  ID \(duplicateID): \(duplicates.count) mal vorhanden")
                    }
                }
            } else {
                print("❌ Validierung fehlgeschlagen: Items konnten nicht wieder geladen werden")
            }
        } else {
            print("❌ Fehler beim Encodieren der Items")
            
            // Debug: Versuche herauszufinden, welches Item das Problem verursacht
            for (index, persistableItem) in persistableItems.enumerated() {
                do {
                    let itemData = try JSONEncoder().encode(persistableItem)
                    print("✅ Item \(index) (\(persistableItem.id)) kann encodiert werden")
                } catch {
                    print("❌ Item \(index) (\(persistableItem.id)) kann NICHT encodiert werden: \(error)")
                }
            }
        }
    }
    
    func load() {
        print("📂 Load-Funktion aufgerufen")
        
        if let data = UserDefaults.standard.data(forKey: saveKey) {
            print("📦 Daten gefunden, Größe: \(data.count) bytes")
            
            // Versuche zuerst als PersistableURLItems zu laden (neues Format)
            if let decodedPersistable = try? JSONDecoder().decode([PersistableURLItem].self, from: data) {
                self.items = decodedPersistable.map { $0.toURLItem() }
                print("✅ Items erfolgreich geladen (neues Format ohne Historie): \(items.count) Items")
                
                // Debug: Alle geladenen Items auflisten
                print("📋 Geladene Items:")
                for (index, item) in items.enumerated() {
                    print("  \(index): \(item.id) - \(item.title ?? item.urlString)")
                }
            } else {
                // Fallback: Versuche als alte URLItems zu laden (mit Historie)
                print("🔄 Versuche Fallback auf altes Format...")
                if let decoded = try? JSONDecoder().decode([URLItem].self, from: data) {
                    self.items = decoded
                    print("✅ Items erfolgreich geladen (altes Format): \(items.count) Items")
                    
                    // Debug: Alle geladenen Items auflisten
                    print("📋 Geladene Items:")
                    for (index, item) in items.enumerated() {
                        print("  \(index): \(item.id) - \(item.title ?? item.urlString)")
                    }
                } else {
                    print("❌ Fehler beim Decodieren der Items (beide Formate)")
                }
            }
        } else {
            print("📭 Keine gespeicherten Daten gefunden")
        }
    }
}
