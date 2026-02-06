# REQ-002: 下载文件夹时目录占位符冲突

> 状态：✅ 已完成 | 优先级：P1 | 版本：v1.0.1

---

## 1. 需求概述

修复下载 R2 文件夹时，不带尾斜杠的目录占位符对象（如 `t1`、`t1/t2`）被当作普通文件下载，导致与实际目录路径冲突而失败的问题。

---

## 2. 问题描述

### 2.1 背景

在 R2/S3 存储中，某些客户端工具会创建不带尾斜杠的目录占位符对象来标记文件夹的存在。这些对象的特征是：
- key 不以 `/` 结尾（如 `t1`、`t1/t2`）
- 文件大小通常为 0 字节
- key 恰好等于其他文件路径中的目录前缀

### 2.2 问题表现

下载包含目录占位符的文件夹时会出现冲突：

```
R2 对象列表:
vowels/t1 (0 bytes)  ← 目录占位符
vowels/t1/t2 (0 bytes)  ← 目录占位符
vowels/t1/t2/carrier.mp3 (1024 bytes)  ← 真实文件

下载流程:
1. 系统尝试下载 "t1" → 在本地创建文件 ~/Downloads/t1
2. 系统创建目录 ~/Downloads/t1/t2/ （为 carrier.mp3 做准备）
   ❌ 失败：~/Downloads/t1 已是文件，无法作为目录
```

### 2.3 影响范围

- 用户无法成功下载包含目录占位符的文件夹
- 下载过程中断，已下载文件可能不完整
- 部分云存储迁移工具（如 rclone）会创建这类占位符

---

## 3. 解决方案

### 3.1 技术方案

实现**两层防御机制**：

#### 第一层：列表阶段过滤（主要防御）

**位置**: `R2Service.listAllFilesInFolder()`

**逻辑**:
1. 扫描文件夹，收集所有对象
2. 从所有文件的 `relativePath` 中提取目录前缀
3. 过滤掉 `relativePath` 恰好等于某个目录前缀的条目
4. 返回过滤后的文件列表

**代码**:
```swift
// 列出文件后自动过滤
let filteredFiles = R2Service.filterDirectoryPlaceholders(from: allFiles)
```

#### 第二层：下载阶段防御性检查

**位置**: `DownloadQueueManager.performDownload()`

**逻辑**:
```swift
// 防御性检查：如果 localURL 已作为目录存在，跳过下载
var isDirectory: ObjCBool = false
if FileManager.default.fileExists(atPath: task.localURL.path, isDirectory: &isDirectory),
   isDirectory.boolValue {
    // 跳过下载，标记任务为完成
    return
}
```

### 3.2 实现细节

#### `filterDirectoryPlaceholders` 算法

```swift
nonisolated static func filterDirectoryPlaceholders(
    from files: [(key: String, size: Int64, relativePath: String)]
) -> [(key: String, size: Int64, relativePath: String)] {
    // 1. 收集所有目录前缀
    var directoryPrefixes = Set<String>()
    for file in files {
        let components = file.relativePath.split(separator: "/")
        if components.count > 1 {
            var prefix = ""
            for component in components.dropLast() {
                if !prefix.isEmpty { prefix += "/" }
                prefix += String(component)
                directoryPrefixes.insert(prefix)
            }
        }
    }

    // 2. 过滤掉 relativePath 恰好等于目录前缀的条目
    return files.filter { !directoryPrefixes.contains($0.relativePath) }
}
```

**示例**:

```
输入文件列表:
- t1 (relativePath: "t1") → 被过滤（等于目录前缀 "t1"）
- t1/t2 (relativePath: "t1/t2") → 被过滤（等于目录前缀 "t1/t2"）
- t1/t2/carrier.mp3 (relativePath: "t1/t2/carrier.mp3") → 保留（真实文件）
- t1.txt (relativePath: "t1.txt") → 保留（不等于目录前缀 "t1"）

输出文件列表:
- t1/t2/carrier.mp3
- t1.txt
```

---

## 4. 测试覆盖

### 4.1 单元测试

**文件**: `OwlUploaderTests/R2ServiceTests.swift`

| 测试用例 | 验证内容 |
|---------|---------|
| `testFilterDirectoryPlaceholders_removesPlaceholdersWithoutTrailingSlash` | 过滤不带尾斜杠的占位符 |
| `testFilterDirectoryPlaceholders_preservesLegitimateFiles` | 保留所有真实文件 |
| `testFilterDirectoryPlaceholders_emptyList` | 空列表处理 |
| `testFilterDirectoryPlaceholders_singleFile` | 单文件场景 |
| `testFilterDirectoryPlaceholders_deepNestedPlaceholderChain` | 深层嵌套占位符链 |
| `testFilterDirectoryPlaceholders_similarNameNotFalselyFiltered` | 相似名称不会被误过滤 |
| `testFilterDirectoryPlaceholders_multipleSubdirectories` | 多子目录占位符处理 |

**运行测试**:
```bash
xcodebuild test -scheme OwlUploader -destination 'platform=macOS' \
  -only-testing:OwlUploaderTests/R2ServiceTests
```

### 4.2 集成测试

**手动测试场景**:
1. 使用 rclone 或其他工具创建包含目录占位符的文件夹
2. 在 OwlUploader 中下载该文件夹
3. 验证下载成功且目录结构正确

---

## 5. 相关代码

### 5.1 修改文件

| 文件 | 修改内容 |
|------|---------|
| `OwlUploader/R2Service.swift` | 新增 `filterDirectoryPlaceholders()` 方法 |
| `OwlUploader/R2Service.swift` | 更新 `listAllFilesInFolder()` 调用过滤方法 |
| `OwlUploader/Queue/DownloadQueueManager.swift` | 在 `performDownload()` 中添加防御性检查 |
| `OwlUploaderTests/R2ServiceTests.swift` | 新增 7 个单元测试 |

### 5.2 代码位置

```swift
// R2Service.swift
func listAllFilesInFolder(...) async throws {
    // ... 收集所有文件
    let filteredFiles = R2Service.filterDirectoryPlaceholders(from: allFiles)
    return filteredFiles
}

nonisolated static func filterDirectoryPlaceholders(
    from files: [(key: String, size: Int64, relativePath: String)]
) -> [(key: String, size: Int64, relativePath: String)]

// DownloadQueueManager.swift
private func performDownload(taskId: UUID, task: DownloadQueueTask) async {
    // 防御性检查：如果 localURL 已作为目录存在，跳过下载
    var isDirectory: ObjCBool = false
    if FileManager.default.fileExists(atPath: task.localURL.path, isDirectory: &isDirectory),
       isDirectory.boolValue {
        // 跳过下载
        return
    }
    // ... 继续下载
}
```

---

## 6. 验收标准

- ✅ 下载包含目录占位符的文件夹能够成功完成
- ✅ 目录占位符对象被自动过滤，不出现在本地文件系统中
- ✅ 真实文件全部下载成功，目录结构正确
- ✅ 不会误过滤相似名称的真实文件（如 `t1.txt` vs `t1`）
- ✅ 所有相关单元测试通过
- ✅ 不影响不包含占位符的正常文件夹下载

---

## 7. 完成状态

**版本**: v1.0.1
**完成日期**: 2025-02-06
**提交记录**: feat: Add upload conflict detection, CDN cache purge, and thumbnail versioning

---

## 8. 相关链接

- [功能文档：文件下载、删除与重命名](../features/05-file-download-delete.md)
- [单元测试：R2ServiceTests](../../OwlUploaderTests/R2ServiceTests.swift)
- [相关代码：R2Service](../../OwlUploader/R2Service.swift)
- [相关代码：DownloadQueueManager](../../OwlUploader/Queue/DownloadQueueManager.swift)
