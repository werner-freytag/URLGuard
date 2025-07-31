import Foundation
import Combine

class URLMonitor: ObservableObject {
    @Published var items: [URLItem] = []
    private var timers: [UUID: Timer] = [:]
    private var countdownTimers: [UUID: Timer] = [:]
    private let saveKey = "URLMonitorItems"
    let requestManager = URLRequestManager()
    
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
        for item in items where item.isEnabled {
            schedule(item: item)
        }
    }
    
    func schedule(item: URLItem) {
        print("⏰ Schedule-Funktion aufgerufen für Item: \(item.id)")
        
        cancel(item: item)
        guard item.isEnabled else { 
            print("⏰ Item ist deaktiviert - Timer nicht gestartet")
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
        guard item.isEnabled else { return }
        
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
        print("🔄 Dupliziere Item: \(item.title ?? item.url.absoluteString)")
        
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
        let existingTitles = items.compactMap { $0.title }
        duplicatedItem.title = baseTitle.generateUniqueCopyName(existingTitles: existingTitles)
        
        print("📝 Generierter Titel: \(duplicatedItem.title ?? "Kein Titel")")
        
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
        
        let newItem = URLItem(url: URL(string: "https://")!, interval: 10, isEnabled: false)
        
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
        
        // Item ist bereits validiert - direkt hinzufügen und starten
        var validItem = item
        validItem.isEnabled = true
        
        items.insert(validItem, at: 0)
        schedule(item: validItem)
        save()
        print("Item erfolgreich hinzugefügt und gestartet")
    }
    
    func testURL(_ urlString: String, completion: @escaping (Bool, String?) -> Void) {
        guard let url = URL(string: urlString) else {
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
    

    
    // confirmNewItemWithValues wurde entfernt - neue Items werden über addItem() hinzugefügt
    
    func confirmEditingWithValues(for item: URLItem, urlString: String, title: String?, interval: Double, isEnabled: Bool, enabledNotifications: Set<URLItem.NotificationType>? = nil) {
        if let index = items.firstIndex(where: { $0.id == item.id }) {
            print("💾 Bestätige Bearbeitung für Item: \(item.title ?? item.url.absoluteString)")
            
            // URL validieren und erstellen
            guard let url = URL(string: urlString) else {
                print("❌ Ungültige URL: \(urlString)")
                return
            }
            
            // Prüfe, ob sich die URL geändert hat
            let urlChanged = items[index].url.absoluteString != url.absoluteString
            
            // Prüfe, ob sich isEnabled geändert hat
            let wasEnabled = items[index].isEnabled
            let isEnabledChanged = wasEnabled != isEnabled
            
            // Aktualisiere das Item
            items[index].url = url
            items[index].title = title
            items[index].interval = interval
            items[index].isEnabled = isEnabled
            
            if let enabledNotifications = enabledNotifications {
                items[index].enabledNotifications = enabledNotifications
            }
            
            // History zurücksetzen, wenn sich die URL geändert hat
            if urlChanged {
                print("🔄 URL geändert - History wird zurückgesetzt")
                resetHistory(for: items[index])
            }
            
            // Timer-Management basierend auf isEnabled Änderung
            if isEnabledChanged {
                if isEnabled {
                    // Item wurde aktiviert - Timer starten
                    print("▶️ Timer für Item starten: \(items[index].title ?? items[index].url.absoluteString)")
                    schedule(item: items[index])
                } else {
                    // Item wurde deaktiviert - Timer stoppen
                    print("⏸️ Timer für Item stoppen: \(items[index].title ?? items[index].url.absoluteString)")
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
        
        // Alle Items löschen
        items.removeAll()
        save()
    }
    
    func resetHistory(for item: URLItem) {
        if let index = items.firstIndex(where: { $0.id == item.id }) {
            // Historie komplett löschen
            items[index].history.removeAll()
            
            // Request-Manager zurücksetzen
            requestManager.resetHistory(for: item.id)
            
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
        // Request-Manager zurücksetzen
        requestManager.resetAllHistories()
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
        // URLs sind bereits validiert, da sie URL-Objekte sind
        // Keine leeren URLs mehr möglich
        // Kein automatisches Speichern hier
    }
    
    func findFirstEmptyItem() -> URLItem? {
        // URLs sind bereits validiert, da sie URL-Objekte sind
        return nil
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
        // URL ist bereits validiert, da es ein URL-Objekt ist
        
        // Pending Requests Counter erhöhen
        items[index].pendingRequests += 1
        
        requestManager.checkURL(for: item) { [weak self] status, httpStatusCode, responseSize, responseTime, diff in
            guard let self = self else { return }
            guard let currentIndex = self.items.firstIndex(where: { $0.id == itemID }) else { return }
            
            // Pending Requests Counter verringern
            self.items[currentIndex].pendingRequests = max(0, self.items[currentIndex].pendingRequests - 1)
            
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
            
            // History-Eintrag erstellen
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
    }
    

    

    
    func save() {
        print("💾 Save-Funktion aufgerufen")
        print("📊 Anzahl Items zum Speichern: \(items.count)")
        
        // Debug: Alle Items vor dem Speichern auflisten
        print("📋 Items vor dem Speichern:")
        for (index, item) in items.enumerated() {
            print("  \(index): \(item.id) - \(item.title ?? item.url.absoluteString)")
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
                    print("    \(index): \(duplicate.title ?? duplicate.url.absoluteString)")
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
                    print("  \(index): \(item.id) - \(item.title ?? item.url.absoluteString)")
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
                        print("  \(index): \(item.id) - \(item.title ?? item.url.absoluteString)")
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
