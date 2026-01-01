//
//  SelectionManager.swift
//  OwlUploader
//
//  选择状态管理器
//  支持单选、Cmd多选、Shift范围选择，类似Finder的选择行为
//

import SwiftUI

/// 选择模式枚举
enum SelectionMode {
    case single      // 普通点击：选中当前项，清除其他
    case toggle      // Cmd+点击：切换选中状态
    case range       // Shift+点击：范围选择
    case additive    // 添加到选择（不清除现有）
}

/// 选择状态管理器
@MainActor
class SelectionManager: ObservableObject {
    /// 选中项的key集合
    @Published var selectedItems: Set<String> = []

    /// 最后选中的项（用于Shift范围选择）
    @Published private(set) var lastSelectedItem: String?

    /// 锚点项（范围选择的起点）
    @Published private(set) var anchorItem: String?

    /// 选中项数量
    var selectedCount: Int {
        selectedItems.count
    }

    /// 是否有选中项
    var hasSelection: Bool {
        !selectedItems.isEmpty
    }

    /// 是否为多选状态
    var isMultipleSelection: Bool {
        selectedItems.count > 1
    }

    // MARK: - 选择操作

    /// 选择项目
    /// - Parameters:
    ///   - key: 要选择的项目key
    ///   - mode: 选择模式
    ///   - allKeys: 所有项目的key列表（用于范围选择）
    func select(_ key: String, mode: SelectionMode, allKeys: [String] = []) {
        switch mode {
        case .single:
            // 单选：清除其他，只选中当前
            selectedItems = [key]
            anchorItem = key
            lastSelectedItem = key

        case .toggle:
            // 切换：已选中则取消，未选中则添加
            if selectedItems.contains(key) {
                selectedItems.remove(key)
                // 如果取消的是锚点，更新锚点为最后一个选中项
                if anchorItem == key {
                    anchorItem = selectedItems.first
                }
            } else {
                selectedItems.insert(key)
                anchorItem = key
            }
            lastSelectedItem = key

        case .range:
            // 范围选择：从锚点到当前项的所有项目
            guard let anchor = anchorItem ?? selectedItems.first,
                  !allKeys.isEmpty else {
                // 没有锚点时，当作单选处理
                select(key, mode: .single, allKeys: allKeys)
                return
            }

            // 找到锚点和当前项的索引
            guard let anchorIndex = allKeys.firstIndex(of: anchor),
                  let currentIndex = allKeys.firstIndex(of: key) else {
                select(key, mode: .single, allKeys: allKeys)
                return
            }

            // 计算范围
            let start = min(anchorIndex, currentIndex)
            let end = max(anchorIndex, currentIndex)

            // 选中范围内的所有项
            let rangeKeys = allKeys[start...end]
            selectedItems = Set(rangeKeys)
            lastSelectedItem = key
            // 锚点保持不变

        case .additive:
            // 添加模式：仅添加，不清除
            selectedItems.insert(key)
            if anchorItem == nil {
                anchorItem = key
            }
            lastSelectedItem = key
        }
    }

    /// 检查项目是否被选中
    func isSelected(_ key: String) -> Bool {
        selectedItems.contains(key)
    }

    /// 清除所有选择
    func clearSelection() {
        selectedItems.removeAll()
        lastSelectedItem = nil
        anchorItem = nil
    }

    /// 全选
    func selectAll(_ keys: [String]) {
        selectedItems = Set(keys)
        if let first = keys.first {
            anchorItem = first
        }
        if let last = keys.last {
            lastSelectedItem = last
        }
    }

    /// 反选
    func invertSelection(_ allKeys: [String]) {
        let allSet = Set(allKeys)
        selectedItems = allSet.subtracting(selectedItems)
        anchorItem = selectedItems.first
        lastSelectedItem = selectedItems.first
    }

    /// 移除指定项的选择
    func deselect(_ key: String) {
        selectedItems.remove(key)
        if anchorItem == key {
            anchorItem = selectedItems.first
        }
        if lastSelectedItem == key {
            lastSelectedItem = selectedItems.first
        }
    }

    /// 移除多个项的选择
    func deselect(_ keys: [String]) {
        for key in keys {
            selectedItems.remove(key)
        }
        if let anchor = anchorItem, keys.contains(anchor) {
            anchorItem = selectedItems.first
        }
        if let last = lastSelectedItem, keys.contains(last) {
            lastSelectedItem = selectedItems.first
        }
    }

    // MARK: - 辅助方法

    /// 根据修饰键判断选择模式
    static func modeFromModifiers(_ modifiers: NSEvent.ModifierFlags) -> SelectionMode {
        if modifiers.contains(.command) && modifiers.contains(.shift) {
            // Cmd+Shift：范围添加（暂时当作范围处理）
            return .range
        } else if modifiers.contains(.command) {
            return .toggle
        } else if modifiers.contains(.shift) {
            return .range
        } else {
            return .single
        }
    }

    /// 获取当前选中的keys数组
    func getSelectedKeys() -> [String] {
        Array(selectedItems)
    }
}

// MARK: - FileObject 扩展

extension SelectionManager {
    /// 使用FileObject选择
    func select(_ file: FileObject, mode: SelectionMode, allFiles: [FileObject]) {
        let allKeys = allFiles.map { $0.key }
        select(file.key, mode: mode, allKeys: allKeys)
    }

    /// 检查FileObject是否被选中
    func isSelected(_ file: FileObject) -> Bool {
        isSelected(file.key)
    }

    /// 全选FileObjects
    func selectAll(_ files: [FileObject]) {
        selectAll(files.map { $0.key })
    }
}
