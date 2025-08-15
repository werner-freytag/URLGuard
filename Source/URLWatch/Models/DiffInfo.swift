import Foundation

struct DiffInfo: Codable, Equatable {
    struct ChangedLine: Codable, Equatable {
        let lineNumber: Int
        let oldContent: String
        let newContent: String
        let changeType: ChangeType
        
        enum ChangeType: String, Codable, CaseIterable {
            case added
            case removed
            case modified
        }
        
        init(lineNumber: Int, oldContent: String, newContent: String, changeType: ChangeType) {
            self.lineNumber = lineNumber
            self.oldContent = oldContent
            self.newContent = newContent
            self.changeType = changeType
        }
    }

    let totalChangedLines: Int
    let changedLines: [ChangedLine]
    
    init(totalChangedLines: Int, changedLines: [ChangedLine]) {
        self.totalChangedLines = totalChangedLines
        self.changedLines = changedLines
    }
    
    /// Erstellt ein DiffInfo-Objekt aus zwei Inhalten
    init(from oldContent: String, to newContent: String) {
        let oldLines = oldContent.components(separatedBy: .newlines)
        let newLines = newContent.components(separatedBy: .newlines)
        
        // Intelligente Zeilen-für-Zeilen Analyse mit Begrenzung
        let maxLines = max(oldLines.count, newLines.count)
        let maxChangedLines = 20 // Maximale Anzahl zu analysierender Zeilen
        var changedLinesCount = 0
        
        // Sammle alle Änderungen zuerst
        var allChanges: [ChangedLine] = []
        
        for i in 0..<maxLines {
            // Stoppe, wenn genug Unterschiede gefunden wurden
            if changedLinesCount >= maxChangedLines {
                break
            }
            
            let oldLine = i < oldLines.count ? oldLines[i] : ""
            let newLine = i < newLines.count ? newLines[i] : ""
            
            if oldLine != newLine {
                changedLinesCount += 1
                
                let changeType: ChangedLine.ChangeType
                if oldLine.isEmpty, !newLine.isEmpty {
                    changeType = .added
                } else if !oldLine.isEmpty, newLine.isEmpty {
                    changeType = .removed
                } else {
                    changeType = .modified
                }
                
                let ChangedLine = ChangedLine(
                    lineNumber: i + 1,
                    oldContent: oldLine,
                    newContent: newLine,
                    changeType: changeType
                )
                allChanges.append(ChangedLine)
            }
        }
        
        // Gruppiere aufeinanderfolgende Zeilen
        let groupedChanges = Self.groupConsecutiveLines(allChanges)
        
        // Statistiken berechnen
        let totalChangedLines = allChanges.count // Verwende die ursprüngliche Anzahl für Statistiken
        
        self.init(totalChangedLines: totalChangedLines, changedLines: groupedChanges)
    }
    
    /// Gruppiert aufeinanderfolgende Zeilen zu zusammengefassten Änderungen
    private static func groupConsecutiveLines(_ changes: [ChangedLine]) -> [ChangedLine] {
        guard !changes.isEmpty else { return [] }
        
        var groupedChanges: [ChangedLine] = []
        var currentGroup: [ChangedLine] = [changes[0]]
        
        for i in 1..<changes.count {
            let current = changes[i]
            let previous = changes[i - 1]
            
            // Prüfe, ob die aktuelle Zeile auf die vorherige folgt
            let isConsecutive = current.lineNumber == previous.lineNumber + 1
            
            if isConsecutive {
                currentGroup.append(current)
            } else {
                // Gruppe abschließen und neue Gruppe starten
                if let groupedChange = createGroupedChange(from: currentGroup) {
                    groupedChanges.append(groupedChange)
                }
                currentGroup = [current]
            }
        }
        
        // Letzte Gruppe hinzufügen
        if let groupedChange = createGroupedChange(from: currentGroup) {
            groupedChanges.append(groupedChange)
        }
        
        return groupedChanges
    }
    
    /// Erstellt eine zusammengefasste Änderung aus einer Gruppe von Zeilen
    private static func createGroupedChange(from group: [ChangedLine]) -> ChangedLine? {
        guard !group.isEmpty else { return nil }
        
        if group.count == 1 {
            return group[0]
        }
        
        // Alle Zeilen haben den gleichen Änderungstyp
        let changeType = group[0].changeType
        
        // Erste und letzte Zeilennummer
        let firstLineNumber = group.first!.lineNumber
        
        // Alle alten und neuen Inhalte zusammenfassen
        let oldContents = group.map { $0.oldContent }.filter { !$0.isEmpty }
        let newContents = group.map { $0.newContent }.filter { !$0.isEmpty }
        
        let oldContent = oldContents.isEmpty ? "" : oldContents.joined(separator: "\n")
        let newContent = newContents.isEmpty ? "" : newContents.joined(separator: "\n")
        
        return ChangedLine(
            lineNumber: firstLineNumber,
            oldContent: oldContent,
            newContent: newContent,
            changeType: changeType
        )
    }
}
