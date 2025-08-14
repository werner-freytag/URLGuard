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
                    Text(item.displayTitle)
                    
                    let markedCount = item.history.markedCount

                    if markedCount > 0 {
                        if markedCount == 1 {
                            Text("1 markierter Eintrag")
                        } else {
                            Text("\(markedCount) markierte Einträge")
                        }
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
