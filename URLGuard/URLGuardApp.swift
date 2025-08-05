import SwiftUI
import Combine
import SwiftData

@main
struct URLGuardApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    private let monitor = URLMonitor()
    @State private var editingItem: URLItem? = nil

    @AppStorage("showStatusBarIcon") var showStatusBarIcon: Bool = true
    
    private var dockBadgeCancellable: AnyCancellable?
    
    init() {
        let notificationManager = NotificationManager.shared
        
        dockBadgeCancellable = monitor.$items
            .receive(on: DispatchQueue.main)
            .sink { items in
                let count = items.map { item in
                    item.history.filter {
                        notificationManager.notification(for: item, status: $0.status, httpStatusCode: $0.httpStatusCode) != nil
                    }.count
                }.reduce(0, +)

                NSApp.dockTile.badgeLabel = count > 0 ? "\(count)" : nil
            }
    }

    var body: some Scene {
        Window("URL Guard", id: "main") {
            ContentView(monitor: monitor)
                .toolbar {
                    ToolbarItemGroup(placement: .primaryAction) {
                        if monitor.isGlobalPaused {
                            IconButton(
                                icon: "pause.circle.fill",
                                title: "Pausiert",
                                color: .orange,
                                isDisabled: monitor.items.isEmpty
                            ) {
                                monitor.startGlobal()
                            }
                            .keyframeAnimator(initialValue: 1.0, repeating: true) { content, opacity in
                                content
                                    .opacity(opacity)
                            } keyframes: { _ in
                                KeyframeTrack(\.self) {
                                    LinearKeyframe(1.0, duration: 3.0)
                                    LinearKeyframe(0.3, duration: 0.75, timingCurve: .easeInOut)
                                    LinearKeyframe(1.0, duration: 0.75, timingCurve: .easeInOut)
                                }
                            }
                        }
                        else {
                            IconButton(
                                icon: "play.circle.fill",
                                title: "Gestartet",
                                color: .green,
                                isDisabled: monitor.items.isEmpty
                            ) {
                                monitor.pauseGlobal()
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
                    monitor.isGlobalPaused ? monitor.startGlobal() : monitor.pauseGlobal()
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
                monitor.isGlobalPaused ? monitor.startGlobal() : monitor.pauseGlobal()
            }
            
            Divider()
            if monitor.items.isEmpty {
                Text("Keine Einträge")
            } else {
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
