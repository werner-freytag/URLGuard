import Foundation
import OrderedCollections
import Combine
import SwiftUI

@MainActor
class URLMonitor: ObservableObject {
    @Published var items: [URLItem] = []
    @Published var highlightedItemID: UUID? = nil

    @AppStorage("maxHistoryItems") var maxHistoryItems: Int = 200
    @AppStorage("URLMonitorGlobalPause") var isGlobalPaused: Bool = false
    @AppStorage("persistHistory") var persistHistory: Bool = false
    @AppStorage("URLMonitorItemsData") private var savedItemsData: Data = Data()
    @AppStorage("isCompactViewMode") var isCompactViewMode: Bool = false
    
    private var timer: Timer?
    
    @Published private var remainingTimes: [UUID: Double] = [:]
    @Published private var pendingRequests: [UUID: Int] = [:]
    
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
    
    func startTimer() {
        stopTimer()
        
        guard !isGlobalPaused && items.contains(where: { $0.isEnabled }) else { return }
        
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.processCentralTimer()
            }
        }
        
        // Timer-Modus auf .common setzen, damit er auch bei UI-Blockaden läuft
//        RunLoop.main.add(timer!, forMode: .common)
    }
    
    func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
    
    private func processCentralTimer() {
        guard !isGlobalPaused else { return }
        
        // UI-Updates müssen auf den Main Thread
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            for item in self.items where item.isEnabled {
                let currentTime = self.getRemainingTime(for: item.id)
                
                if currentTime > 0 {
                    self.setRemainingTime(currentTime - 1.0, for: item.id)
                }
                
                if self.getRemainingTime(for: item.id) <= 0 {
                    self.check(item: item)
                    self.setRemainingTime(item.interval, for: item.id)
                }
            }
        }
    }
    
    init() {
        load()
        
        if !isGlobalPaused {
            startTimer()
        }
    }
    
    func pauseGlobal() {
        isGlobalPaused = true
        stopTimer()
    }
    
    func startGlobal() {
        isGlobalPaused = false
        startTimer()
    }
    
    func highlightItem(_ itemID: UUID) {
        highlightedItemID = itemID
        
        // Highlight nach 1 Sekunde automatisch entfernen
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            if self.highlightedItemID == itemID {
                self.highlightedItemID = nil
            }
        }
    }
    
    func startTimer(for item: URLItem, resume: Bool = false) {
        guard item.isEnabled && !isGlobalPaused else { return }
        
        if !resume || getRemainingTime(for: item.id) <= 0 {
            setRemainingTime(item.interval, for: item.id)
        }
        
        if timer == nil {
            startTimer()
        }
    }
    
    func cancel(item: URLItem) {
        setRemainingTime(0, for: item.id)
        
        if !items.contains(where: { $0.isEnabled }) {
            stopTimer()
        }
    }
    
    func togglePause(for item: URLItem) {
        guard let index = items.firstIndex(where: { $0.id == item.id }) else { return }
        
        items[index].isEnabled.toggle()
        save()
        
        if !items[index].isEnabled {
            cancel(item: items[index])
        } else {
            startTimer(for: items[index], resume: true)
        }
        
        if items.contains(where: { $0.isEnabled }) && !isGlobalPaused {
            if timer == nil {
                startTimer()
            }
        } else {
            stopTimer()
        }
    }
    
    func remove(item: URLItem) {
        cancel(item: item)
        items.removeAll { $0.id == item.id }
        save()
        
        if !items.contains(where: { $0.isEnabled }) {
            stopTimer()
        }
    }
    
    @discardableResult
    func duplicate(item: URLItem) -> URLItem {
        
        // Intelligente Titel-Generierung
        let existingTitles = items.map { $0.title ?? $0.url.absoluteString }
        let newTitle = (item.title ?? item.url.absoluteString).generateUniqueCopyName(existingTitles: existingTitles)
        
        // Neues Item erstellen
        var duplicatedItem = item
        duplicatedItem.id = UUID()
        duplicatedItem.title = newTitle
        
        // Historie zurücksetzen
        duplicatedItem.history.removeAll()
        
        return duplicatedItem
    }
    
    @discardableResult
    func createNewItem() -> URLItem {
        let newItem = URLItem(url: URL(string: "https://")!)
        
        // Force UI Update
        objectWillChange.send()
        
        // Speichere die Änderungen
        save()
        
        return newItem
    }
    
    func addItem(_ newItem: URLItem, after otherItem: URLItem? = nil) {
        if let otherItem, let index = items.firstIndex(of: otherItem) {
            items.insert(newItem, at: index + 1)
        } else {
            items.append(newItem)
        }
        
        // Nur starten wenn nicht global pausiert
        if !isGlobalPaused {
            startTimer(for: newItem)
        }
        save()
    }
    
    func confirmEditingWithValues(for item: URLItem, urlString: String, title: String?, interval: Double, isEnabled: Bool, enabledNotifications: Set<URLItem.NotificationType>? = nil) {
        if let index = items.firstIndex(where: { $0.id == item.id }) {
            
            // URL validieren und erstellen
            guard let url = URL(string: urlString) else {
                return
            }
            
            let urlChanged = items[index].url.absoluteString != url.absoluteString
            let isEnabledChanged = items[index].isEnabled != isEnabled
            let intervalChanged = items[index].interval != interval

            // Aktualisiere das Item
            items[index].url = url
            items[index].title = title
            items[index].interval = interval
            items[index].isEnabled = isEnabled
            
            if let enabledNotifications {
                items[index].enabledNotifications = enabledNotifications
            }
            
            // History zurücksetzen, wenn sich die URL geändert hat
            if urlChanged {
                resetHistory(for: items[index])
            }
            
            if isEnabledChanged {
                if isEnabled && !isGlobalPaused {
                    let resume = !urlChanged && !intervalChanged
                    startTimer(for: self.items[index], resume: resume)
                } else {
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
            Task {
                await requestManager.resetHistory(for: item.id)
            }
            
            save()
        }
    }
    
    func unmarkAll(for item: URLItem) {
        guard let itemIndex = items.firstIndex(where: { $0.id == item.id }) else { return }
        
        items[itemIndex].history.enumerated().forEach { offset, element in
            items[itemIndex].history[offset].unmark()
        }
        
        save()
    }
    
    func toggleHistoryEntryMark(for item: URLItem, at index: Int) {
        guard let itemIndex = items.firstIndex(where: { $0.id == item.id }) else { return }
        guard index < items[itemIndex].history.count else { return }
        items[itemIndex].history[index].toggleIsMarked()
        save()
    }
    
    func moveItems(from source: IndexSet, to destination: Int) {
        items.move(fromOffsets: source, toOffset: destination)
        save()
    }
    
    func check(item: URLItem) {

        // Pending Requests Counter erhöhen
        incrementPendingRequests(for: item.id)
        
        Task {
            let requestResult = await requestManager.checkURL(for: item)
            
            await MainActor.run {
                guard let currentIndex = self.items.firstIndex(where: { $0.id == item.id }) else { return }
                
                // Pending Requests Counter verringern
                self.decrementPendingRequests(for: item.id)
                
                let isMarked = self.items[currentIndex].notification(for: requestResult) != nil
                let historyEntry = HistoryEntry.requestResult(
                    requestResult: requestResult,
                    isMarked: isMarked
                )
                
                self.items[currentIndex].history.append(historyEntry)
                self.items[currentIndex].history = self.items[currentIndex].history.reducedToMaxSize(self.maxHistoryItems)
                save()
                
                // Notification senden
                NotificationManager.shared.notifyIfNeeded(for: item, result: requestResult)
            }
        }
    }
    
    func save() {
        let persistableItems = persistHistory ? items : items.map(\.withoutHistory)
        
        guard let data = try? JSONEncoder().encode(persistableItems) else {
            LoggerManager.app.error("Fehler beim Encoding der Daten.")
            return
        }
    
        savedItemsData = data
    }
    
    func load() {
        guard !savedItemsData.isEmpty else {
            LoggerManager.app.debug("Keine gespeicherten Daten vorhanden.")
            return
        }

        if let decoded = try? JSONDecoder().decode([URLItem].self, from: savedItemsData) {
            self.items = decoded
        }
    }
    
    /// Kürzt die Historie aller Items auf die angegebene maximale Größe
    func trimAllHistories(to maxSize: Int) {
        for index in items.indices {
            items[index].history = items[index].history.reducedToMaxSizeIncludingGaps(maxSize)
        }
        save() // Änderungen speichern
    }
}


private extension HistoryEntry {
    mutating func toggleIsMarked(_ newValue: Bool? = nil) {
        guard case let .requestResult(id, requestResult, isMarked) = self else { return }
        self = .requestResult(id: id, requestResult: requestResult, isMarked: newValue ?? !isMarked)
    }
    
    mutating func unmark() {
        toggleIsMarked(false)
    }
}


extension [HistoryEntry] {
    /// Reduziert die History auf die maximale Größe in einem Schritt
    func reducedToMaxSize(_ maxSize: Int) -> Self {
        let currentEntryCount = numberOfEntries
        
        guard currentEntryCount > maxSize else {
            return self
        }
        
        let count = currentEntryCount - maxSize
        
        // Spezialfälle für kleine maxSize Werte
        switch maxSize {
        case 0:
            return []
        case 1:
            return suffix(1)
        case 2:
            return [.gap] + suffix(1)
        default:
            break
        }
        
        // Sammle alle nicht-markierten Indizes
        let unmarkedIndices: [Int] = indexesOfEntries(marked: false)
        
        // Entferne zuerst nicht-markierte Einträge
        var indicesToRemove = Array<Int>(unmarkedIndices.prefix(count))
        
        // Falls nicht genug nicht-markierte Einträge vorhanden, fülle mit markierten auf
        if indicesToRemove.count < count {
            let remainingCount = count - indicesToRemove.count
            let markedIndices: [Int] = indexesOfEntries(marked: true)
            let additionalIndices = Array<Int>(markedIndices.prefix(remainingCount))
            indicesToRemove = (indicesToRemove + additionalIndices).sorted()
        }
        
        return removeEntriesAtIndices(Array<Int>(indicesToRemove))
    }
    
    /// Reduziert die History auf die maximale Größe, wobei Gaps mitgezählt werden
    func reducedToMaxSizeIncludingGaps(_ maxSize: Int) -> Self {
        var size = maxSize
        
        var result = reducedToMaxSize(maxSize)
        if (maxSize <= 2) { return result }
        
        while result.count > maxSize {
            size -= 1
            result = result.reducedToMaxSize(size)
        }
        
        return result
    }
    
    private func indexesOfEntries(marked: Bool) -> Array<Int> {
        enumerated().compactMap { index, entry in
           if case .requestResult(_, _, let isMarked) = entry, isMarked == marked {
               return index
           }
           return nil
       }
    }
    
    private var numberOfEntries: Int {
        filter { if case .requestResult = $0 { return true }; return false }.count
    }
    
    /// Entfernt Einträge an mehreren Indizes und fügt Lücken hinzu
    private func removeEntriesAtIndices(_ indices: Array<Int>) -> [HistoryEntry] {
        guard !indices.isEmpty else { return self }
        
        return enumerated().reduce(into: [HistoryEntry]()) { result, entry in
            let (index, element) = entry
            
            if element == .gap || indices.contains(index) {
                if result.last == .gap {
                    return
                }
                result.append(.gap)
            } else {
                result.append(element)
            }
        }
    }
    
    /// Berechnet die Länge des zu entfernenden Bereichs (inkl. benachbarter Lücken)
    private func calculateRemoveLength(at index: Int) -> Int {
        var length = 1 // Der Eintrag selbst
        
        // Füge benachbarte Lücke hinzu, falls vorhanden
        if index < count - 1 && self[index + 1] == .gap {
            length += 1
        }
        
        return length
    }
}

