import SwiftUI

struct MenuBarContentView: View {
    @ObservedObject var monitor: URLMonitor
    
    var body: some View {
        Button("Öffnen") {
            NSApp.openMainWindow()
        }
        Divider()
        Button(monitor.isGlobalPaused ? "Monitoring starten" : "Monitoring pausieren") {
            monitor.isGlobalPaused ? monitor.startGlobal() : monitor.pauseGlobal()
        }
        
        Divider()
        if monitor.items.isEmpty {
            Text("Keine Einträge")
        } else {
            ForEach(monitor.items) { item in
                Button {
                    NSApp.openMainWindow()
                    monitor.highlightItem(item.id)
                } label: {
                    Image(systemName: item.history.lastRequestResult?.statusIconName ?? "circle.dashed")
                    Text(item.displayTitle)
                    if let requestResult = item.history.lastRequestResult {
                        Text([
                            requestResult.statusTitle ,
                            requestResult.statusCode != nil ? "Code \(requestResult.statusCode!)" : "",
                            requestResult.date.formatted(date: .numeric, time: .standard)
                        ].filter { !$0.isEmpty }.joined(separator: " • "))
                    }
                }
                .disabled(!item.isEnabled)
            }
        }
        Divider()
        Button("Beenden") {
            NSApp.terminate(nil)
        }
    }
}
