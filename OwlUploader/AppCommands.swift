//
//  AppCommands.swift
//  OwlUploader
//
//  应用级键盘命令
//  使用FocusedValue在主菜单中集成快捷键
//

import SwiftUI

// MARK: - FocusedValue Keys

/// 文件操作焦点值
struct FileActionsKey: FocusedValueKey {
    typealias Value = FileActions
}

extension FocusedValues {
    var fileActions: FileActions? {
        get { self[FileActionsKey.self] }
        set { self[FileActionsKey.self] = newValue }
    }
}

/// 文件操作协议
struct FileActions {
    var selectAll: () -> Void
    var deselectAll: () -> Void
    var deleteSelected: () -> Void
    var refresh: () -> Void
    var goUp: () -> Void
    var newFolder: () -> Void
    var hasSelection: Bool
    var canGoUp: Bool
}

// MARK: - 应用命令

struct AppCommands: Commands {
    @FocusedValue(\.fileActions) var fileActions

    var body: some Commands {
        // 文件菜单
        CommandGroup(after: .newItem) {
            Button(L.Commands.newFolder) {
                fileActions?.newFolder()
            }
            .keyboardShortcut("n", modifiers: [.command, .shift])
            .disabled(fileActions == nil)
        }

        // 编辑菜单
        CommandGroup(after: .pasteboard) {
            Divider()

            Button(L.Commands.selectAll) {
                fileActions?.selectAll()
            }
            .keyboardShortcut("a", modifiers: .command)
            .disabled(fileActions == nil)

            Button(L.Commands.deselectAll) {
                fileActions?.deselectAll()
            }
            .keyboardShortcut("d", modifiers: .command)
            .disabled(fileActions == nil || fileActions?.hasSelection != true)
        }

        // 视图菜单
        CommandGroup(replacing: .sidebar) {
            Button(L.Commands.refresh) {
                fileActions?.refresh()
            }
            .keyboardShortcut("r", modifiers: .command)
            .disabled(fileActions == nil)

            Divider()

            Button(L.Commands.goUp) {
                fileActions?.goUp()
            }
            .keyboardShortcut(.upArrow, modifiers: .command)
            .disabled(fileActions == nil || fileActions?.canGoUp != true)
        }
    }
}

// MARK: - 视图模式命令

struct ViewModeKey: FocusedValueKey {
    typealias Value = ViewModeActions
}

extension FocusedValues {
    var viewModeActions: ViewModeActions? {
        get { self[ViewModeKey.self] }
        set { self[ViewModeKey.self] = newValue }
    }
}

struct ViewModeActions {
    var setTableMode: () -> Void
    var setIconsMode: () -> Void
    var currentMode: FileViewMode
}

struct ViewModeCommands: Commands {
    @FocusedValue(\.viewModeActions) var viewModeActions

    var body: some Commands {
        CommandMenu(L.Commands.view) {
            Button(L.Commands.tableView) {
                viewModeActions?.setTableMode()
            }
            .keyboardShortcut("2", modifiers: .command)

            Button(L.Commands.iconView) {
                viewModeActions?.setIconsMode()
            }
            .keyboardShortcut("3", modifiers: .command)
        }
    }
}
