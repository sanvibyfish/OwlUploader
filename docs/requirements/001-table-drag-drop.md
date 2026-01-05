# REQ-001: Table视图拖拽移动文件

> 状态：🟡 Blocked | 优先级：P2 | 预估工时：待定

---

## 1. 需求概述

在 Table 视图模式下支持拖拽文件到文件夹进行移动，与 Icons 视图模式保持功能一致。

---

## 2. 背景与问题

### 2.1 问题描述
- SwiftUI Table 组件与 `.draggable()` / `.dropDestination()` 修饰符存在根本性冲突
- 任何拖放修饰符都会阻止 Table 原生的**多选**和**双击**行为
- Icons 视图模式（使用自定义 Grid）拖拽功能正常

### 2.2 技术分析
| 方面 | Finder (AppKit) | OwlUploader (SwiftUI) |
|------|-----------------|----------------------|
| 表格组件 | NSTableView | SwiftUI Table |
| 拖放 API | Delegate 方法（独立于选择） | 手势修饰符（拦截点击事件） |
| 兼容性 | 完美支持 | 互相冲突 |

### 2.3 已尝试的方案
1. `.draggable()` + `.dropDestination()` - 阻止多选和双击
2. `.onDrag()` + `.onDrop()` - 同样阻止原生行为
3. `.simultaneousGesture()` - 无法解决问题

---

## 3. 可能的解决方案

### 方案 A: NSViewRepresentable 包装 NSTableView
- **优点**：完美支持拖放，与 Finder 一致
- **缺点**：工作量大，需要重写整个表格视图
- **预估工时**：1-2 周

### 方案 B: 等待 Apple 修复
- **优点**：无需额外工作
- **缺点**：时间不确定

### 方案 C: 仅在 Icons 视图支持拖拽（当前方案）
- **优点**：立即可用，无需改动
- **缺点**：Table 视图功能受限

---

## 4. 临时替代方案

通过**右键菜单"移动到"子菜单**实现文件移动功能：
- 列出上级目录
- 列出当前目录下的所有文件夹
- 用户选择目标位置后执行移动

---

## 5. 相关代码

- `OwlUploader/Views/FileTableView.swift` - Table 视图
- `OwlUploader/Views/FileGridItemView.swift` - Icons 视图项（拖拽正常）
- `OwlUploader/R2Service.swift` - `moveObject()` / `moveFolder()` 方法
