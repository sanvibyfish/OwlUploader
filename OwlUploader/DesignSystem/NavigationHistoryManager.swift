//
//  NavigationHistoryManager.swift
//  OwlUploader
//
//  浏览历史管理器
//  实现类似 Finder 的前进/后退导航
//

import SwiftUI

/// 浏览历史管理器
/// 维护目录浏览的前进/后退栈
@MainActor
class NavigationHistoryManager: ObservableObject {
    /// 后退栈（历史记录）
    @Published private(set) var backStack: [String] = []
    
    /// 前进栈
    @Published private(set) var forwardStack: [String] = []
    
    /// 当前路径
    @Published private(set) var currentPath: String = ""
    
    /// 是否可以后退
    var canGoBack: Bool {
        !backStack.isEmpty
    }
    
    /// 是否可以前进
    var canGoForward: Bool {
        !forwardStack.isEmpty
    }
    
    // MARK: - 初始化
    
    init(initialPath: String = "") {
        self.currentPath = initialPath
    }
    
    // MARK: - 导航操作
    
    /// 导航到新位置
    /// - Parameter path: 目标路径
    /// - Parameter recordHistory: 是否记录历史（默认 true）
    func navigateTo(_ path: String, recordHistory: Bool = true) {
        // 如果路径相同，不做任何操作
        guard path != currentPath else { return }
        
        if recordHistory {
            // 将当前路径压入后退栈
            backStack.append(currentPath)
            
            // 导航到新位置时，清空前进栈
            forwardStack.removeAll()
        }
        
        // 更新当前路径
        currentPath = path
        
        print("📍 导航到: \(path.isEmpty ? "根目录" : path)")
        print("   后退栈: \(backStack.count) 项, 前进栈: \(forwardStack.count) 项")
    }
    
    /// 后退到上一个位置
    /// - Returns: 后退到的路径，如果无法后退则返回 nil
    func goBack() -> String? {
        guard canGoBack else {
            print("⚠️ 无法后退：已在历史起点")
            return nil
        }
        
        // 将当前路径压入前进栈
        forwardStack.append(currentPath)
        
        // 从后退栈弹出路径
        let previousPath = backStack.removeLast()
        currentPath = previousPath
        
        print("⬅️ 后退到: \(previousPath.isEmpty ? "根目录" : previousPath)")
        print("   后退栈: \(backStack.count) 项, 前进栈: \(forwardStack.count) 项")
        
        return previousPath
    }
    
    /// 前进到下一个位置
    /// - Returns: 前进到的路径，如果无法前进则返回 nil
    func goForward() -> String? {
        guard canGoForward else {
            print("⚠️ 无法前进：已在最新位置")
            return nil
        }
        
        // 将当前路径压入后退栈
        backStack.append(currentPath)
        
        // 从前进栈弹出路径
        let nextPath = forwardStack.removeLast()
        currentPath = nextPath
        
        print("➡️ 前进到: \(nextPath.isEmpty ? "根目录" : nextPath)")
        print("   后退栈: \(backStack.count) 项, 前进栈: \(forwardStack.count) 项")
        
        return nextPath
    }
    
    /// 清空历史记录
    func clearHistory() {
        backStack.removeAll()
        forwardStack.removeAll()
        print("🗑️ 已清空浏览历史")
    }
    
    /// 重置到指定路径（清空历史）
    /// - Parameter path: 新的起始路径
    func reset(to path: String = "") {
        clearHistory()
        currentPath = path
        print("🔄 重置浏览历史到: \(path.isEmpty ? "根目录" : path)")
    }
}
