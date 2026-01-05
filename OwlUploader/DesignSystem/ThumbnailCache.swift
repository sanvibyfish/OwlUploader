//
//  ThumbnailCache.swift
//  OwlUploader
//
//  图片缩略图缓存管理器
//  使用 NSCache 进行内存缓存，支持异步加载
//

import SwiftUI
import AppKit

/// 加载任务管理器 (Actor保证线程安全)
private actor LoadingTaskManager {
    private var loadingTasks: [String: Task<NSImage?, Never>] = [:]

    func getTask(for key: String) -> Task<NSImage?, Never>? {
        return loadingTasks[key]
    }

    func setTask(_ task: Task<NSImage?, Never>, for key: String) {
        loadingTasks[key] = task
    }

    func removeTask(for key: String) {
        loadingTasks.removeValue(forKey: key)
    }
}

/// 缩略图缓存管理器
class ThumbnailCache: ObservableObject {
    /// 单例
    static let shared = ThumbnailCache()

    /// 内存缓存
    private let cache = NSCache<NSString, NSImage>()

    /// 加载任务管理器
    private let taskManager = LoadingTaskManager()

    private init() {
        // 设置缓存限制
        cache.countLimit = 200 // 最多缓存200张缩略图
        cache.totalCostLimit = 100 * 1024 * 1024 // 100MB
    }

    /// 获取缓存的缩略图
    func getCachedThumbnail(for key: String) -> NSImage? {
        return cache.object(forKey: key as NSString)
    }

    /// 缓存缩略图
    func cacheThumbnail(_ image: NSImage, for key: String) {
        cache.setObject(image, forKey: key as NSString)
    }

    /// 异步加载缩略图
    func loadThumbnail(from urlString: String, maxSize: CGFloat = 128) async -> NSImage? {
        let cacheKey = "\(urlString)_\(Int(maxSize))"

        // 检查缓存
        if let cached = getCachedThumbnail(for: cacheKey) {
            return cached
        }

        // 检查是否已在加载
        if let existingTask = await taskManager.getTask(for: cacheKey) {
            return await existingTask.value
        }

        // 创建加载任务
        let task = Task<NSImage?, Never> {
            await performLoad(urlString: urlString, maxSize: maxSize, cacheKey: cacheKey)
        }
        await taskManager.setTask(task, for: cacheKey)

        let result = await task.value

        // 清理任务
        await taskManager.removeTask(for: cacheKey)

        return result
    }

    private func performLoad(urlString: String, maxSize: CGFloat, cacheKey: String) async -> NSImage? {
        guard let url = URL(string: urlString) else { return nil }

        do {
            let (data, response) = try await URLSession.shared.data(from: url)

            // 验证响应
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                return nil
            }

            // 验证内容类型是图片
            if let contentType = httpResponse.value(forHTTPHeaderField: "Content-Type"),
               !contentType.hasPrefix("image/") {
                return nil
            }

            // 创建图片
            guard let image = NSImage(data: data) else { return nil }

            // 创建缩略图
            let thumbnail = createThumbnail(from: image, maxSize: maxSize)

            // 缓存
            if let thumbnail = thumbnail {
                cacheThumbnail(thumbnail, for: cacheKey)
            }

            return thumbnail

        } catch {
            print("⚠️ ThumbnailCache: 加载缩略图失败 - \(error.localizedDescription)")
            return nil
        }
    }

    /// 创建指定大小的缩略图
    private func createThumbnail(from image: NSImage, maxSize: CGFloat) -> NSImage? {
        let originalSize = image.size
        guard originalSize.width > 0, originalSize.height > 0 else { return nil }

        // 计算缩放比例
        let scale = min(maxSize / originalSize.width, maxSize / originalSize.height, 1.0)
        let newSize = NSSize(
            width: originalSize.width * scale,
            height: originalSize.height * scale
        )

        // 如果不需要缩放，直接返回
        if scale >= 1.0 {
            return image
        }

        // 创建缩略图
        let thumbnail = NSImage(size: newSize)
        thumbnail.lockFocus()

        NSGraphicsContext.current?.imageInterpolation = .high

        image.draw(
            in: NSRect(origin: .zero, size: newSize),
            from: NSRect(origin: .zero, size: originalSize),
            operation: .copy,
            fraction: 1.0
        )

        thumbnail.unlockFocus()

        return thumbnail
    }

    /// 清空缓存
    func clearCache() {
        cache.removeAllObjects()
    }
}

// MARK: - SwiftUI Thumbnail View

/// 异步缩略图视图
struct AsyncThumbnailView: View {
    let urlString: String?
    let size: CGFloat
    let placeholder: AnyView

    @State private var thumbnail: NSImage?
    @State private var isLoading = false

    init(urlString: String?, size: CGFloat, @ViewBuilder placeholder: () -> some View) {
        self.urlString = urlString
        self.size = size
        self.placeholder = AnyView(placeholder())
    }

    var body: some View {
        Group {
            if let thumbnail = thumbnail {
                Image(nsImage: thumbnail)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: size, height: size)
                    .clipped()
                    .cornerRadius(6)
            } else {
                placeholder
            }
        }
        .task(id: urlString) {
            await loadThumbnail()
        }
    }

    private func loadThumbnail() async {
        guard let urlString = urlString, !urlString.isEmpty else { return }

        // 先检查缓存
        if let cached = ThumbnailCache.shared.getCachedThumbnail(for: "\(urlString)_\(Int(size))") {
            self.thumbnail = cached
            return
        }

        isLoading = true
        thumbnail = await ThumbnailCache.shared.loadThumbnail(from: urlString, maxSize: size * 2) // 2x for retina
        isLoading = false
    }
}
