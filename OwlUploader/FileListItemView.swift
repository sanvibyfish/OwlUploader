import SwiftUI

struct FileListItemView: View {
    let fileObject: FileObject
    
    // Dependencies
    var r2Service: R2Service?
    var bucketName: String?
    var messageManager: MessageManager?
    
    // Actions
    var onDeleteFile: ((FileObject) -> Void)?
    
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
                    .foregroundColor(AppColors.textPrimary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                
                HStack(spacing: 8) {
                    if fileObject.isDirectory {
                        Text("Folder")
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
            if isHovering {
                 HStack(spacing: 12) {
                     if !fileObject.isDirectory {
                         Button(action: copyFileURL) {
                             Image(systemName: "link")
                                 .foregroundColor(AppColors.primary)
                         }
                         .buttonStyle(.plain)
                         .help("Copy Link")
                         
                         Button(action: { onDeleteFile?(fileObject) }) {
                             Image(systemName: "trash")
                                 .foregroundColor(AppColors.destructive)
                         }
                         .buttonStyle(.plain)
                         .help("Delete")
                     }
                 }
                 .transition(.opacity)
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .onHover { isHovering = $0 }
        .contextMenu {
            Button(action: copyFileURL) {
                Label("Copy Link", systemImage: "link")
            }
            Divider()
            Button(role: .destructive, action: { onDeleteFile?(fileObject) }) {
                Label("Delete", systemImage: "trash")
            }
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
        messageManager?.showSuccess("Link Copied", description: "File URL copied to clipboard")
    }
}