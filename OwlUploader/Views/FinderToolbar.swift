//
//  FinderToolbar.swift
//  OwlUploader
//
//  Finder风格工具栏
//  三区布局：导航 | 搜索 | 操作
//

import SwiftUI

/// Finder风格工具栏
struct FinderToolbar: View {
    // MARK: - Bindings

    /// 搜索文本
    @Binding var searchText: String

    /// 视图模式
    @Binding var viewMode: FileViewMode

    /// 排序方式
    @Binding var sortOrder: FileSortOrder

    /// 筛选类型
    @Binding var filterType: FileFilterType

    // MARK: - 状态

    /// 是否可以返回上级
    let canGoUp: Bool

    /// 是否禁用操作（加载中等）
    let isDisabled: Bool

    /// 是否正在加载
    var isLoading: Bool = false

    /// 选中的文件数量
    var selectedCount: Int = 0

    // MARK: - 回调

    /// 返回上级
    let onGoUp: () -> Void

    /// 刷新
    let onRefresh: () -> Void

    /// 新建文件夹
    let onNewFolder: () -> Void

    /// 上传文件
    let onUpload: () -> Void

    /// 批量删除
    var onBatchDelete: (() -> Void)?

    /// 批量下载
    var onBatchDownload: (() -> Void)?

    var body: some View {
        HStack(spacing: 0) {
            // 左侧：导航区
            navigationSection
                .frame(width: 100)

            Spacer()

            // 中间：搜索区或批量操作区
            if selectedCount > 0 {
                batchActionsSection
            } else {
                searchSection
                    .frame(maxWidth: 280)
            }

            Spacer()

            // 右侧：操作区
            actionSection
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    // MARK: - 批量操作区

    /// 清除选择回调
    var onClearSelection: (() -> Void)?

    private var batchActionsSection: some View {
        HStack(spacing: 12) {
            Text(L.Files.itemsSelected(selectedCount))
                .font(.system(size: 13))
                .foregroundColor(AppColors.textSecondary)

            // 清除选择按钮
            Button(action: { onClearSelection?() }) {
                Image(systemName: "xmark.circle")
                    .font(.system(size: 12))
            }
            .buttonStyle(.plain)
            .foregroundColor(.secondary)
            .help(L.Help.clearSelection)

            Divider()
                .frame(height: 16)

            // 批量下载
            Button(action: { onBatchDownload?() }) {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.down.circle")
                        .font(.system(size: 12))
                    Text(L.Files.Toolbar.download)
                        .font(.system(size: 12))
                }
            }
            .buttonStyle(ToolbarButtonStyle())
            .disabled(isDisabled)

            // 批量删除
            Button(action: { onBatchDelete?() }) {
                HStack(spacing: 4) {
                    Image(systemName: "trash")
                        .font(.system(size: 12))
                    Text(L.Files.Toolbar.deleteAction)
                        .font(.system(size: 12))
                }
                .foregroundColor(AppColors.destructive)
            }
            .buttonStyle(ToolbarButtonStyle())
            .disabled(isDisabled)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(AppColors.primary.opacity(0.08))
        .cornerRadius(6)
    }

    // MARK: - 导航区

    private var navigationSection: some View {
        HStack(spacing: 4) {
            // 返回上级
            Button(action: onGoUp) {
                Image(systemName: "chevron.up")
                    .font(.system(size: 12, weight: .medium))
                    .frame(width: 28, height: 22)
            }
            .buttonStyle(ToolbarButtonStyle())
            .disabled(!canGoUp || isDisabled)
            .help(L.Help.goUp)

            // 刷新
            Button(action: onRefresh) {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 12, weight: .medium))
                    .frame(width: 28, height: 22)
            }
            .buttonStyle(ToolbarButtonStyle())
            .disabled(isDisabled)
            .help(L.Help.refresh)

            // 加载指示器（内联，不阻塞）
            if isLoading {
                ProgressView()
                    .scaleEffect(0.6)
                    .frame(width: 20, height: 20)
            }
        }
    }

    // MARK: - 搜索区

    private var searchSection: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 12))
                .foregroundColor(.secondary)

            TextField(L.Files.Toolbar.searchPlaceholder, text: $searchText)
                .textFieldStyle(.plain)
                .font(.system(size: 13))

            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(6)
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .strokeBorder(Color(nsColor: .separatorColor), lineWidth: 0.5)
        )
    }

    // MARK: - 操作区

    private var actionSection: some View {
        HStack(spacing: 4) {
            // 新建文件夹
            Button(action: onNewFolder) {
                Image(systemName: "folder.badge.plus")
                    .font(.system(size: 13))
                    .frame(width: 28, height: 22)
            }
            .buttonStyle(ToolbarButtonStyle())
            .disabled(isDisabled)
            .help(L.Help.newFolder)

            // 上传
            Button(action: onUpload) {
                Image(systemName: "arrow.up.doc")
                    .font(.system(size: 13))
                    .frame(width: 28, height: 22)
            }
            .buttonStyle(ToolbarButtonStyle())
            .disabled(isDisabled)
            .help(L.Help.uploadFile)

            Divider()
                .frame(height: 16)
                .padding(.horizontal, 4)

            // 筛选菜单
            Menu {
                ForEach(FileFilterType.allCases, id: \.self) { type in
                    Button {
                        filterType = type
                    } label: {
                        HStack {
                            Label(type.rawValue, systemImage: type.iconName)
                            if filterType == type {
                                Spacer()
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                Image(systemName: filterType == .all ? "line.3.horizontal.decrease" : "line.3.horizontal.decrease.circle.fill")
                    .font(.system(size: 13))
                    .frame(width: 28, height: 22)
                    .foregroundColor(filterType == .all ? .primary : AppColors.primary)
            }
            .menuStyle(.borderlessButton)
            .frame(width: 32)
            .help(L.Help.filter)

            // 排序菜单
            Menu {
                ForEach(FileSortOrder.allCases, id: \.self) { order in
                    Button {
                        sortOrder = order
                    } label: {
                        HStack {
                            Label(order.rawValue, systemImage: order.iconName)
                            if sortOrder == order {
                                Spacer()
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                Image(systemName: "arrow.up.arrow.down")
                    .font(.system(size: 12))
                    .frame(width: 28, height: 22)
            }
            .menuStyle(.borderlessButton)
            .frame(width: 32)
            .help(L.Help.sort)

            Divider()
                .frame(height: 16)
                .padding(.horizontal, 4)

            // 视图切换
            ViewModePicker(selectedMode: $viewMode)
        }
    }
}

// MARK: - 工具栏按钮样式

struct ToolbarButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundColor(isEnabled ? .primary : .secondary.opacity(0.5))
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(configuration.isPressed ? Color.gray.opacity(0.2) : Color.clear)
            )
            .contentShape(Rectangle())
    }
}

// MARK: - 视图模式选择器

struct ViewModePicker: View {
    @Binding var selectedMode: FileViewMode

    var body: some View {
        HStack(spacing: 0) {
            ForEach(FileViewMode.allCases) { mode in
                Button {
                    withAnimation(AppAnimations.fast) {
                        selectedMode = mode
                    }
                } label: {
                    Image(systemName: mode.iconName)
                        .font(.system(size: 12))
                        .frame(width: 26, height: 22)
                        .foregroundColor(selectedMode == mode ? AppColors.primary : .secondary)
                        .background(
                            RoundedRectangle(cornerRadius: 4)
                                .fill(selectedMode == mode ? AppColors.primary.opacity(0.12) : Color.clear)
                        )
                }
                .buttonStyle(.plain)
                .help(mode.displayName)
            }
        }
        .padding(2)
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(6)
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .strokeBorder(Color(nsColor: .separatorColor), lineWidth: 0.5)
        )
    }
}

// MARK: - 预览

#Preview {
    VStack {
        FinderToolbar(
            searchText: .constant(""),
            viewMode: .constant(.table),
            sortOrder: .constant(.name),
            filterType: .constant(.all),
            canGoUp: true,
            isDisabled: false,
            onGoUp: {},
            onRefresh: {},
            onNewFolder: {},
            onUpload: {}
        )

        Divider()

        FinderToolbar(
            searchText: .constant("test"),
            viewMode: .constant(.icons),
            sortOrder: .constant(.dateModified),
            filterType: .constant(.images),
            canGoUp: false,
            isDisabled: false,
            onGoUp: {},
            onRefresh: {},
            onNewFolder: {},
            onUpload: {}
        )
    }
    .frame(width: 700)
    .padding()
}
