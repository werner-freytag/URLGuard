import Combine
import SwiftData
import SwiftUI

@main
struct URLGuardApp: App {
    #if os(macOS)
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @AppStorage("showStatusBarIcon") var showStatusBarIcon: Bool = true
    private var dockBadgeCancellable: AnyCancellable?
    #endif

    @StateObject private var monitor = URLMonitor()
    @State private var editingItem: URLItem? = nil

    init() {
        #if os(macOS)
        dockBadgeCancellable = monitor.$items
            .receive(on: DispatchQueue.main)
            .sink { items in
                let count = items.map(\.history.markedCount).reduce(0, +)
                NSApp.dockTile.badgeLabel = count > 0 ? "\(count)" : nil
            }
        #endif
    }

    var body: some Scene {
        #if os(macOS)
        Window("URL Guard", id: "MainWindow") {
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
                        } else {
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
        }
        #endif
    }
}
