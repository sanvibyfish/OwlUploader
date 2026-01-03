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
        .windowStyle(.hiddenTitleBar)  // 隐藏标题栏，使用统一工具栏
        .windowToolbarStyle(.unified(showsTitle: true))  // Finder 风格统一工具栏
        .commands {
            CommandGroup(replacing: .newItem) { }
            AppCommands()
            ViewModeCommands()
        }
    }
}
