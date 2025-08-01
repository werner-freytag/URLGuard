import Foundation

extension URL {
    
    /// Prüft, ob die URL gültig ist für URL-Überwachung
    /// - Returns: true wenn die URL gültig ist, false sonst
    var isValidForMonitoring: Bool {
        // Prüfe, ob die URL gültige Komponenten hat
        guard let scheme = self.scheme?.lowercased() else { return false }
        guard let host = self.host, !host.isEmpty else { return false }
        
        // Erlaubte Protokolle mit Regex (http oder https)
        let schemePattern = #"^https?$"#
        guard scheme.range(of: schemePattern, options: .regularExpression) != nil else { return false }
        
        // Port-Validierung (falls vorhanden)
        if let port = self.port {
            guard port > 0 && port <= 65535 else { return false }
        }
        
        // Pfad- und Query-Validierung (optional)
        let invalidCharacters = CharacterSet(charactersIn: "<>\"|")
        
        // Pfad-Validierung
        if !self.path.isEmpty {
            if self.path.rangeOfCharacter(from: invalidCharacters) != nil {
                return false
            }
        }
        
        // Query-Parameter-Validierung
        if let query = self.query, !query.isEmpty {
            if query.rangeOfCharacter(from: invalidCharacters) != nil {
                return false
            }
        }
        
        return true
    }
}


func sanitizeURLString(_ urLString : String) -> String {
    let regex = /^https?:\/\//.ignoresCase()
    let trimmed = urLString.trimmingCharacters(in: .whitespacesAndNewlines)
    if trimmed.isEmpty || trimmed.firstMatch(of: regex) != nil {
        return trimmed
    }
    
    return "https://" + trimmed
}
