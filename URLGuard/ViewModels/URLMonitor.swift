import Foundation
import Combine

class URLMonitor: ObservableObject {
    @Published var items: [URLItem] = []
    @Published var isGlobalPaused: Bool = true {
        didSet {
            if isGlobalPaused {
                startTimers()
            } else {
                stopTimers()
            }
        }
    }
    
    private var timers: [UUID: Timer] = [:]
    private var countdownTimers: [UUID: Timer] = [:]
    
    // Externe Zustandsverwaltung für Timer und Requests - als @Published für UI-Updates
    @Published private var remainingTimes: [UUID: Double] = [:]
    @Published private var pendingRequests: [UUID: Int] = [:]
    
    private let saveKey = "URLMonitorItems"
    private let globalPauseKey = "URLMonitorGlobalPause"
    
    let requestManager = URLRequestManager()
    
    // MARK: - Zustandsverwaltung
    
    func getRemainingTime(for itemID: UUID) -> Double {
        return remainingTimes[itemID] ?? 0
    }
    
    func setRemainingTime(_ time: Double, for itemID: UUID) {
        remainingTimes[itemID] = time
    }
    
    func getPendingRequests(for itemID: UUID) -> Int {
        return pendingRequests[itemID] ?? 0
    }
    
    func setPendingRequests(_ count: Int, for itemID: UUID) {
        pendingRequests[itemID] = count
    }
    
    func incrementPendingRequests(for itemID: UUID) {
        let current = getPendingRequests(for: itemID)
        setPendingRequests(current + 1, for: itemID)
    }
    
    func decrementPendingRequests(for itemID: UUID) {
        let current = getPendingRequests(for: itemID)
        setPendingRequests(max(0, current - 1), for: itemID)
    }
    
    func isWaiting(for itemID: UUID) -> Bool {
        return getPendingRequests(for: itemID) > 0
    }
    
    func startTimers() {
        for item in items where item.isEnabled {
            schedule(item: item)
        }
    }
    
    func stopTimers() {
        for (_, timer) in timers {
            timer.invalidate()
        }
        timers.removeAll()
    }
    
    init() {
        load()
        
        if !isGlobalPaused {
            startTimers()
        }
    }
    
    func toggleGlobalPause() {
        isGlobalPaused.toggle()
    }
    
    func schedule(item: URLItem) {
        
        cancel(item: item)
        guard item.isEnabled && !isGlobalPaused else { 
            return 
        }
        
        // Verbleibende Zeit auf Intervall setzen
        setRemainingTime(item.interval, for: item.id)
        
        // Einziger Timer für Countdown und Checks (jede Sekunde)
        let timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                guard self.items.firstIndex(where: { $0.id == item.id }) != nil else { 
                    self.timers[item.id]?.invalidate()
                    self.timers.removeValue(forKey: item.id)
                    return 
                }
                
                // Countdown aktualisieren
                let currentTime = self.getRemainingTime(for: item.id)
                if currentTime > 0 {
                    self.setRemainingTime(currentTime - 1.0, for: item.id)
                }
                
                // Check auslösen wenn Countdown bei 0 ist
                if self.getRemainingTime(for: item.id) <= 0 {
                    self.check(itemID: item.id)
                    // Countdown auf Intervall zurücksetzen
                    self.setRemainingTime(item.interval, for: item.id)
                }
            }
        }
        timers[item.id] = timer
    }
    
    // startCountdown und stopCountdown wurden entfernt - Countdown wird jetzt vom Haupt-Timer gehandhabt
    
    func rescheduleTimer(for item: URLItem) {
        cancel(item: item)
        guard item.isEnabled && !isGlobalPaused else { return }
        
        // Verbleibende Zeit auf Intervall setzen
        setRemainingTime(item.interval, for: item.id)
        
        // Einziger Timer für Countdown und Checks (jede Sekunde)
        let timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                guard self.items.firstIndex(where: { $0.id == item.id }) != nil else { return }
                
                // Countdown aktualisieren
                let currentTime = self.getRemainingTime(for: item.id)
                if currentTime > 0 {
                    self.setRemainingTime(currentTime - 1.0, for: item.id)
                }
                
                // Check auslösen wenn Countdown bei 0 ist
                if self.getRemainingTime(for: item.id) <= 0 {
                    self.check(itemID: item.id)
                    // Countdown auf Intervall zurücksetzen
                    self.setRemainingTime(item.interval, for: item.id)
                }
            }
        }
        timers[item.id] = timer
    }
    
    func cancel(item: URLItem) {
        timers[item.id]?.invalidate()
        timers.removeValue(forKey: item.id)
        
        // Countdown zurücksetzen
        setRemainingTime(0, for: item.id)
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
        
        // Nur starten wenn nicht global pausiert
        if !isGlobalPaused {
            schedule(item: newItem)
        }
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
                if isEnabled && !isGlobalPaused {
                    // Item wurde aktiviert und globale Pause ist nicht aktiv - Timer starten
                    schedule(item: self.items[index])
                } else {
                    // Item wurde deaktiviert oder globale Pause ist aktiv - Timer stoppen
                    cancel(item: self.items[index])
                }
            }
            
            // Force UI Update
            objectWillChange.send()
            
            // Speichere die Änderungen
            save()
            
        }
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
    
    func check(itemID: UUID) {
        guard let index = items.firstIndex(where: { $0.id == itemID }) else { return }
        let item = items[index]
        // URL ist bereits validiert, da es ein URL-Objekt ist
        
        // Pending Requests Counter erhöhen
        incrementPendingRequests(for: itemID)
        
        requestManager.checkURL(for: item) { [weak self] status, httpStatusCode, responseSize, responseTime, diff in
            guard let self = self else { return }
            guard let currentIndex = self.items.firstIndex(where: { $0.id == itemID }) else { return }
            
            // Pending Requests Counter verringern
            self.decrementPendingRequests(for: itemID)
            
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
            
            let maxHistoryItems = UserDefaults.standard.integer(forKey: "maxHistoryItems")
            let limit = maxHistoryItems > 0 ? maxHistoryItems : 1000 // Fallback auf 1000
            
            if self.items[currentIndex].history.count > limit {
                self.items[currentIndex].history.removeFirst()
            }
            
            // Notification senden
            NotificationManager.shared.notifyIfNeeded(for: self.items[currentIndex], status: status, httpStatusCode: httpStatusCode)
        }
    }
    
    func save() {
        let persistableItems = items.map(\.withoutHistory)
        
        guard let data = try? JSONEncoder().encode(persistableItems) else {
            print("Fehler beim Encoding der Daten.")
            return
        }
    
        UserDefaults.standard.set(data, forKey: saveKey)
        UserDefaults.standard.set(isGlobalPaused, forKey: globalPauseKey)
        UserDefaults.standard.synchronize()
    }
    
    func load() {
        isGlobalPaused = UserDefaults.standard.bool(forKey: globalPauseKey)
        
        guard let data = UserDefaults.standard.data(forKey: saveKey) else {
            print("Fehler beim Laden der Daten.")
            return
        }

        // Lade URLItems (ohne Historie, da sie beim Speichern entfernt wurde)
        if let decoded = try? JSONDecoder().decode([URLItem].self, from: data) {
            self.items = decoded
        }
    }
}
