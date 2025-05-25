# Task 1.1 手动操作指导 - 添加 AWS SDK 包产品依赖

## 背景
AWS SDK for Swift 包已成功添加到项目中，并且包依赖已正确解析，但需要手动在 Xcode 中将具体的模块链接到 Target。

## 步骤说明

### 1. 打开 Xcode 项目
```bash
open OwlUploader.xcodeproj
```

### 2. 在 Xcode 中添加包产品依赖
1. 在项目导航器中，选择 **OwlUploader** 项目（蓝色图标）
2. 在主编辑区域中，选择 **OwlUploader** Target（在 TARGETS 列表中）
3. 点击 **General** 标签页
4. 向下滚动到 **Frameworks, Libraries, and Embedded Content** 部分
5. 点击 **+** 按钮
6. 在弹出的窗口中，找到并添加以下包产品：
   - **AWSS3**
   - **AWSClientRuntime**
7. 确保这两个依赖的 **Embed** 设置为 **Do Not Embed**

### 3. 验证依赖添加成功
依赖添加后，项目配置文件中应该会看到类似以下的内容更新：

```
packageProductDependencies = (
    [AWSS3的ID] /* AWSS3 */,
    [AWSClientRuntime的ID] /* AWSClientRuntime */,
);
```

### 4. 测试编译
在完成上述步骤后，尝试编译项目：
1. 在 Xcode 中按 `Cmd+B` 进行编译
2. 或者在终端中运行：
   ```bash
   xcodebuild -project OwlUploader.xcodeproj -scheme OwlUploader -configuration Debug build
   ```

### 5. 验证模块导入
在完成依赖添加后，应该能够在 Swift 文件中成功导入：
```swift
import AWSClientRuntime
import AWSS3
```

## 预期结果
- 项目能够成功编译，没有 "no such module" 错误
- 可以在代码中正常 import AWS SDK 模块
- Task 1.1 的第三个子步骤得以完成

## 注意事项
- 确保选择的是正确的 Target (OwlUploader)，而不是测试 Target
- 如果在依赖列表中没有看到 AWSS3 和 AWSClientRuntime，请检查是否已正确添加了 aws-sdk-swift 包引用
- 添加依赖后，Xcode 可能需要一些时间来索引和解析模块 