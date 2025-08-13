import Combine
import UserNotifications
import SwiftData
import SwiftUI

@main
struct URLGuardApp: App {
    #if os(macOS)
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @AppStorage("showStatusBarIcon") var showStatusBarIcon: Bool = true
    @State private var dockBadgeCancellable: AnyCancellable?
    #endif

    @StateObject private var monitor = URLMonitor()
    @State private var editingItem: URLItem? = nil
    @State private var highlightCancellable: AnyCancellable?

    var body: some Scene {
        #if os(macOS)
        Window("URL Guard", id: "MainWindow") {
            ContentView(monitor: monitor)
                .toolbar {
                    ToolbarItemGroup(placement: .primaryAction) {
                        if monitor.isGlobalPaused {
                            Button("Starten", systemImage: "play.circle.fill") {
                                monitor.startGlobal()
                            }
                        } else {
                            Button("Pausieren", systemImage: "pause.circle.fill") {
                                monitor.pauseGlobal()
                            }
                        }

                        Spacer(minLength: 40)
                        
                        Button("Neuer Eintrag", systemImage: "plus.circle") {
                            editingItem = URLItem()
                        }
                        
                        Spacer(minLength: 40)
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
                .onAppear {
                    if let window = NSApplication.shared.windows.first {
                        window.toolbar?.displayMode = .iconAndLabel
                    }
                }
                .onAppear {
                    dockBadgeCancellable = monitor.$items
                        .receive(on: DispatchQueue.main)
                        .sink { items in
                            let count = items.map { $0.history.markedCount }.reduce(0, +)
                            NSApp.dockTile.badgeLabel = count > 0 ? "\(count)" : nil
                        }
                }
                .onAppear {
                    // NotificationManager als Delegate für UserNotifications registrieren
                    UNUserNotificationCenter.current().delegate = NotificationManager.shared
                }
                .onAppear {
                    // NotificationManager-Subscription für Highlight-Requests
                    highlightCancellable = NotificationManager.shared.highlightRequestPublisher
                        .receive(on: DispatchQueue.main)
                        .sink { itemId in
                            monitor.highlightItem(itemId)
                        }
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
            CommandGroup(replacing: .windowArrangement) {}
            CommandGroup(replacing: .toolbar) {}
            CommandGroup(replacing: .windowSize) {
                Button("Fenster schließen") {
                    NSApplication.shared.keyWindow?.close()
                }
                .keyboardShortcut("w", modifiers: .command)
            }
            CommandGroup(after: .newItem) {
                Button(monitor.isGlobalPaused ? "Monitoring starten" : "Monitoring pausieren") {
                    monitor.isGlobalPaused ? monitor.startGlobal() : monitor.pauseGlobal()
                }
                .keyboardShortcut("p", modifiers: [.command, .shift])
            }
        }

        MenuBarExtra("URL Guard", image: "StatusbarIcon", isInserted: .constant(showStatusBarIcon)) {
            MenuBarContentView(monitor: monitor)
        }

        Settings {
            SettingsView()
        }
        #else
        WindowGroup {
            NavigationStack {
                ContentView(monitor: monitor)
                    .navigationTitle("URL Guard")
                    .toolbarTitleDisplayMode(.inlineLarge)
                    .toolbar {
                        if #available(iOS 16.0, *) {
                            ToolbarItemGroup(placement: .topBarTrailing) {
                                Button(action: {
                                    monitor.isGlobalPaused ? monitor.startGlobal() : monitor.pauseGlobal()
                                }) {
                                    Image(systemName: monitor.isGlobalPaused ? "pause.circle.fill" : "play.circle.fill")
                                }
                                .disabled(monitor.items.isEmpty)
                                .accessibilityLabel(monitor.isGlobalPaused ? "Monitoring starten" : "Monitoring pausieren")

                                Button(action: { editingItem = URLItem() }) {
                                    Image(systemName: "plus.circle.fill")
                                }
                                .accessibilityLabel("Neuer Eintrag")
                            }
                        } else {
                            ToolbarItemGroup(placement: .navigationBarTrailing) {
                                Button(action: {
                                    monitor.isGlobalPaused ? monitor.startGlobal() : monitor.pauseGlobal()
                                }) {
                                    Image(systemName: monitor.isGlobalPaused ? "pause.circle.fill" : "play.circle.fill")
                                }
                                .disabled(monitor.items.isEmpty)
                                .accessibilityLabel(monitor.isGlobalPaused ? "Monitoring starten" : "Monitoring pausieren")

                                Button(action: { editingItem = URLItem() }) {
                                    Image(systemName: "plus.circle.fill")
                                }
                                .accessibilityLabel("Neuer Eintrag")
                            }
                        }
                    }
            }
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
            .onAppear {
                // iOS-spezifischer UNUserNotificationCenterDelegate
                UNUserNotificationCenter.current().delegate = NotificationManager.shared
            }
        }
        #endif
    }
}
