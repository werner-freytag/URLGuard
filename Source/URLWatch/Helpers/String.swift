import Foundation

extension String {
    
    /// Generiert einen eindeutigen Kopie-Namen basierend auf dem aktuellen Titel
    /// - Parameter existingTitles: Array von bereits existierenden Titeln
    /// - Returns: Einen eindeutigen Titel mit Kopie-Suffix
    func generateUniqueCopyName(existingTitles: [String]) -> String {
        let copyPattern = #"^(.+?)(?:\s*\(Kopie(?:\s*(\d+))?\))?$"#
        
        guard let regex = try? NSRegularExpression(pattern: copyPattern, options: []),
              let match = regex.firstMatch(in: self, options: [], range: NSRange(self.startIndex..., in: self)) else {
            // Kein Kopie-Pattern gefunden - versuche "Kopie" ohne Nummer
            let proposedTitle = "\(self) (Kopie)"
            
            // Prüfe, ob "Kopie" ohne Nummer bereits existiert
            let titleExists = existingTitles.contains { $0 == proposedTitle }
            
            if titleExists {
                // "Kopie" existiert bereits - verwende "Kopie 2"
                return "\(self) (Kopie 2)"
            } else {
                // "Kopie" ist frei
                return proposedTitle
            }
        }
        
        let baseTitleRange = Range(match.range(at: 1), in: self)!
        let actualBaseTitle = String(self[baseTitleRange])
        
        // Prüfe, ob der ursprüngliche Titel bereits eine Kopie-Nummer hat
        var minNumber = 1
        if match.range(at: 2).location != NSNotFound {
            // Der ursprüngliche Titel hat bereits eine Nummer (z.B. "Kopie 3")
            let numberRange = Range(match.range(at: 2), in: self)!
            let originalNumber = Int(self[numberRange]) ?? 1
            minNumber = originalNumber + 1 // Mindestens die nächste Nummer
        }
        
        // Finde die nächste freie Kopie-Nummer
        var nextNumber = minNumber
        while true {
            let proposedTitle: String
            if nextNumber == 1 {
                // Erste Kopie: nur "Kopie" ohne Nummer
                proposedTitle = "\(actualBaseTitle) (Kopie)"
            } else {
                // Weitere Kopien: "Kopie 2", "Kopie 3", etc.
                proposedTitle = "\(actualBaseTitle) (Kopie \(nextNumber))"
            }
            
            // Prüfe, ob dieser Titel bereits existiert
            let titleExists = existingTitles.contains { $0 == proposedTitle }
            
            if !titleExists {
                // Titel ist frei - verwende ihn
                return proposedTitle
            }
            
            // Titel existiert bereits - versuche nächste Nummer
            nextNumber += 1
        }
    }
    
    /// Lokalisiert einen String-Key
    var localized: String {
        NSLocalizedString(self, comment: "")
    }
    
    /// Lokalisiert einen String-Key mit Kommentar
    func localized(comment: String) -> String {
        NSLocalizedString(self, comment: comment)
    }
} 