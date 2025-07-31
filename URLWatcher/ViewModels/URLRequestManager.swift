import Foundation

class URLRequestManager {
    private var lastResponses: [UUID: Data] = [:]
    private var lastETags: [UUID: String] = [:]
    
    // MARK: - Public Interface
    
    func checkURL(for item: URLItem, onComplete: @escaping (URLItem.Status, Int?, Int?, Double?, String?) -> Void) {
        // Intelligente HEAD/GET-Strategie
        let hasInitialData = self.lastResponses[item.id] != nil
        let hasETag = lastETags[item.id] != nil
        
        if !hasInitialData {
            // Erster Request: Immer GET für Basis-Diff
            print("🔄 Erster Request für \(item.url.absoluteString) - GET für Basis-Diff")
            performGETRequest(item: item, onComplete: onComplete)
        } else if hasETag {
            // Folge-Requests mit ETag: Erst HEAD, dann GET nur bei Änderung
            print("🔍 Folge-Request mit ETag für \(item.url.absoluteString) - HEAD-Check")
            performHEADRequest(item: item, onComplete: onComplete)
        } else {
            // Folge-Requests ohne ETag: Immer GET
            print("📄 Folge-Request ohne ETag für \(item.url.absoluteString) - GET")
            performGETRequest(item: item, onComplete: onComplete)
        }
    }
    
    func resetHistory(for itemID: UUID) {
        lastResponses.removeValue(forKey: itemID)
        lastETags.removeValue(forKey: itemID)
    }
    
    func resetAllHistories() {
        lastResponses.removeAll()
        lastETags.removeAll()
    }
    
    // MARK: - Private Request Methods
    
    private func performHEADRequest(item: URLItem, onComplete: @escaping (URLItem.Status, Int?, Int?, Double?, String?) -> Void) {
        var request = URLRequest(url: item.url)
        request.httpMethod = "HEAD"
        
        // ETag aus vorherigem Request hinzufügen
        if let etag = lastETags[item.id] {
            request.setValue(etag, forHTTPHeaderField: "If-None-Match")
        }
        
        let startTime = Date()
        
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            DispatchQueue.main.async {
                guard let self = self else { return }
                
                var status: URLItem.Status = .error
                var httpStatusCode: Int? = nil
                var responseSize: Int? = nil
                var responseTime: Double? = nil
                
                responseTime = Date().timeIntervalSince(startTime)
                
                if let httpResponse = response as? HTTPURLResponse {
                    httpStatusCode = httpResponse.statusCode
                    
                    print("🔍 HEAD Request: \(item.url.absoluteString)")
                    print("📊 HTTP Status Code: \(httpStatusCode ?? 0)")
                    
                    // ETag aus Response extrahieren
                    if let etag = httpResponse.value(forHTTPHeaderField: "ETag") {
                        self.lastETags[item.id] = etag
                        print("🏷️ ETag gefunden: \(etag)")
                    }
                    
                    if let statusCode = httpStatusCode {
                        // Prüfe zuerst, ob ETag identisch ist (Content unverändert)
                        if let currentETag = httpResponse.value(forHTTPHeaderField: "ETag"),
                           let lastETag = self.lastETags[item.id],
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
                                self.performGETRequest(item: item, onComplete: onComplete)
                                return
                                
                            case 304:
                                // Content unverändert
                                status = .success
                                print("✅ Content unverändert (304 Not Modified)")
                                
                            default:
                                // Andere Status-Codes - GET Request für vollständige Prüfung
                                print("⚠️ Unerwarteter Status \(statusCode) - GET Request folgt")
                                self.performGETRequest(item: item, onComplete: onComplete)
                                return
                            }
                        }
                    } else {
                        // Kein HTTP Status Code - GET Request für vollständige Prüfung
                        print("⚠️ Kein HTTP Status Code - GET Request folgt")
                        self.performGETRequest(item: item, onComplete: onComplete)
                        return
                    }
                } else {
                    print("❌ HEAD Request fehlgeschlagen: \(error?.localizedDescription ?? "Unknown error")")
                    // Fallback zu GET Request
                    self.performGETRequest(item: item, onComplete: onComplete)
                    return
                }
                
                onComplete(status, httpStatusCode, responseSize, responseTime, nil)
            }
        }.resume()
    }
    
    private func performGETRequest(item: URLItem, onComplete: @escaping (URLItem.Status, Int?, Int?, Double?, String?) -> Void) {
        var request = URLRequest(url: item.url)
        request.httpMethod = "GET"
        
        // ETag aus vorherigem Request hinzufügen (für 304-Responses)
        if let etag = lastETags[item.id] {
            request.setValue(etag, forHTTPHeaderField: "If-None-Match")
        }
        
        let startTime = Date()
        
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            DispatchQueue.main.async {
                guard let self = self else { return }
                
                var status: URLItem.Status = .error
                var httpStatusCode: Int? = nil
                var diff: String? = nil
                var responseSize: Int? = nil
                var responseTime: Double? = nil
                
                responseTime = Date().timeIntervalSince(startTime)
                
                if let httpResponse = response as? HTTPURLResponse {
                    httpStatusCode = httpResponse.statusCode
                    
                    print("📄 GET Request: \(item.url.absoluteString)")
                    print("📊 HTTP Status Code: \(httpStatusCode ?? 0)")
                    
                    // ETag aus Response extrahieren
                    if let etag = httpResponse.value(forHTTPHeaderField: "ETag") {
                        self.lastETags[item.id] = etag
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
                        
                        if let lastData = self.lastResponses[item.id], lastData != data {
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
                        self.lastResponses[item.id] = data
                    } else if httpStatusCode == 304 {
                        // 304 Not Modified - Content unverändert
                        status = .success
                        print("✅ Content unverändert (304 Not Modified)")
                    } else {
                        print("❌ Error: No data received or network error")
                    }
                } else if let data = data, error == nil {
                    // Non-HTTP response
                    print("📄 GET Request (Non-HTTP): \(item.url.absoluteString)")
                    
                    let contentLength = data.count
                    responseSize = contentLength
                    
                    let contentPreview = String(data: data.prefix(200), encoding: .utf8) ?? "Binary data"
                    
                    print("📄 Content Length: \(contentLength) bytes")
                    print("📝 Content Preview: \(contentPreview)")
                    print("⏱️ Response Time: \(responseTime ?? 0) seconds")
                    
                    // lastResponses wird automatisch gesetzt - kein separater Flag nötig
                    
                    if let lastData = self.lastResponses[item.id], lastData != data {
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
                    self.lastResponses[item.id] = data
                } else {
                    print("📄 GET Request fehlgeschlagen: \(error?.localizedDescription ?? "Unknown error")")
                }
                
                onComplete(status, httpStatusCode, responseSize, responseTime, diff)
            }
        }.resume()
    }
    
    // MARK: - Helper Methods
    
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