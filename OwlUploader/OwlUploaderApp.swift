//
//  OwlUploaderApp.swift
//  OwlUploader
//
//  Created by Sanvi Lu on 2025/5/25.
//

import SwiftUI

@main
struct OwlUploaderApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .defaultSize(width: 1200, height: 800)
        .windowStyle(.hiddenTitleBar)
        .windowToolbarStyle(.unified(showsTitle: true))
        .commands {
            CommandGroup(replacing: .newItem) { }
            AppCommands()
            ViewModeCommands()
        }

        // macOS 原生设置窗口
        Settings {
            AccountSettingsView()
                .environmentObject(R2Service.shared)
                .environmentObject(R2AccountManager.shared)
                .environmentObject(MessageManager())
        }
    }
}
