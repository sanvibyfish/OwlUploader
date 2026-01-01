//
//  AnimationConstants.swift
//  OwlUploader
//
//  统一的动画常量定义
//  确保整个应用的动画效果一致且流畅
//

import SwiftUI

/// 应用动画常量
enum AppAnimations {
    // MARK: - 标准过渡动画

    /// 标准过渡动画 (0.2s)
    static let standard = Animation.easeInOut(duration: 0.2)

    /// 快速过渡动画 (0.1s)
    static let fast = Animation.easeInOut(duration: 0.1)

    /// 慢速过渡动画 (0.35s)
    static let slow = Animation.easeInOut(duration: 0.35)

    // MARK: - 弹簧动画

    /// 标准弹簧动画
    static let spring = Animation.spring(response: 0.3, dampingFraction: 0.7)

    /// 轻弹簧动画（更有弹性）
    static let bouncy = Animation.spring(response: 0.4, dampingFraction: 0.6)

    /// 刚性弹簧动画（较少弹跳）
    static let stiff = Animation.spring(response: 0.25, dampingFraction: 0.85)

    // MARK: - 交互动画

    /// Hover效果动画
    static let hover = Animation.easeOut(duration: 0.15)

    /// 选中状态变化动画
    static let selection = Animation.easeInOut(duration: 0.12)

    /// 按钮按压动画
    static let buttonPress = Animation.easeOut(duration: 0.1)

    // MARK: - 列表动画

    /// 列表项插入动画
    static let listInsert = Animation.spring(response: 0.35, dampingFraction: 0.8)

    /// 列表项移除动画
    static let listRemove = Animation.easeOut(duration: 0.2)

    /// 列表项移动动画
    static let listMove = Animation.spring(response: 0.4, dampingFraction: 0.75)

    // MARK: - 面板动画

    /// 面板展开/收起动画
    static let panel = Animation.spring(response: 0.35, dampingFraction: 0.8)

    /// 弹窗出现动画
    static let popup = Animation.spring(response: 0.3, dampingFraction: 0.75)

    /// 侧边栏动画
    static let sidebar = Animation.easeInOut(duration: 0.25)

    // MARK: - 进度动画

    /// 进度条更新动画
    static let progress = Animation.easeInOut(duration: 0.3)

    /// 加载指示器动画
    static let loading = Animation.linear(duration: 1.0).repeatForever(autoreverses: false)

    // MARK: - 消息动画

    /// 消息横幅出现
    static let messageAppear = Animation.spring(response: 0.4, dampingFraction: 0.7)

    /// 消息横幅消失
    static let messageDisappear = Animation.easeOut(duration: 0.25)
}

// MARK: - 过渡效果

enum AppTransitions {
    /// 标准淡入淡出
    static let fade = AnyTransition.opacity

    /// 从上方滑入
    static let slideFromTop = AnyTransition.move(edge: .top).combined(with: .opacity)

    /// 从下方滑入
    static let slideFromBottom = AnyTransition.move(edge: .bottom).combined(with: .opacity)

    /// 从右侧滑入
    static let slideFromTrailing = AnyTransition.move(edge: .trailing).combined(with: .opacity)

    /// 从左侧滑入
    static let slideFromLeading = AnyTransition.move(edge: .leading).combined(with: .opacity)

    /// 缩放淡入
    static let scaleAndFade = AnyTransition.scale(scale: 0.9).combined(with: .opacity)

    /// 列表项过渡（插入从上，移除向下）
    static let listItem = AnyTransition.asymmetric(
        insertion: .move(edge: .top).combined(with: .opacity),
        removal: .opacity
    )

    /// 消息横幅过渡
    static let messageBanner = AnyTransition.asymmetric(
        insertion: .move(edge: .top).combined(with: .opacity),
        removal: .move(edge: .trailing).combined(with: .opacity)
    )

    /// hover 操作按钮过渡
    static let hoverActions = AnyTransition.opacity.combined(
        with: .scale(scale: 0.9, anchor: .trailing)
    )
}

// MARK: - View 扩展

extension View {
    /// 应用标准hover动画
    func animateOnHover(_ isHovering: Bool) -> some View {
        self.animation(AppAnimations.hover, value: isHovering)
    }

    /// 应用选中状态动画
    func animateSelection(_ isSelected: Bool) -> some View {
        self.animation(AppAnimations.selection, value: isSelected)
    }

    /// 应用标准过渡动画
    func standardAnimation<V: Equatable>(_ value: V) -> some View {
        self.animation(AppAnimations.standard, value: value)
    }

    /// 应用弹簧动画
    func springAnimation<V: Equatable>(_ value: V) -> some View {
        self.animation(AppAnimations.spring, value: value)
    }

    /// 应用面板动画
    func panelAnimation<V: Equatable>(_ value: V) -> some View {
        self.animation(AppAnimations.panel, value: value)
    }
}

// MARK: - 时长常量

enum AnimationDurations {
    /// 快速 (100ms)
    static let fast: Double = 0.1

    /// 标准 (200ms)
    static let standard: Double = 0.2

    /// 中等 (300ms)
    static let medium: Double = 0.3

    /// 慢速 (350ms)
    static let slow: Double = 0.35

    /// 消息显示时长 - 成功消息 (4s)
    static let messageSuccess: Double = 4.0

    /// 消息显示时长 - 错误消息 (6s)
    static let messageError: Double = 6.0

    /// 消息显示时长 - 警告消息 (5s)
    static let messageWarning: Double = 5.0

    /// 消息显示时长 - 信息消息 (4s)
    static let messageInfo: Double = 4.0
}
