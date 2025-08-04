import SwiftUI
import SwiftData

@main
struct URLGuardApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var monitor = URLMonitor()
    @State private var editingItem: URLItem? = nil

    @AppStorage("showStatusBarIcon") var showStatusBarIcon: Bool = true

    var body: some Scene {
        Window("URL Guard", id: "main") {
            ContentView(monitor: monitor)
                .toolbar {
                    ToolbarItemGroup(placement: .primaryAction) {
                        IconButton(
                            icon: monitor.isGlobalPaused ? "pause.circle.fill" : "play.circle.fill",
                            title: monitor.isGlobalPaused ? "Starten" : "Gestartet",
                            color: monitor.isGlobalPaused ? .orange : .green,
                            isDisabled: monitor.items.isEmpty
                        ) {
                            monitor.toggleGlobalPause()
                        }
                        .keyframeAnimator(initialValue: 1.0, repeating: true) { content, opacity in
                            content
                                .opacity(opacity)
                        } keyframes: { _ in
                            KeyframeTrack(\.self) {
                                LinearKeyframe(1.0, duration: 5.0)
                                LinearKeyframe(0.3, duration: 1.0, timingCurve: .easeInOut)
                                LinearKeyframe(1.0, duration: 1.0, timingCurve: .easeInOut)
                            }
                        }

                        IconButton(
                            icon: "plus.circle.fill",
                            title: "Neuer Eintrag",
                            color: .blue
                        ) {
                            editingItem = URLItem()
                        }
                    }
                }
                .toolbar(.visible, for: .windowToolbar)
                .toolbar(.automatic, for: .windowToolbar)
                .sheet(item: $editingItem) { item in
                    let isNewItem = !monitor.items.contains { $0.id == item.id }
                    
                    ModalEditorView(
                        item: item, 
                        monitor: monitor, 
                        isNewItem: isNewItem,
                        onSave: { newItem in
                            if isNewItem {
                                monitor.addItem(newItem)
                            }
                        }
                    )
                }
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified)
        .defaultSize(width: 600, height: 400)
        .windowResizability(.contentSize)
        .commands {
            CommandGroup(replacing: .newItem) { 
                Button("Neuer Eintrag") {
                    editingItem = URLItem()
                }
                .keyboardShortcut("n", modifiers: .command)
            }
            CommandGroup(replacing: .windowArrangement) { }
            CommandGroup(replacing: .toolbar) { }
            CommandGroup(replacing: .windowSize) {
                Button("Fenster schließen") {
                    NSApplication.shared.keyWindow?.close()
                }
                .keyboardShortcut("w", modifiers: .command)
            }
            CommandGroup(after: .newItem) {
                Button("Monitoring pausieren/starten") {
                    monitor.toggleGlobalPause()
                }
                .keyboardShortcut("p", modifiers: [.command, .shift])
            }
        }

        MenuBarExtra("URL Guard", image: "StatusbarIcon", isInserted: .constant(showStatusBarIcon)) {
            Button("Öffnen") {
                NSApp.activate(ignoringOtherApps: true)

                NSApp.windows.forEach { window in
                    if window.canBecomeKey {
                        window.makeKeyAndOrderFront(nil)
                    }
                }
            }
            Divider()
            Button(monitor.isGlobalPaused ? "Monitoring starten" : "Monitoring pausieren") {
                monitor.toggleGlobalPause()
            }
            
            if !monitor.items.isEmpty {
                Divider()
                
                ForEach(monitor.items) { item in
                    let entry = item.history.last

                    Button {} label: {
                        Image(systemName: entry?.statusIconName ?? "circle.dashed")
                        Text(item.displayTitle)
                        if let entry {
                            Text([
                                entry.statusTitle ,
                                entry.httpStatusCode != nil ? "Code \(entry.httpStatusCode!)" : "",
                                entry.date.formatted(date: .numeric, time: .standard)
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

        Settings {
            SettingsView()
        }
    }
}


private extension URLItem.HistoryEntry {
    var statusIconName: String {
        switch status {
        case .success: return "checkmark.circle.fill"
        case .changed: return "arrow.trianglehead.2.clockwise.rotate.90.circle.fill"
        case .error: return "exclamationmark.triangle.fill"
        }
    }
        
    var statusTitle: String {
        switch status {
        case .success: return "Erfolgreich"
        case .changed: return "Geändert"
        case .error: return "Fehler"
        }
    }
}
