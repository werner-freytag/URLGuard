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
                            monitor.createNewItem()
                            // Das neu erstellte Item ist das letzte in der Liste
                            if let newItem = monitor.items.last {
                                editingItem = newItem
                            }
                        }) {
                            HStack(spacing: 6) {
                                Image(systemName: "plus.circle.fill")
                                    .font(.title3)
                                Text("Eintrag hinzufügen")
                                    .font(.body)
                                    .fontWeight(.medium)
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Color.blue)
                            .cornerRadius(8)
                        }
                        .buttonStyle(.plain)
                        .help("Eintrag hinzufügen")
                    }
                }
                .toolbar(.visible, for: .windowToolbar)
                .toolbar(.automatic, for: .windowToolbar)
                .sheet(item: $editingItem) { item in
                    // Prüfe ob es ein neues Item ist (nicht in der Liste vorhanden)
                    let isNewItem = !monitor.items.contains { $0.id == item.id }
                    
                    ModalEditorView(
                        item: item, 
                        monitor: monitor, 
                        isNewItem: isNewItem,
                        onSave: { newItem in
                            // Neues Item hinzufügen
                            monitor.addItem(newItem)
                        }
                    )
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
