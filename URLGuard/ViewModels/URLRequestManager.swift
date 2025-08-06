import os
import Foundation
import OrderedCollections

fileprivate let logger = Logger(subsystem: "de.wfco.URLGuard", category: "Network")

// MARK: - Response Structure

struct URLCheckResponse {
    let status: URLItem.Status
    let httpStatusCode: Int?
    let responseSize: Int?
    let responseTime: Double?
    let diff: String?
    let httpMethod: String?
    let headers: OrderedDictionary<String, String>
}

class URLRequestManager {
    private var lastResponses: [UUID: Data] = [:]
    private var lastETags: [UUID: String] = [:]
    
    // MARK: - Public Interface
    
    func checkURL(for item: URLItem) async -> URLCheckResponse {
        guard URL(string: item.url.absoluteString) != nil else {
            return URLCheckResponse(
                status: .error,
                httpStatusCode: nil,
                responseSize: nil,
                responseTime: nil,
                diff: nil,
                httpMethod: nil,
                headers: [:]
            )
        }

        // Intelligente HEAD/GET-Strategie
        let hasInitialData = self.lastResponses[item.id] != nil
        let hasETag = lastETags[item.id] != nil
        
        if !hasInitialData {
            // Erster Request: Immer GET für Basis-Diff
            return await performGETRequest(item: item)
        } else if hasETag {
            // Folge-Requests mit ETag: Erst HEAD, dann GET nur bei Änderung
            return await performHEADRequest(item: item)
        } else {
            // Folge-Requests ohne ETag: Immer GET
            return await performGETRequest(item: item)
        }
    }
    
    func resetHistory(for itemID: UUID) {
        lastResponses.removeValue(forKey: itemID)
        lastETags.removeValue(forKey: itemID)
    }
    
    // MARK: - Private Request Methods
    
    /// Gemeinsame Response-Verarbeitung für HTTP Responses
    private func processHTTPResponse(_ httpResponse: HTTPURLResponse, for item: URLItem) {
        // ETag aus Response extrahieren
        if let etag = httpResponse.value(forHTTPHeaderField: "ETag") {
            lastETags[item.id] = etag
        }
    }
    
    private let redirectHeaders = [
        "Location",
        "Refresh",
    ]
    
    /// Array der HTTP-Header, die extrahiert werden sollen
    private let trackedHeaders = [
        "Content-Type",
        "Last-Modified",
    ]
    
    /// Extrahiert wichtige HTTP-Header aus der Response
    private func extractHeaders(from httpResponse: HTTPURLResponse) -> OrderedDictionary<String, String> {
        var headers = OrderedDictionary<String, String>()
        
        for headerName in redirectHeaders {
            if let headerValue = httpResponse.value(forHTTPHeaderField: headerName) {
                headers[headerName] = headerValue
            }
        }
        
        if (!headers.isEmpty) {
            return headers
        }
        
        for headerName in trackedHeaders {
            if let headerValue = httpResponse.value(forHTTPHeaderField: headerName) {
                headers[headerName] = headerValue
            }
        }
        
        return headers
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
    
    private func performRequest(for item: URLItem, method: String) async -> (Data?, URLResponse?, Error?) {
        logger.debug("\(method) \(item.url)")
        
        var request = URLRequest(url: item.url)
        request.httpMethod = method
        
        // ETag aus vorherigem Request hinzufügen
        if let etag = lastETags[item.id] {
            request.setValue(etag, forHTTPHeaderField: "If-None-Match")
        }
        
        let delegate = RedirectHandler()
        let session = URLSession(configuration: .default, delegate: delegate, delegateQueue: nil)

        return await withCheckedContinuation { continuation in
            session.dataTask(with: request) { data, response, error in
                continuation.resume(returning: (data, response, error))
            }.resume()
        }
    }
    
    private func performHEADRequest(item: URLItem) async -> URLCheckResponse {
        let startTime = Date()
        
        let (data, response, error) = await performRequest(for: item, method: "HEAD")
        
        var status: URLItem.Status = .error
        var httpStatusCode: Int? = nil
        var responseTime: Double? = nil
        var headers: OrderedDictionary<String, String> = [:]
        
        responseTime = Date().timeIntervalSince(startTime)
        
        if let httpResponse = response as? HTTPURLResponse {
            httpStatusCode = httpResponse.statusCode
            self.processHTTPResponse(httpResponse, for: item)
            headers = self.extractHeaders(from: httpResponse)
            
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
                        return await performGETRequest(item: item)
                        
                    case 304:
                        // Content unverändert
                        status = .success
                        
                    default:
                        // Andere Status-Codes - GET Request für vollständige Prüfung
                        return await performGETRequest(item: item)
                    }
                }
            } else {
                // Kein HTTP Status Code - GET Request für vollständige Prüfung
                return await performGETRequest(item: item)
            }
        } else {
            // Fallback zu GET Request
            return await performGETRequest(item: item)
        }
        
        return URLCheckResponse(
            status: status,
            httpStatusCode: httpStatusCode,
            responseSize: data?.count,
            responseTime: responseTime,
            diff: nil,
            httpMethod: "HEAD",
            headers: headers
        )
    }
    
    
    private func performGETRequest(item: URLItem) async -> URLCheckResponse {
        let startTime = Date()
        
        let (data, response, error) = await performRequest(for: item, method: "GET")
        
        var status: URLItem.Status = .error
        var httpStatusCode: Int? = nil
        var diff: String? = nil
        var responseTime: Double? = nil
        var headers: OrderedDictionary<String, String> = [:]

        responseTime = Date().timeIntervalSince(startTime)

        if let httpResponse = response as? HTTPURLResponse {
            httpStatusCode = httpResponse.statusCode
            self.processHTTPResponse(httpResponse, for: item)
            headers = self.extractHeaders(from: httpResponse)

            if let data = data, error == nil {
                let (contentStatus, contentDiff) = self.processContent(data, for: item)
                status = contentStatus
                diff = contentDiff
            } else if httpStatusCode == 304 {
                // 304 Not Modified - Content unverändert
                status = .success
            }
        } else if let data = data, error == nil {
            // Non-HTTP response
            let (contentStatus, contentDiff) = self.processContent(data, for: item)
            status = contentStatus
            diff = contentDiff
        }

        return URLCheckResponse(
            status: status,
            httpStatusCode: httpStatusCode,
            responseSize: data?.count,
            responseTime: responseTime,
            diff: diff,
            httpMethod: "GET",
            headers: headers
        )
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

fileprivate class RedirectHandler: NSObject, URLSessionDelegate, URLSessionTaskDelegate {
    func urlSession(_ session: URLSession,
                    task: URLSessionTask,
                    willPerformHTTPRedirection response: HTTPURLResponse,
                    newRequest request: URLRequest,
                    completionHandler: @escaping (URLRequest?) -> Void) {

        completionHandler(nil)
    }
}
