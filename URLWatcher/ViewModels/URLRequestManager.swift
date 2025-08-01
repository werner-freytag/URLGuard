import Foundation

class URLRequestManager {
    private var lastResponses: [UUID: Data] = [:]
    private var lastETags: [UUID: String] = [:]
    
    // MARK: - Public Interface
    
    func checkURL(for item: URLItem, onComplete: @escaping (URLItem.Status, Int?, Int?, Double?, String?) -> Void) {
        guard URL(string: item.url.absoluteString) != nil else { // Use item.url.absoluteString
            onComplete(.error, nil, nil, nil, nil)
            return
        }

        // Intelligente HEAD/GET-Strategie
        let hasInitialData = self.lastResponses[item.id] != nil
        let hasETag = lastETags[item.id] != nil
        
        if !hasInitialData {
            // Erster Request: Immer GET für Basis-Diff
            performGETRequest(item: item, onComplete: onComplete)
        } else if hasETag {
            // Folge-Requests mit ETag: Erst HEAD, dann GET nur bei Änderung
            performHEADRequest(item: item, onComplete: onComplete)
        } else {
            // Folge-Requests ohne ETag: Immer GET
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
    
    /// Gemeinsame Request-Vorbereitung für HEAD und GET Requests
    private func prepareRequest(for item: URLItem, method: String) -> URLRequest {
        var request = URLRequest(url: item.url)
        request.httpMethod = method
        
        // ETag aus vorherigem Request hinzufügen
        if let etag = lastETags[item.id] {
            request.setValue(etag, forHTTPHeaderField: "If-None-Match")
        }
        
        return request
    }
    
    /// Gemeinsame Response-Verarbeitung für HTTP Responses
    private func processHTTPResponse(_ httpResponse: HTTPURLResponse, for item: URLItem) {
        // ETag aus Response extrahieren
        if let etag = httpResponse.value(forHTTPHeaderField: "ETag") {
            lastETags[item.id] = etag
        }
    }
    
    /// Gemeinsame Content-Verarbeitung für GET Requests
    private func processContent(_ data: Data, for item: URLItem) -> (URLItem.Status, String?) {
        // lastResponses wird automatisch gesetzt - kein separater Flag nötig
        if let lastData = lastResponses[item.id], lastData != data {
            // Intelligente Diff-Erstellung mit begrenzter Datenmenge
            if let lastContent = String(data: lastData, encoding: .utf8),
               let currentContent = String(data: data, encoding: .utf8) {
                let diff = createIntelligentDiff(from: lastContent, to: currentContent)
                lastResponses[item.id] = data
                return (.changed, diff)
            }
        }
        
        lastResponses[item.id] = data
        return (.success, nil)
    }
    
    private func performHEADRequest(item: URLItem, onComplete: @escaping (URLItem.Status, Int?, Int?, Double?, String?) -> Void) {
        let request = prepareRequest(for: item, method: "HEAD")
        let startTime = Date()
        
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            DispatchQueue.main.async {
                guard let self = self else { return }
                
                var status: URLItem.Status = .error
                var httpStatusCode: Int? = nil
                let responseSize: Int? = nil
                var responseTime: Double? = nil
                
                responseTime = Date().timeIntervalSince(startTime)
                
                if let httpResponse = response as? HTTPURLResponse {
                    httpStatusCode = httpResponse.statusCode
                    self.processHTTPResponse(httpResponse, for: item)
                    
                    if let statusCode = httpStatusCode {
                        // Prüfe zuerst, ob ETag identisch ist (Content unverändert)
                        if let currentETag = httpResponse.value(forHTTPHeaderField: "ETag"),
                           let lastETag = self.lastETags[item.id],
                           currentETag == lastETag {
                            // ETag identisch - Content unverändert, auch wenn Status != 304
                            status = .success
                        } else {
                            // ETag unterschiedlich oder nicht vorhanden - prüfe Status-Code
                            switch statusCode {
                            case 200...299:
                                // Content hat sich geändert - GET Request für vollständigen Inhalt
                                self.performGETRequest(item: item, onComplete: onComplete)
                                return
                                
                            case 304:
                                // Content unverändert
                                status = .success
                                
                            default:
                                // Andere Status-Codes - GET Request für vollständige Prüfung
                                self.performGETRequest(item: item, onComplete: onComplete)
                                return
                            }
                        }
                    } else {
                        // Kein HTTP Status Code - GET Request für vollständige Prüfung
                        self.performGETRequest(item: item, onComplete: onComplete)
                        return
                    }
                } else {
                    // Fallback zu GET Request
                    self.performGETRequest(item: item, onComplete: onComplete)
                    return
                }
                
                onComplete(status, httpStatusCode, responseSize, responseTime, nil)
            }
        }.resume()
    }
    
    private func performGETRequest(item: URLItem, onComplete: @escaping (URLItem.Status, Int?, Int?, Double?, String?) -> Void) {
        guard URL(string: item.url.absoluteString) != nil else {
            onComplete(.error, nil, nil, nil, nil)
            return
        }

        let request = prepareRequest(for: item, method: "GET")
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
                    self.processHTTPResponse(httpResponse, for: item)

                    if let data = data, error == nil {
                        responseSize = data.count
                        let (contentStatus, contentDiff) = self.processContent(data, for: item)
                        status = contentStatus
                        diff = contentDiff
                    } else if httpStatusCode == 304 {
                        // 304 Not Modified - Content unverändert
                        status = .success
                    }
                } else if let data = data, error == nil {
                    // Non-HTTP response
                    responseSize = data.count
                    let (contentStatus, contentDiff) = self.processContent(data, for: item)
                    status = contentStatus
                    diff = contentDiff
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

    /// Erstellt einen intelligenten Diff mit begrenzter Datenmenge
    private func createIntelligentDiff(from oldContent: String, to newContent: String) -> String {
        let oldLines = oldContent.components(separatedBy: .newlines)
        let newLines = newContent.components(separatedBy: .newlines)

        var diffLines: [String] = []
        diffLines.append("=== INTELLIGENTER DIFF ===")
        diffLines.append("Alte Version: \(oldLines.count) Zeilen")
        diffLines.append("Neue Version: \(newLines.count) Zeilen")
        diffLines.append("")

        // Intelligente Zeilen-für-Zeilen Analyse mit Begrenzung
        let maxLines = max(oldLines.count, newLines.count)
        var changedLinesCount = 0
        let maxChangedLines = 20 // Maximale Anzahl zu analysierender Zeilen

        for i in 0..<maxLines {
            // Stoppe, wenn genug Unterschiede gefunden wurden
            if changedLinesCount >= maxChangedLines {
                diffLines.append("... (weitere Änderungen vorhanden)")
                break
            }

            let oldLine = i < oldLines.count ? oldLines[i] : ""
            let newLine = i < newLines.count ? newLines[i] : ""

            if oldLine != newLine {
                changedLinesCount += 1
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

        let totalChangedLines = zip(oldLines, newLines).filter { $0 != $1 }.count
        if totalChangedLines > 0 {
            diffLines.append("🔄 \(totalChangedLines) Zeilen geändert (max. \(maxChangedLines) angezeigt)")
        }

        return diffLines.joined(separator: "\n")
    }
} 
