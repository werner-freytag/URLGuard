import SwiftUI

struct MenuBarContentView: View {
    @ObservedObject var monitor: URLMonitor
    
    var body: some View {
        Button("Open") {
            NSApp.openMainWindow()
        }
        Divider()
        Button(monitor.isGlobalPaused ? "Start Monitoring" : "Pause Monitoring") {
            monitor.isGlobalPaused ? monitor.startGlobal() : monitor.pauseGlobal()
        }
        
        Divider()
        if monitor.items.isEmpty {
            Text("No entries")
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
                            Text("1 marked entry")
                        } else {
                            Text("\(markedCount) marked entries")
                        }
                    }
                }
                .disabled(!item.isEnabled)
            }
        }
        Divider()
        Button("Quit") {
            NSApp.terminate(nil)
        }
    }
}
