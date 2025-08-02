import Foundation
import Combine

class URLMonitor: ObservableObject {
    @Published var items: [URLItem] = []
    private var timers: [UUID: Timer] = [:]
    private var countdownTimers: [UUID: Timer] = [:]
    private let saveKey = "URLMonitorItems"
    let requestManager = URLRequestManager()
    
    init() {
        load()
        
        // Sofort alle nicht-pausierten Items starten
        for item in items {
            if item.isEnabled {
                schedule(item: item)
            }
        }
    }
    
    func startAll() {
        for item in items where item.isEnabled {
            schedule(item: item)
        }
    }
    
    func schedule(item: URLItem) {
        
        cancel(item: item)
        guard item.isEnabled else { 
            return 
        }
        
        // Verbleibende Zeit auf Intervall setzen
        if let index = items.firstIndex(where: { $0.id == item.id }) {
            items[index].remainingTime = item.interval
        } else {
            return
        }
        
        // Einziger Timer für Countdown und Checks (jede Sekunde)
        let timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                guard let currentIndex = self.items.firstIndex(where: { $0.id == item.id }) else { 
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
    
    @discardableResult
    func duplicate(item: URLItem) -> URLItem {
        
        // Intelligente Titel-Generierung
        let existingTitles = items.map { $0.title ?? $0.url.absoluteString }
        let newTitle = (item.title ?? item.url.absoluteString).generateUniqueCopyName(existingTitles: existingTitles)
        
        // Neues Item erstellen
        var duplicatedItem = item
        duplicatedItem.id = UUID() // Neue ID für das Duplikat
        duplicatedItem.title = newTitle
        duplicatedItem.isEnabled = false // Duplikat ist standardmäßig pausiert
        
        // Historie zurücksetzen
        duplicatedItem.history.removeAll()
        
        // Item zur Liste hinzufügen
        if let index = items.firstIndex(of: item) {
            items.insert(duplicatedItem, at: index + 1)
        } else {
            items.append(duplicatedItem)
        }
        
        // Speichern
        save()
        
        return duplicatedItem
    }
    
    @discardableResult
    func createNewItem() -> URLItem {
        let newItem = URLItem(url: URL(string: "https://")!, interval: 10, isEnabled: false)
        
        // Force UI Update
        objectWillChange.send()
        
        // Speichere die Änderungen
        save()
        
        return newItem
    }
    
    func addItem(_ item: URLItem) {
        var newItem = item
        newItem.isEnabled = true
        
        // Füge das neue Item hinzu
        items.append(newItem)
        
        schedule(item: newItem)
        save()
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
            
            // URL validieren und erstellen
            guard let url = URL(string: urlString) else {
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
                resetHistory(for: items[index])
            }
            
            // Timer-Management basierend auf isEnabled Änderung
            if isEnabledChanged {
                if isEnabled {
                    // Item wurde aktiviert - Timer starten
                    schedule(item: self.items[index])
                } else {
                    // Item wurde deaktiviert - Timer stoppen
                    cancel(item: self.items[index])
                }
            }
            
            // Force UI Update
            objectWillChange.send()
            
            // Speichere die Änderungen
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
            self.items[currentIndex].history.append(URLItem.HistoryEntry(
                date: Date(),
                status: status,
                httpStatusCode: httpStatusCode,
                diffInfo: diffInfo,
                responseSize: responseSize,
                responseTime: responseTime
            ))
            
            if self.items[currentIndex].history.count > 1000 {
                self.items[currentIndex].history.removeFirst()
            }
            
            // Notification senden
            NotificationManager.shared.notifyIfNeeded(for: self.items[currentIndex], status: status, httpStatusCode: httpStatusCode)
        }
    }
    

    

    
    func save() {
        
        // Konvertiere zu URLItems ohne Historie für die Persistierung
        let persistableItems = items.map { $0.withoutHistory() }
        
        if let data = try? JSONEncoder().encode(persistableItems) {
            UserDefaults.standard.set(data, forKey: saveKey)
            UserDefaults.standard.synchronize() // Sofort synchronisieren
            
            // Validierung: Versuche die Daten sofort wieder zu laden
            if let savedData = UserDefaults.standard.data(forKey: saveKey),
               let decodedItems = try? JSONDecoder().decode([URLItem].self, from: savedData) {
                if decodedItems.count != self.items.count {
                }
                
                // Prüfe auf Duplikate in den geladenen Daten
                let loadedDuplicateIDs = Dictionary(grouping: decodedItems, by: { $0.id })
                    .filter { $1.count > 1 }
                    .keys
                
                if !loadedDuplicateIDs.isEmpty {
                }
            } else {
            }
        } else {
        }
    }
    
    func load() {
        
        if let data = UserDefaults.standard.data(forKey: saveKey) {
            
            // Lade URLItems (ohne Historie, da sie beim Speichern entfernt wurde)
            if let decoded = try? JSONDecoder().decode([URLItem].self, from: data) {
                self.items = decoded
                
            } else {
                // Fallback: Versuche als alte URLItems zu laden (mit Historie)
                if let decoded = try? JSONDecoder().decode([URLItem].self, from: data) {
                    self.items = decoded
                    
                } else {
                }
            }
        } else {
        }
    }
    

}
