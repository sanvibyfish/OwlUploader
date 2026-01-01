//
//  ViewModeManager.swift
//  OwlUploader
//
//  视图模式管理器
//  支持列表视图和图标网格视图切换，类似Finder
//

import SwiftUI

/// 文件视图模式
enum FileViewMode: String, CaseIterable, Identifiable {
    case list       // 列表视图（带列头，详细信息）
    case icons      // 图标网格视图

    var id: String { rawValue }

    /// 模式对应的SF Symbol图标
    var iconName: String {
        switch self {
        case .list:
            return "list.bullet"
        case .icons:
            return "square.grid.2x2"
        }
    }

    /// 模式名称（用于辅助功能）
    var displayName: String {
        switch self {
        case .list:
            return "列表"
        case .icons:
            return "图标"
        }
    }

    /// 快捷键提示
    var keyboardShortcutHint: String {
        switch self {
        case .list:
            return "Cmd+2"
        case .icons:
            return "Cmd+3"
        }
    }
}

/// 图标大小预设
enum IconSize: String, CaseIterable, Identifiable {
    case small      // 48pt
    case medium     // 64pt (默认)
    case large      // 96pt
    case extraLarge // 128pt

    var id: String { rawValue }

    var size: CGFloat {
        switch self {
        case .small:
            return 48
        case .medium:
            return 64
        case .large:
            return 96
        case .extraLarge:
            return 128
        }
    }

    var displayName: String {
        switch self {
        case .small:
            return "小"
        case .medium:
            return "中"
        case .large:
            return "大"
        case .extraLarge:
            return "特大"
        }
    }
}

/// 视图模式管理器
@MainActor
class ViewModeManager: ObservableObject {
    /// 当前视图模式
    @Published var currentMode: FileViewMode {
        didSet {
            savePreferences()
        }
    }

    /// 图标大小（图标视图模式下使用）
    @Published var iconSize: IconSize {
        didSet {
            savePreferences()
        }
    }

    /// 是否显示预览面板（三栏布局）
    @Published var showPreviewPanel: Bool {
        didSet {
            savePreferences()
        }
    }

    /// 是否显示文件扩展名
    @Published var showFileExtensions: Bool {
        didSet {
            savePreferences()
        }
    }

    /// 列表视图是否显示修改日期列
    @Published var showDateColumn: Bool {
        didSet {
            savePreferences()
        }
    }

    /// 列表视图是否显示大小列
    @Published var showSizeColumn: Bool {
        didSet {
            savePreferences()
        }
    }

    /// 列表视图是否显示类型列
    @Published var showTypeColumn: Bool {
        didSet {
            savePreferences()
        }
    }

    // MARK: - UserDefaults Keys

    private enum Keys {
        static let viewMode = "fileViewMode"
        static let iconSize = "iconSize"
        static let showPreviewPanel = "showPreviewPanel"
        static let showFileExtensions = "showFileExtensions"
        static let showDateColumn = "showDateColumn"
        static let showSizeColumn = "showSizeColumn"
        static let showTypeColumn = "showTypeColumn"
    }

    // MARK: - 初始化

    init() {
        // 从UserDefaults加载偏好设置
        let defaults = UserDefaults.standard

        if let modeString = defaults.string(forKey: Keys.viewMode),
           let mode = FileViewMode(rawValue: modeString) {
            self.currentMode = mode
        } else {
            self.currentMode = .list
        }

        if let sizeString = defaults.string(forKey: Keys.iconSize),
           let size = IconSize(rawValue: sizeString) {
            self.iconSize = size
        } else {
            self.iconSize = .medium
        }

        self.showPreviewPanel = defaults.bool(forKey: Keys.showPreviewPanel)
        self.showFileExtensions = defaults.object(forKey: Keys.showFileExtensions) as? Bool ?? true
        self.showDateColumn = defaults.object(forKey: Keys.showDateColumn) as? Bool ?? true
        self.showSizeColumn = defaults.object(forKey: Keys.showSizeColumn) as? Bool ?? true
        self.showTypeColumn = defaults.object(forKey: Keys.showTypeColumn) as? Bool ?? false
    }

    // MARK: - 公开方法

    /// 切换视图模式
    func toggleMode() {
        currentMode = currentMode == .list ? .icons : .list
    }

    /// 设置视图模式
    func setMode(_ mode: FileViewMode) {
        currentMode = mode
    }

    /// 切换预览面板显示
    func togglePreviewPanel() {
        showPreviewPanel.toggle()
    }

    /// 增大图标
    func increaseIconSize() {
        guard let currentIndex = IconSize.allCases.firstIndex(of: iconSize),
              currentIndex < IconSize.allCases.count - 1 else { return }
        iconSize = IconSize.allCases[currentIndex + 1]
    }

    /// 减小图标
    func decreaseIconSize() {
        guard let currentIndex = IconSize.allCases.firstIndex(of: iconSize),
              currentIndex > 0 else { return }
        iconSize = IconSize.allCases[currentIndex - 1]
    }

    /// 获取当前图标尺寸值
    var currentIconSize: CGFloat {
        iconSize.size
    }

    // MARK: - 私有方法

    private func savePreferences() {
        let defaults = UserDefaults.standard
        defaults.set(currentMode.rawValue, forKey: Keys.viewMode)
        defaults.set(iconSize.rawValue, forKey: Keys.iconSize)
        defaults.set(showPreviewPanel, forKey: Keys.showPreviewPanel)
        defaults.set(showFileExtensions, forKey: Keys.showFileExtensions)
        defaults.set(showDateColumn, forKey: Keys.showDateColumn)
        defaults.set(showSizeColumn, forKey: Keys.showSizeColumn)
        defaults.set(showTypeColumn, forKey: Keys.showTypeColumn)
    }
}
