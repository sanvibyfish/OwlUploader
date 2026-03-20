//
//  CloudProvider.swift
//  OwlUploader
//
//  云存储供应商枚举和 OSS Region 定义
//

import Foundation

// MARK: - 云存储供应商

/// 支持的云存储供应商
enum CloudProvider: String, Codable, CaseIterable {
    case r2 = "cloudflare_r2"
    case oss = "aliyun_oss"

    /// 供应商显示名称
    var displayName: String {
        switch self {
        case .r2: return "Cloudflare R2"
        case .oss: return "Alibaba Cloud OSS"
        }
    }

    /// 供应商图标（SF Symbol）
    var iconName: String {
        switch self {
        case .r2: return "cloud.fill"
        case .oss: return "externaldrive.connected.to.line.below.fill"
        }
    }

    /// 是否需要 Account ID（R2 特有）
    var requiresAccountID: Bool {
        switch self {
        case .r2: return true
        case .oss: return false
        }
    }

    /// 是否需要 Region 选择（OSS 特有）
    var requiresRegion: Bool {
        switch self {
        case .r2: return false
        case .oss: return true
        }
    }

    /// 是否支持 Cloudflare CDN Purge
    var supportsCDNPurge: Bool {
        switch self {
        case .r2: return true
        case .oss: return false
        }
    }

    /// S3 SDK 是否使用 path-style 寻址
    /// - R2: true（endpoint 已含 accountID，bucket 在 path 中）
    /// - OSS: false（bucket 作为子域名，即 virtual-hosted-style）
    var usePathStyle: Bool {
        switch self {
        case .r2: return true
        case .oss: return false
        }
    }

    /// 生成默认 Endpoint URL
    /// - Parameters:
    ///   - accountID: R2 的 Account ID
    ///   - region: OSS 的 Region ID
    /// - Returns: 默认 Endpoint URL
    func defaultEndpointURL(accountID: String = "", region: String = "") -> String {
        switch self {
        case .r2:
            return "https://\(accountID).r2.cloudflarestorage.com"
        case .oss:
            return "https://oss-\(region).aliyuncs.com"
        }
    }

    /// 该供应商使用的 S3 兼容 region 字符串
    func s3Region(ossRegion: String? = nil) -> String {
        switch self {
        case .r2:
            return "auto"
        case .oss:
            return ossRegion ?? "oss-cn-hangzhou"
        }
    }
}

// MARK: - OSS Region 定义

/// 阿里云 OSS 可用区域
struct OSSRegion: Identifiable, Hashable {
    let id: String       // region ID，如 "cn-hangzhou"
    let displayName: String

    /// 完整的 OSS endpoint region 前缀（如 "oss-cn-hangzhou"）
    var endpointRegion: String { "oss-\(id)" }

    /// 所有可用区域（按地域分组）
    static let allRegions: [OSSRegion] = chinaRegions + hongkongRegion + asiaRegions + usRegions + euRegions + meRegions

    // MARK: - 中国大陆

    static let chinaRegions: [OSSRegion] = [
        OSSRegion(id: "cn-hangzhou", displayName: "华东1（杭州）"),
        OSSRegion(id: "cn-shanghai", displayName: "华东2（上海）"),
        OSSRegion(id: "cn-nanjing", displayName: "华东5（南京）"),
        OSSRegion(id: "cn-fuzhou", displayName: "华东6（福州）"),
        OSSRegion(id: "cn-qingdao", displayName: "华北1（青岛）"),
        OSSRegion(id: "cn-beijing", displayName: "华北2（北京）"),
        OSSRegion(id: "cn-zhangjiakou", displayName: "华北3（张家口）"),
        OSSRegion(id: "cn-huhehaote", displayName: "华北5（呼和浩特）"),
        OSSRegion(id: "cn-wulanchabu", displayName: "华北6（乌兰察布）"),
        OSSRegion(id: "cn-shenzhen", displayName: "华南1（深圳）"),
        OSSRegion(id: "cn-heyuan", displayName: "华南2（河源）"),
        OSSRegion(id: "cn-guangzhou", displayName: "华南3（广州）"),
        OSSRegion(id: "cn-chengdu", displayName: "西南1（成都）"),
    ]

    // MARK: - 中国香港

    static let hongkongRegion: [OSSRegion] = [
        OSSRegion(id: "cn-hongkong", displayName: "中国香港"),
    ]

    // MARK: - 亚太

    static let asiaRegions: [OSSRegion] = [
        OSSRegion(id: "ap-southeast-1", displayName: "新加坡"),
        OSSRegion(id: "ap-southeast-2", displayName: "澳大利亚（悉尼）"),
        OSSRegion(id: "ap-southeast-3", displayName: "马来西亚（吉隆坡）"),
        OSSRegion(id: "ap-southeast-5", displayName: "印度尼西亚（雅加达）"),
        OSSRegion(id: "ap-southeast-6", displayName: "菲律宾（马尼拉）"),
        OSSRegion(id: "ap-southeast-7", displayName: "泰国（曼谷）"),
        OSSRegion(id: "ap-northeast-1", displayName: "日本（东京）"),
        OSSRegion(id: "ap-northeast-2", displayName: "韩国（首尔）"),
        OSSRegion(id: "ap-south-1", displayName: "印度（孟买）"),
    ]

    // MARK: - 美国

    static let usRegions: [OSSRegion] = [
        OSSRegion(id: "us-west-1", displayName: "美国西部（硅谷）"),
        OSSRegion(id: "us-east-1", displayName: "美国东部（弗吉尼亚）"),
    ]

    // MARK: - 欧洲

    static let euRegions: [OSSRegion] = [
        OSSRegion(id: "eu-central-1", displayName: "德国（法兰克福）"),
        OSSRegion(id: "eu-west-1", displayName: "英国（伦敦）"),
    ]

    // MARK: - 中东

    static let meRegions: [OSSRegion] = [
        OSSRegion(id: "me-east-1", displayName: "阿联酋（迪拜）"),
    ]
}
