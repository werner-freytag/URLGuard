import Foundation
import Combine

class URLMonitor: ObservableObject {
    @Published var items: [URLItem] = []
    private var timers: [UUID: Timer] = [:]
    private var countdownTimers: [UUID: Timer] = [:]
    private let saveKey = "URLMonitorItems"
    private var lastResponses: [UUID: Data] = [:]
    private var lastETags: [UUID: String] = [:]
    
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
        for item in items where item.isEnabled && !item.urlString.isEmpty {
            schedule(item: item)
        }
    }
    
    func schedule(item: URLItem) {
        print("⏰ Schedule-Funktion aufgerufen für Item: \(item.id)")
        
        cancel(item: item)
        guard item.isEnabled, !item.urlString.isEmpty else { 
            print("⏰ Item ist deaktiviert oder URL ist leer - Timer nicht gestartet")
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
        guard item.isEnabled, !item.urlString.isEmpty else { return }
        
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
            items[index].isEnabled.toggle()
            save()
            if !items[index].isEnabled {
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
        print("🔄 Dupliziere Item: \(item.title ?? item.urlString)")
        
        // Erstelle eine Kopie des Items
        var duplicatedItem = item
        duplicatedItem.id = UUID() // Neue eindeutige ID
        duplicatedItem.isEnabled = false // Startet pausiert
        duplicatedItem.pendingRequests = 0
        duplicatedItem.remainingTime = 0
        duplicatedItem.history = [] // Keine Historie für Duplikate
        // currentStatus wird automatisch aus history abgeleitet
        
        // Intelligente Titel-Generierung für Duplikate
        let baseTitle = item.title ?? "URL"
        let copyPattern = #"^(.+?)(?:\s*\(Kopie(?:\s*(\d+))?\))?$"#
        
        if let regex = try? NSRegularExpression(pattern: copyPattern, options: []),
           let match = regex.firstMatch(in: baseTitle, options: [], range: NSRange(baseTitle.startIndex..., in: baseTitle)) {
            
            let baseTitleRange = Range(match.range(at: 1), in: baseTitle)!
            let actualBaseTitle = String(baseTitle[baseTitleRange])
            
            // Finde alle existierenden Items mit ähnlichen Titeln
            let existingTitles = items.compactMap { $0.title }
            let copyNumbers = existingTitles.compactMap { title -> Int? in
                let copyPattern = #"^\(Kopie(?:\s*(\d+))?\)$"#
                if let regex = try? NSRegularExpression(pattern: copyPattern, options: []),
                   let match = regex.firstMatch(in: title, options: [], range: NSRange(title.startIndex..., in: title)) {
                    if match.range(at: 1).location != NSNotFound {
                        let numberRange = Range(match.range(at: 1), in: title)!
                        return Int(title[numberRange])
                    } else {
                        return 1 // "Kopie" ohne Nummer = 1
                    }
                }
                return nil
            }
            
            let nextNumber = (copyNumbers.max() ?? 0) + 1
            duplicatedItem.title = "\(actualBaseTitle) (Kopie \(nextNumber))"
        } else {
            duplicatedItem.title = "\(baseTitle) (Kopie)"
        }
        
        print("📝 Generierter Titel: \(duplicatedItem.title ?? "Kein Titel")")
        
        // Validiere das duplizierte Item
        let validation = validateItem(duplicatedItem)
        if !validation.isValid {
            print("❌ Dupliziertes Item ist ungültig: \(validation.urlError ?? ""), \(validation.intervalError ?? "")")
            return
        }
        
        // Füge das duplizierte Item hinzu
        items.append(duplicatedItem)
        
        // Force UI Update
        objectWillChange.send()
        
        // Speichere die Änderungen
        save()
        
        print("✅ Item erfolgreich dupliziert")
    }
    
    func createNewItem() {
        print("➕ Erstelle neues Item")
        
        let newItem = URLItem(urlString: "https://", interval: 10, isEnabled: false)
        
        // Füge das neue Item hinzu
        items.append(newItem)
        
        // Force UI Update
        objectWillChange.send()
        
        // Speichere die Änderungen
        save()
        
        print("✅ Neues Item erstellt")
    }
    
    func addItem(_ item: URLItem) {
        print("addItem() aufgerufen für Item: \(item.id)")
        // Validiere das Item vor dem Hinzufügen
        let validation = validateItem(item)
        
        if validation.isValid {
            // Item ist gültig - hinzufügen und starten
            var validItem = item
            validItem.isEnabled = true
            
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
    
    func confirmEditingWithValues(for item: URLItem, urlString: String, title: String?, interval: Double, isEnabled: Bool, enabledNotifications: Set<URLItem.NotificationType>? = nil) {
        if let index = items.firstIndex(where: { $0.id == item.id }) {
            print("💾 Bestätige Bearbeitung für Item: \(item.title ?? item.urlString)")
            
            // Erstelle ein temporäres Item für die Validierung
            var validItem = item
            validItem.urlString = urlString
            validItem.title = title
            validItem.interval = interval
            validItem.isEnabled = isEnabled
            
            // Validiere das Item
            let validation = validateItem(validItem)
            if !validation.isValid {
                print("❌ Item ist ungültig: \(validation.urlError ?? ""), \(validation.intervalError ?? "")")
                return
            }
            
            // Prüfe, ob sich isEnabled geändert hat
            let wasEnabled = items[index].isEnabled
            let isEnabledChanged = wasEnabled != isEnabled
            
            // Aktualisiere das Item
            items[index].urlString = urlString
            items[index].title = title
            items[index].interval = interval
            items[index].isEnabled = isEnabled
            
            if let enabledNotifications = enabledNotifications {
                items[index].enabledNotifications = enabledNotifications
            }
            
            // Timer-Management basierend auf isEnabled Änderung
            if isEnabledChanged {
                if isEnabled {
                    // Item wurde aktiviert - Timer starten
                    print("▶️ Timer für Item starten: \(items[index].title ?? items[index].urlString)")
                    schedule(item: items[index])
                } else {
                    // Item wurde deaktiviert - Timer stoppen
                    print("⏸️ Timer für Item stoppen: \(items[index].title ?? items[index].urlString)")
                    cancel(item: items[index])
                }
            }
            
            // Force UI Update
            objectWillChange.send()
            
            // Speichere die Änderungen
            save()
            
            print("✅ Bearbeitung bestätigt")
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
                    if items[index].isEnabled {
            items[index].isEnabled = false
                cancel(item: items[index])
            }
        }
        save()
    }
    
    func resetAllHistories() {
        for index in items.indices {
            // Historie komplett löschen
            items[index].history.removeAll()
        }
        // Letzte Responses für Vergleichszwecke behalten
        // lastResponses wird NICHT gelöscht, damit die letzten Zustände erhalten bleiben
        save()
    }
    

    
    func toggleEditing(for item: URLItem) {
        // Diese Funktion ist nicht mehr benötigt, da nur noch Modal-Editor verwendet wird
        print("⚠️ toggleEditing() ist veraltet - Modal-Editor wird verwendet")
    }
    
    func cancelEditing(for item: URLItem) {
        // Diese Funktion ist nicht mehr benötigt, da nur noch Modal-Editor verwendet wird
        print("⚠️ cancelEditing() ist veraltet - Modal-Editor wird verwendet")
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
        
        let correctedURLString = correctURL(item.urlString)
        guard let url = URL(string: correctedURLString) else { 
            // Counter zurücksetzen bei ungültiger URL
            items[index].pendingRequests = max(0, items[index].pendingRequests - 1)
            return 
        }
        
        // Intelligente HEAD/GET-Strategie
        let hasInitialData = self.lastResponses[itemID] != nil
        let hasETag = lastETags[itemID] != nil
        
        if !hasInitialData {
            // Erster Request: Immer GET für Basis-Diff
            print("🔄 Erster Request für \(item.urlString) - GET für Basis-Diff")
            performGETRequest(url: url, itemID: itemID, item: item)
        } else if hasETag {
            // Folge-Requests mit ETag: Erst HEAD, dann GET nur bei Änderung
            print("🔍 Folge-Request mit ETag für \(item.urlString) - HEAD-Check")
            performHEADRequest(url: url, itemID: itemID, item: item)
        } else {
            // Folge-Requests ohne ETag: Immer GET
            print("📄 Folge-Request ohne ETag für \(item.urlString) - GET")
            performGETRequest(url: url, itemID: itemID, item: item)
        }
    }
    
    private func performHEADRequest(url: URL, itemID: UUID, item: URLItem) {
        var request = URLRequest(url: url)
        request.httpMethod = "HEAD"
        
        // ETag aus vorherigem Request hinzufügen
        if let etag = lastETags[itemID] {
            request.setValue(etag, forHTTPHeaderField: "If-None-Match")
        }
        
        let startTime = Date()
        
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            DispatchQueue.main.async {
                guard let self = self else { return }
                guard let currentIndex = self.items.firstIndex(where: { $0.id == itemID }) else { return }
                
                // Pending Requests Counter verringern
                self.items[currentIndex].pendingRequests = max(0, self.items[currentIndex].pendingRequests - 1)
                
                var status: URLItem.Status = .error
                var httpStatusCode: Int? = nil
                var responseSize: Int? = nil
                var responseTime: Double? = nil
                
                responseTime = Date().timeIntervalSince(startTime)
                
                if let httpResponse = response as? HTTPURLResponse {
                    httpStatusCode = httpResponse.statusCode
                    
                    print("🔍 HEAD Request: \(item.urlString)")
                    print("📊 HTTP Status Code: \(httpStatusCode ?? 0)")
                    
                    // ETag aus Response extrahieren
                    if let etag = httpResponse.value(forHTTPHeaderField: "ETag") {
                        self.lastETags[itemID] = etag
                        print("🏷️ ETag gefunden: \(etag)")
                    }
                    
                    if let statusCode = httpStatusCode {
                        // Prüfe zuerst, ob ETag identisch ist (Content unverändert)
                        if let currentETag = httpResponse.value(forHTTPHeaderField: "ETag"),
                           let lastETag = self.lastETags[itemID],
                           currentETag == lastETag {
                            // ETag identisch - Content unverändert, auch wenn Status != 304
                            status = .success
                            print("✅ Content unverändert (ETag identisch: \(currentETag))")
                        } else {
                            // ETag unterschiedlich oder nicht vorhanden - prüfe Status-Code
                            switch statusCode {
                            case 200...299:
                                // Content hat sich geändert - GET Request für vollständigen Inhalt
                                print("🔄 Content geändert (Status \(statusCode)) - GET Request folgt")
                                self.performGETRequest(url: url, itemID: itemID, item: item)
                                return
                                
                            case 304:
                                // Content unverändert
                                status = .success
                                print("✅ Content unverändert (304 Not Modified)")
                                
                            default:
                                // Andere Status-Codes - GET Request für vollständige Prüfung
                                print("⚠️ Unerwarteter Status \(statusCode) - GET Request folgt")
                                self.performGETRequest(url: url, itemID: itemID, item: item)
                                return
                            }
                        }
                    } else {
                        // Kein HTTP Status Code - GET Request für vollständige Prüfung
                        print("⚠️ Kein HTTP Status Code - GET Request folgt")
                        self.performGETRequest(url: url, itemID: itemID, item: item)
                        return
                    }
                } else {
                    print("❌ HEAD Request fehlgeschlagen: \(error?.localizedDescription ?? "Unknown error")")
                    // Fallback zu GET Request
                    self.performGETRequest(url: url, itemID: itemID, item: item)
                    return
                }
                
                // History-Eintrag für HEAD Request
                self.items[currentIndex].history.insert(URLItem.HistoryEntry(
                    date: Date(),
                    status: status,
                    httpStatusCode: httpStatusCode,
                    diffInfo: nil,
                    responseSize: responseSize,
                    responseTime: responseTime
                ), at: 0)
                
                if self.items[currentIndex].history.count > 1000 {
                    self.items[currentIndex].history.removeLast()
                }
                
                // Notification senden
                NotificationManager.shared.notifyIfNeeded(for: self.items[currentIndex], status: status, httpStatusCode: httpStatusCode)
            }
        }.resume()
    }
    
    private func performGETRequest(url: URL, itemID: UUID, item: URLItem) {
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        
        // ETag aus vorherigem Request hinzufügen (für 304-Responses)
        if let etag = lastETags[itemID] {
            request.setValue(etag, forHTTPHeaderField: "If-None-Match")
        }
        
        let startTime = Date()
        
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            DispatchQueue.main.async {
                guard let self = self else { return }
                guard let currentIndex = self.items.firstIndex(where: { $0.id == itemID }) else { return }
                
                // Pending Requests Counter verringern
                self.items[currentIndex].pendingRequests = max(0, self.items[currentIndex].pendingRequests - 1)
                
                var status: URLItem.Status = .error
                var httpStatusCode: Int? = nil
                var diff: String? = nil
                var responseSize: Int? = nil
                var responseTime: Double? = nil
                
                responseTime = Date().timeIntervalSince(startTime)
                
                if let httpResponse = response as? HTTPURLResponse {
                    httpStatusCode = httpResponse.statusCode
                    
                    print("📄 GET Request: \(item.urlString)")
                    print("📊 HTTP Status Code: \(httpStatusCode ?? 0)")
                    
                    // ETag aus Response extrahieren
                    if let etag = httpResponse.value(forHTTPHeaderField: "ETag") {
                        self.lastETags[itemID] = etag
                        print("🏷️ ETag gefunden: \(etag)")
                    }
                    
                    if let data = data, error == nil {
                        // Content verarbeitung
                        let contentLength = data.count
                        responseSize = contentLength
                        
                        let contentPreview = String(data: data.prefix(200), encoding: .utf8) ?? "Binary data"
                        
                        print("📄 Content Length: \(contentLength) bytes")
                        print("📝 Content Preview: \(contentPreview)")
                        print("⏱️ Response Time: \(responseTime ?? 0) seconds")
                        
                        // lastResponses wird automatisch gesetzt - kein separater Flag nötig
                        
                        if let lastData = self.lastResponses[itemID], lastData != data {
                            status = .changed
                            print("🔄 Status: CHANGED (Content differs from last check)")
                            
                            // Diff erstellen
                            if let lastContent = String(data: lastData, encoding: .utf8),
                               let currentContent = String(data: data, encoding: .utf8) {
                                diff = self.createDiff(from: lastContent, to: currentContent)
                                print("📋 Diff erstellt: \(diff?.prefix(100) ?? "Kein Diff")")
                            }
                        } else {
                            status = .success
                            print("✅ Status: SUCCESS (Content unchanged)")
                        }
                        self.lastResponses[itemID] = data
                    } else if httpStatusCode == 304 {
                        // 304 Not Modified - Content unverändert
                        status = .success
                        print("✅ Content unverändert (304 Not Modified)")
                    } else {
                        print("❌ Error: No data received or network error")
                    }
                } else if let data = data, error == nil {
                    // Non-HTTP response
                    print("📄 GET Request (Non-HTTP): \(item.urlString)")
                    
                    let contentLength = data.count
                    responseSize = contentLength
                    
                    let contentPreview = String(data: data.prefix(200), encoding: .utf8) ?? "Binary data"
                    
                    print("📄 Content Length: \(contentLength) bytes")
                    print("📝 Content Preview: \(contentPreview)")
                    print("⏱️ Response Time: \(responseTime ?? 0) seconds")
                    
                    // lastResponses wird automatisch gesetzt - kein separater Flag nötig
                    
                    if let lastData = self.lastResponses[itemID], lastData != data {
                        status = .changed
                        print("🔄 Status: CHANGED (Content differs from last check)")
                        
                        // Diff erstellen
                        if let lastContent = String(data: lastData, encoding: .utf8),
                           let currentContent = String(data: data, encoding: .utf8) {
                            diff = self.createDiff(from: lastContent, to: currentContent)
                            print("📋 Diff erstellt: \(diff?.prefix(100) ?? "Kein Diff")")
                        }
                    } else {
                        status = .success
                        print("✅ Status: SUCCESS (Content unchanged)")
                    }
                    self.lastResponses[itemID] = data
                } else {
                    print("📄 GET Request fehlgeschlagen: \(error?.localizedDescription ?? "Unknown error")")
                }
                
                // DiffInfo erstellen falls Diff vorhanden
                var diffInfo: URLItem.DiffInfo? = nil
                if let diff = diff {
                    let changedLines = diff.components(separatedBy: .newlines).filter { line in
                        line.hasPrefix("+") || line.hasPrefix("-")
                    }
                    let previewLines = Array(changedLines.prefix(20))
                    diffInfo = URLItem.DiffInfo(
                        totalChangedLines: changedLines.count,
                        previewLines: previewLines
                    )
                }
                
                // History-Eintrag für GET Request
                self.items[currentIndex].history.insert(URLItem.HistoryEntry(
                    date: Date(),
                    status: status,
                    httpStatusCode: httpStatusCode,
                    diffInfo: diffInfo,
                    responseSize: responseSize,
                    responseTime: responseTime
                ), at: 0)
                
                if self.items[currentIndex].history.count > 1000 {
                    self.items[currentIndex].history.removeLast()
                }
                
                // Notification senden
                NotificationManager.shared.notifyIfNeeded(for: self.items[currentIndex], status: status, httpStatusCode: httpStatusCode)
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
                    _ = try JSONEncoder().encode(persistableItem)
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
    
    // MARK: - Diff-Funktionalität
    
    /// Erstellt einen Diff zwischen zwei Strings
    private func createDiff(from oldContent: String, to newContent: String) -> String {
        let oldLines = oldContent.components(separatedBy: .newlines)
        let newLines = newContent.components(separatedBy: .newlines)
        
        var diffLines: [String] = []
        diffLines.append("=== DIFF ===")
        diffLines.append("Alte Version: \(oldLines.count) Zeilen")
        diffLines.append("Neue Version: \(newLines.count) Zeilen")
        diffLines.append("")
        
        // Einfacher Zeilen-für-Zeilen Vergleich
        let maxLines = max(oldLines.count, newLines.count)
        
        for i in 0..<maxLines {
            let oldLine = i < oldLines.count ? oldLines[i] : ""
            let newLine = i < newLines.count ? newLines[i] : ""
            
            if oldLine != newLine {
                diffLines.append("Zeile \(i + 1):")
                if !oldLine.isEmpty {
                    diffLines.append("- \(oldLine)")
                }
                if !newLine.isEmpty {
                    diffLines.append("+ \(newLine)")
                }
                diffLines.append("")
            }
        }
        
        // Zusätzliche Statistiken
        let addedLines = newLines.count - oldLines.count
        if addedLines > 0 {
            diffLines.append("📈 \(addedLines) Zeilen hinzugefügt")
        } else if addedLines < 0 {
            diffLines.append("📉 \(abs(addedLines)) Zeilen entfernt")
        }
        
        let changedLines = zip(oldLines, newLines).filter { $0 != $1 }.count
        if changedLines > 0 {
            diffLines.append("🔄 \(changedLines) Zeilen geändert")
        }
        
        return diffLines.joined(separator: "\n")
    }
}
