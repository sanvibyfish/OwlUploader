# Progress

## In Progress

## Done

- OSS / 多云供应商基础：`CloudProvider`、`R2Account` / `R2Service` 动态 S3 配置、账户 UI 与本地化、相关文档（2026-03-20）
- OSS 兼容修复：`SecondLevelDomainForbidden`（`usePathStyle` / `forcePathStyle`）、复制链接 URL（`buildStorageURL`）、文件夹重命名（`renameFolder` + `copySingleObject` + 标记对象 PutObject）、上传后 CDN purge 仅 R2（`supportsCDNPurge`）（2026-03-20）
- v1.0.1 已发布（2026-02-06）
- 多账户切换、文件搜索过滤、Finder 风格 UI、缩略图预览、文件预览、批量操作
- 文件移动、重命名、本地化（中/英）、导航历史、合并队列视图

## Pending Issues

- REQ-001: Table 视图拖拽移动文件（Blocked）

## Notes

- 多云差异集中在 `CloudProvider`：`usePathStyle`（OSS 需 virtual-hosted）、`supportsCDNPurge`（仅 R2 走 Cloudflare purge）。
- 文件夹「标记」对象用 PutObject 创建/迁移；单对象复制统一经 `copySingleObject()`，避免 OSS 上 CopyObject 与标记对象不兼容。
