# 05. 文件下载、删除与重命名 (File Download, Delete & Rename)

## 功能概述

文件下载、删除与重命名模块提供从 R2 存储下载文件到本地、删除远程文件和重命名文件/文件夹的功能。支持单文件和批量操作。

## 核心组件

| 文件 | 职责 |
|------|-----|
| `FileListView.swift` | 下载/删除/重命名操作入口、批量操作 |
| `FilePreviewView.swift` | 文件预览视图 |
| `FileGridItemView.swift` | 网格视图文件项操作 |
| `FileTableView.swift` | 表格视图文件项操作 |
| `FinderToolbar.swift` | 批量操作工具栏 |
| `SelectionManager.swift` | 多选状态管理 |
| `RenameSheet.swift` | 重命名对话框组件 |
| `R2Service.swift` | 下载/删除/重命名 API |

## 功能特性

### ✅ 已实现

- **文件预览**: 双击文件打开预览窗口
- **单文件下载**: 右键菜单或悬停按钮下载
- **批量下载**: 选择多个文件后批量下载到指定目录
- **下载位置选择**: 通过系统对话框选择保存位置
- **单文件删除**: 删除单个文件
- **批量删除**: 选择多个文件后批量删除（使用批量 API 优化）
- **删除确认**: 删除前显示确认对话框
- **文件重命名**: 右键菜单重命名文件
- **文件夹重命名**: 右键菜单重命名文件夹
- **操作反馈**: 成功/失败状态提示
- **多选支持**: Cmd+Click 添加选择，Shift+Click 范围选择
- **任务取消**: 支持取消进行中的下载任务
- **任务去重**: 自动跳过已在队列中的活跃任务

## 已知问题 / 改进方向

- **下载内存占用**：当前 `downloadObject` 会将对象一次性读入内存再写入磁盘，大文件可能导致内存飙升。后续需要改为流式读取/写入，逐块落盘。

## 文件预览

### 触发方式

双击文件或通过右键菜单选择「预览」打开预览窗口。

### 支持的文件类型

| 类型 | 扩展名 | 预览方式 |
|------|--------|----------|
| **图片** | jpg, png, gif, webp, bmp, ico, svg | 图片视图（自适应缩放） |
| **视频** | mp4, mov, avi, mkv, webm | AVPlayer 播放器 |
| **音频** | mp3, wav, flac, aac, ogg, m4a | AVPlayer 播放器 |
| **PDF** | pdf | PDFKit 渲染 |
| **文本** | txt, md, json, xml, html, css, js, ts, swift 等 | 等宽字体文本显示 |

### 预览界面

```
┌─────────────────────────────────────────────────────────────┐
│ [图标] photo.jpg  2.3 MB · JPEG │  [◀] [▶]  │ [⬇] [🔗] [🗑] [✕] │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│                                                             │
│                     [图片/视频/文档内容]                      │
│                                                             │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

### 工具栏功能

| 按钮 | 功能 |
|:----:|------|
| `◀` `▶` | 切换到上一个/下一个文件 |
| `⬇` | 下载文件到本地 |
| `🔗` | 复制公开链接到剪贴板 |
| `🗑` | 删除文件 |
| `✕` | 关闭预览 |

### 键盘快捷键

| 快捷键 | 功能 |
|--------|------|
| `←` | 上一个文件 |
| `→` | 下一个文件 |
| `Esc` | 关闭预览 |

## 文件下载

### 单文件下载

1. 右键点击文件或悬停显示下载按钮
2. 选择本地保存位置
3. 开始下载
4. 完成后显示成功提示

### 批量下载

1. 使用 Cmd+Click 或 Shift+Click 选择多个文件
2. 工具栏显示选中数量和批量操作按钮
3. 点击 **Download** 按钮
4. 选择保存目录
5. 所有文件下载到指定目录

### 下载 API

```swift
func downloadObject(
    bucket: String,
    key: String,
    to localURL: URL
) async throws
```

## 文件删除

### 单文件删除

```mermaid
flowchart TD
    A[选择文件] --> B[点击删除]
    B --> C[显示确认对话框]
    C --> D{用户确认?}
    D -->|取消| E[关闭对话框]
    D -->|确认| F[执行删除]
    F --> G{删除结果}
    G -->|成功| H[刷新列表]
    G -->|失败| I[显示错误]
    H --> J[显示成功提示]
```

### 批量删除

1. 选择多个文件
2. 工具栏显示批量操作区
3. 点击 **Delete** 按钮
4. 确认对话框显示 "Delete N Files?"
5. 确认后依次删除所有选中文件
6. 显示删除结果统计

### 确认对话框

**单文件删除：**
```
Complete Deletion
Are you sure you want to delete 'example.txt'?
[Cancel] [Delete]
```

**批量删除：**
```
Delete 5 Files?
This action cannot be undone.
[Cancel] [Delete]
```

### 删除 API

```swift
// 删除单个对象
func deleteObject(bucket: String, key: String) async throws

// 批量删除对象（最多 1000 个，推荐用于多文件删除）
func deleteObjects(bucket: String, keys: [String]) async throws -> [String]

// 删除文件夹（递归删除所有内容，内部使用批量 API）
func deleteFolder(bucket: String, folderKey: String) async throws -> (deleted: Int, failed: [String])
```

### 批量删除优化

多选删除使用 S3 `DeleteObjects` 批量 API，一次请求最多删除 1000 个文件：

```swift
// 优化前：N 个文件 = N 次 API 调用（慢）
for file in files {
    try await r2Service.deleteObject(bucket: bucketName, key: file.key)
}

// 优化后：N 个文件 = 1 次 API 调用（快）
let fileKeys = files.map { $0.key }
let failedKeys = try await r2Service.deleteObjects(bucket: bucketName, keys: fileKeys)
```

**性能对比**：

| 文件数量 | 串行删除 | 批量删除 |
|---------|---------|---------|
| 10 个文件 | ~2-3 秒 | ~0.3 秒 |
| 100 个文件 | ~20-30 秒 | ~0.5 秒 |
| 1000 个文件 | ~3-5 分钟 | ~1 秒 |

## 文件夹删除

### 技术说明

R2/S3 使用扁平的键值存储结构，"文件夹"实际上是以 `/` 结尾的空对象（文件夹标记）加上共享相同前缀的一组对象。

### 删除流程

```mermaid
flowchart TD
    A[选择文件夹] --> B[点击删除]
    B --> C[显示确认对话框]
    C --> D{用户确认?}
    D -->|取消| E[关闭对话框]
    D -->|确认| F[列出所有子对象]
    F --> G[收集所有对象 key]
    G --> H[添加文件夹标记对象]
    H --> I[批量删除所有对象]
    I --> J{删除结果}
    J -->|成功| K[刷新文件列表]
    J -->|失败| L[显示错误]
    K --> M[显示成功提示]
```

### 删除内容

文件夹删除会移除：
1. **所有子文件**: 文件夹内的所有文件
2. **所有子文件夹**: 递归删除嵌套的文件夹及其内容
3. **文件夹标记对象**: 以 `/` 结尾的空对象（表示文件夹本身）

### 确认对话框

**文件夹删除：**
```
确认删除
确定要删除文件夹 'documents' 吗？
此文件夹包含 15 个文件，删除后无法恢复。
[取消] [删除]
```

## 多选操作

### 选择模式

| 操作 | 快捷键 | 说明 |
|------|--------|------|
| 单选 | 点击 | 清除其他选择，只选中当前 |
| 添加选择 | Cmd + 点击 | 将文件添加/移除选择 |
| 范围选择 | Shift + 点击 | 选中从上次选择到当前的所有文件 |
| 全选 | Cmd + A | 选中当前目录所有文件 |
| 取消选择 | Esc 或点击空白 | 清除所有选择 |

### 批量操作工具栏

当有文件被选中时，工具栏中间区域会显示批量操作区：

```
[← ↻] ─────── [3 items selected | Download | Delete] ─────── [+ ↑ ≡ ⊞ ☰]
```

- **选中计数**: 显示 "N items selected"
- **Download**: 批量下载按钮
- **Delete**: 批量删除按钮（红色警示）

## 错误处理

| 错误类型 | 描述 | 处理方式 |
|---------|------|---------|
| `downloadFailed` | 下载请求失败 | 显示错误消息 |
| `deleteFileFailed` | 删除请求失败 | 显示错误消息 |
| `networkError` | 网络连接错误 | 建议重试 |
| `permissionDenied` | 权限不足 | 检查 API 权限 |

### 批量操作结果

批量操作完成后显示统计信息：

- **全部成功**: "Deleted Successfully - N files deleted"
- **部分失败**: "Partially Deleted - M succeeded, N failed"

## 文件重命名

### 触发方式

右键点击文件或文件夹，选择「重命名」菜单项。

### 重命名对话框

```
┌─────────────────────────────────────────┐
│              Rename                      │
│                                          │
│  New Name:                               │
│  ┌────────────────────────────────────┐ │
│  │ document.pdf                       │ │
│  └────────────────────────────────────┘ │
│  Names cannot contain: \ / : * ? " < > |│
│  ✓ Valid name                           │
│                                          │
│  [Cancel]                    [Rename]   │
└─────────────────────────────────────────┘
```

### 验证规则

| 规则 | 说明 |
|------|------|
| 非空 | 名称不能为空或仅包含空格 |
| 非法字符 | 不能包含 `\ / : * ? " < > \|` |
| 名称变化 | 新名称必须与原名称不同 |

### 验证状态提示

| 状态 | 颜色 | 说明 |
|------|------|------|
| ✓ Valid name | 绿色 | 名称有效且与原名不同 |
| Name unchanged | 橙色 | 名称与原名相同 |
| Invalid name | 红色 | 包含非法字符 |

### 键盘快捷键

| 快捷键 | 功能 |
|--------|------|
| `Enter` | 确认重命名 |
| `Esc` | 取消操作 |

### 重命名 API

```swift
func renameObject(
    bucket: String,
    oldKey: String,
    newKey: String
) async throws
```

**实现原理**: R2/S3 不支持原生重命名，通过 Copy + Delete 实现：
1. 复制对象到新 key
2. 删除原对象

### Key 构建逻辑

重命名时需要保留原有的目录路径：

**文件重命名**:
```swift
// 原 key: "documents/reports/old.pdf"
// 新名称: "new.pdf"
// 新 key: "documents/reports/new.pdf"
```

**文件夹重命名**:
```swift
// 原 key: "projects/2024/reports/"
// 新名称: "documents"
// 新 key: "projects/2024/documents/"
```

注意：文件夹 key 以 `/` 结尾，处理时需要先去除再添加。

### 错误处理

| 错误类型 | 描述 | 处理方式 |
|---------|------|---------|
| `renameFailed` | 重命名请求失败 | 显示错误消息 |
| `copyFailed` | 复制对象失败 | 显示错误消息 |
| `networkError` | 网络连接错误 | 建议重试 |

## 相关链接

- [文件导航](./03-file-navigation.md)
- [文件上传](./04-file-upload.md)
- [Finder UI 设计规范](./09-finder-ui-design.md)
