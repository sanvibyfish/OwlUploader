import SwiftUI

struct FileListItemView: View {
    let fileObject: FileObject

    /// 是否被选中
    var isSelected: Bool = false

    // Dependencies
    var r2Service: R2Service?
    var bucketName: String?
    var messageManager: MessageManager?

    // Actions
    var onDeleteFile: ((FileObject) -> Void)?
    var onDownloadFile: ((FileObject) -> Void)?

    @State private var isHovering = false

    var body: some View {
        HStack(spacing: AppSpacing.medium) {
            // Icon
            fileIcon
                .font(.title2)
                .frame(width: 32, height: 32)

            // Content
            VStack(alignment: .leading, spacing: 2) {
                Text(fileObject.name)
                    .font(AppTypography.body)
                    .foregroundColor(isSelected ? AppColors.primary : AppColors.textPrimary)
                    .lineLimit(1)
                    .truncationMode(.middle)

                HStack(spacing: 8) {
                    if fileObject.isDirectory {
                        Text(L.Files.FileType.folder)
                            .font(AppTypography.caption)
                            .foregroundColor(AppColors.textSecondary)
                    } else {
                        Text(fileObject.formattedSize)
                            .font(AppTypography.monospacedDigit.weight(.regular))
                            .foregroundColor(AppColors.textSecondary)

                        Text("•")
                            .foregroundColor(AppColors.textSecondary)

                        Text(fileObject.formattedLastModified)
                            .font(AppTypography.caption)
                            .foregroundColor(AppColors.textSecondary)
                    }
                }
            }

            Spacer()

            // Hover Actions (Only visible on hover)
            if isHovering && !fileObject.isDirectory {
                HStack(spacing: 12) {
                    Button(action: { onDownloadFile?(fileObject) }) {
                        Image(systemName: "arrow.down.circle")
                            .foregroundColor(AppColors.primary)
                    }
                    .buttonStyle(.plain)
                    .help(L.Help.download)

                    Button(action: copyFileURL) {
                        Image(systemName: "link")
                            .foregroundColor(AppColors.primary)
                    }
                    .buttonStyle(.plain)
                    .help(L.Help.copyLink)

                    Button(action: { onDeleteFile?(fileObject) }) {
                        Image(systemName: "trash")
                            .foregroundColor(AppColors.destructive)
                    }
                    .buttonStyle(.plain)
                    .help(L.Help.delete)
                }
                .transition(AppTransitions.hoverActions)
            }
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 8)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(backgroundFillColor)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .strokeBorder(isSelected ? AppColors.primary.opacity(0.5) : Color.clear, lineWidth: 1)
        )
        .contentShape(Rectangle())
        .onHover { hovering in
            withAnimation(AppAnimations.hover) {
                isHovering = hovering
            }
        }
        .animation(AppAnimations.selection, value: isSelected)
        .contextMenu {
            if !fileObject.isDirectory {
                Button(action: { onDownloadFile?(fileObject) }) {
                    Label(L.Files.ContextMenu.download, systemImage: "arrow.down.circle")
                }
                Button(action: copyFileURL) {
                    Label(L.Files.ContextMenu.copyLink, systemImage: "link")
                }
                Divider()
            }
            Button(role: .destructive, action: { onDeleteFile?(fileObject) }) {
                Label(L.Files.ContextMenu.delete, systemImage: "trash")
            }
        }
    }

    /// 背景填充颜色
    private var backgroundFillColor: Color {
        if isSelected {
            return AppColors.primary.opacity(0.12)
        } else if isHovering {
            return Color.gray.opacity(0.08)
        } else {
            return Color.clear
        }
    }
    
    private var fileIcon: some View {
        Group {
            if fileObject.isDirectory {
                Image(systemName: "folder.fill")
                    .foregroundColor(.blue)
            } else if fileObject.isImage {
                Image(systemName: "photo")
                    .foregroundColor(.purple)
            } else {
                Image(systemName: "doc")
                    .foregroundColor(.secondary)
            }
        }
    }
    
    private func copyFileURL() {
        guard let r2Service = r2Service,
              let bucketName = bucketName else { return }
        
        guard let fileURL = r2Service.generateFileURL(for: fileObject, in: bucketName) else { return }
        
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(fileURL, forType: .string)
        messageManager?.showSuccess(L.Message.Success.linkCopied, description: L.Message.Success.linkCopiedDescription)
    }
}