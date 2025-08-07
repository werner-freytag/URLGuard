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
                let entry = item.history.last

                Button {
                    NSApp.openMainWindow()
                    monitor.highlightItem(item.id)
                } label: {
                    Image(systemName: entry?.statusIconName ?? "circle.dashed")
                    Text(item.displayTitle)
                    if let entry {
                        Text([
                            entry.statusTitle ,
                            entry.requestResult.statusCode != nil ? "Code \(entry.requestResult.statusCode!)" : "",
                            entry.requestResult.date.formatted(date: .numeric, time: .standard)
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

