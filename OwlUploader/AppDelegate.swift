//
//  AppDelegate.swift
//  OwlUploader
//
//  Application delegate for handling window lifecycle events
//

import SwiftUI
import AppKit

class AppDelegate: NSObject, NSApplicationDelegate {
    private var isQuitting = false
    private var windowObserver: NSObjectProtocol?

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupWindowObserver()
    }

    private func setupWindowObserver() {
        // 监听所有窗口关闭事件
        windowObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            self?.handleWindowWillClose(notification)
        }
    }

    private func handleWindowWillClose(_ notification: Notification) {
        guard let window = notification.object as? NSWindow else { return }

        // 防止递归调用
        guard !isQuitting else { return }

        // 检查是否为设置窗口
        let isSettingsWindow = window.identifier?.rawValue.contains("Settings") ?? false
        if isSettingsWindow {
            // 允许设置窗口独立关闭
            return
        }

        // 检查是否为主窗口
        let isMainWindow = window.styleMask.contains(.titled) &&
                          window.styleMask.contains(.closable) &&
                          window.isMainWindow

        if isMainWindow {
            // 窗口关闭后检查是否需要退出
            DispatchQueue.main.async { [weak self] in
                self?.checkAndQuitIfNeeded()
            }
        }
    }

    private func checkAndQuitIfNeeded() {
        // 统计非设置窗口数量
        let nonSettingsWindows = NSApp.windows.filter { window in
            let isSettings = window.identifier?.rawValue.contains("Settings") ?? false
            return !isSettings && window.isVisible
        }

        // 如果没有主窗口，退出应用
        if nonSettingsWindows.isEmpty {
            isQuitting = true
            NSApp.terminate(nil)
        }
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        // 预留：可在此处检查正在进行的上传/下载任务
        return .terminateNow
    }

    func applicationWillTerminate(_ notification: Notification) {
        // 清理资源
        if let observer = windowObserver {
            NotificationCenter.default.removeObserver(observer)
        }

        print("Application terminating")
    }

    deinit {
        if let observer = windowObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }
}
