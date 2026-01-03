# 03. 文件导航 (File Navigation)

## 功能概述

文件导航模块提供存储桶内文件和文件夹的浏览功能，采用 **Finder 风格** 界面设计，支持多种视图模式、路径导航和高级选择操作。

> **设计规范**: 详细的 UI 规范请参阅 [09. Finder UI 设计规范](./09-finder-ui-design.md)

## 核心组件

| 文件 | 职责 |
|------|-----|
| `FileListView.swift` | 文件列表主界面 |
| `FileListItemView.swift` | 列表视图项组件 |
| `FileGridView.swift` | 图标网格视图 |
| `FileGridItemView.swift` | 网格项组件（支持缩略图） |
| `FileTableView.swift` | 表格视图（可排序列头） |
| `FinderToolbar.swift` | Finder 风格工具栏 |
| `PathBar.swift` | 路径导航栏 |
| `FileObject.swift` | 文件对象数据模型 |

## 功能特性

### ✅ 已实现

- **多视图模式**: 列表 / 表格 / 图标网格 (`Cmd+1/2/3` 切换)
- **图片缩略图**: 图标视图下显示图片缩略图预览
- **Finder 风格选择**: 单选 / `Cmd+点击` 多选 / `Shift+点击` 范围选择
- **文件夹导航**: 单击进入文件夹
- **路径导航栏**: 面包屑风格，点击跳转任意层级
- **搜索过滤**: 实时搜索 + 类型筛选
- **排序功能**: 名称 / 大小 / 日期排序
- **刷新功能**: 重新加载当前目录内容
- **空状态提示**: 当文件夹为空时显示提示
- **加载状态**: 加载中显示进度指示器

### 📱 界面布局

```
┌───────────────────────────────────────────────────────────────┐
│ [← ↑] [↻]  │   [🔍 搜索...]   │ [📁+] [↑] [筛选] [排序] [视图] │  <- FinderToolbar
├───────────────────────────────────────────────────────────────┤
│ 🪣 my-bucket  >  📁 documents  >  📁 images                   │  <- PathBar
├───────────────────────────────────────────────────────────────┤
│ ┌─────┐  ┌─────┐  ┌─────┐  ┌─────┐  ┌─────┐                  │
│ │ 📁  │  │ 🖼️  │  │ 🖼️  │  │ 📄  │  │ 📦  │    <- 图标视图   │
│ │folder│  │photo1│  │photo2│  │ doc │  │ zip │                │
│ └─────┘  └─────┘  └─────┘  └─────┘  └─────┘                  │
└───────────────────────────────────────────────────────────────┘
```

## 导航操作

| 操作 | 触发方式 | 说明 |
|------|---------|------|
| 进入文件夹 | 单击文件夹 | 导航到子目录 |
| 预览文件 | 双击文件 | 打开预览窗口 |
| 返回上级 | 点击工具栏 `↑` 或 `Cmd+↑` | 回到父目录 |
| 快速跳转 | 点击路径栏任意层级 | 跳转到指定目录 |
| 刷新 | 点击工具栏 `↻` 或 `Cmd+R` | 重新加载列表 |

## 文件类型图标

| 类型 | 图标 | 扩展名 |
|------|:----:|--------|
| 文件夹 | 📁 | - |
| 图片 | 🖼️ | jpg, png, gif, webp, svg |
| 视频 | 🎬 | mp4, mov, avi, mkv |
| 音频 | 🎵 | mp3, wav, flac, aac |
| 文档 | 📄 | pdf, doc, docx, txt |
| 代码 | 💻 | js, ts, py, swift |
| 压缩 | 📦 | zip, rar, 7z, tar |
| 其他 | 📎 | * |

## API 方法

### 列出目录内容
```swift
func listFiles(prefix: String) async throws -> [FileObject]
```

### 刷新文件列表
```swift
func refreshFileList() async
```

## 数据模型

```swift
struct FileObject: Identifiable, Hashable {
    let id: UUID
    let key: String           // 完整路径
    let name: String          // 显示名称
    let size: Int64?          // 文件大小 (bytes)
    let lastModified: Date?   // 最后修改时间
    let isFolder: Bool        // 是否为文件夹
    let etag: String?         // ETag 标识
}
```

## 相关链接

- [02. 存储桶操作](./02-bucket-operations.md)
- [04. 文件上传](./04-file-upload.md)
- [06. 文件夹管理](./06-folder-management.md)
- [09. Finder UI 设计规范](./09-finder-ui-design.md) - 详细的 UI 组件和交互规范
