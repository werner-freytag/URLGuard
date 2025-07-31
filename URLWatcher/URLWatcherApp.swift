//
//  URLWatcherApp.swift
//  URLWatcher
//
//  Created by Freytag, Werner on 31.07.25.
//

import SwiftUI
import SwiftData

@main
struct URLWatcherApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var monitor = URLMonitor()
    @State private var editingItem: URLItem? = nil

    var body: some Scene {
        Window("URL Monitor", id: "main") {
            ContentView(monitor: monitor)
                .toolbar {
                    // Gruppe 1: Erstellung
                    ToolbarItemGroup(placement: .primaryAction) {
                        Button(action: {
                            monitor.addNewItem()
                            if let newItem = monitor.items.first(where: { $0.isNewItem }) {
                                editingItem = newItem
                            }
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: "plus.circle")
                                Text("Eintrag hinzufügen")
                            }
                        }
                        .buttonStyle(.plain)
                        .help("Eintrag hinzufügen")
                    }
                }
                .toolbar(.visible, for: .windowToolbar)
                .toolbar(.automatic, for: .windowToolbar)
                .sheet(item: $editingItem) { item in
                    ModalEditorView(item: item, monitor: monitor)
                }
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified)
        .defaultSize(width: 600, height: 400)
        .windowResizability(.contentSize)
        .commands {
            // App beenden wenn Fenster geschlossen wird
            CommandGroup(replacing: .newItem) { }
            CommandGroup(replacing: .windowSize) { }
            CommandGroup(replacing: .windowArrangement) { }
        }

        Settings {
            EmptyView() // Keine extra Settings
        }
    }
}
