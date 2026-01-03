//
//  AppStrings.swift
//  OwlUploader
//
//  Type-safe localization namespace for all user-facing strings
//

import Foundation
import SwiftUI

/// Localization namespace - provides type-safe access to all localized strings
/// Usage: L.Common.Button.cancel, L.Files.Empty.title, etc.
enum L {

    // MARK: - Common

    enum Common {
        enum Button {
            static let ok = String(localized: "common.button.ok", defaultValue: "OK")
            static let cancel = String(localized: "common.button.cancel", defaultValue: "Cancel")
            static let save = String(localized: "common.button.save", defaultValue: "Save")
            static let delete = String(localized: "common.button.delete", defaultValue: "Delete")
            static let add = String(localized: "common.button.add", defaultValue: "Add")
            static let retry = String(localized: "common.button.retry", defaultValue: "Retry")
            static let refresh = String(localized: "common.button.refresh", defaultValue: "Refresh")
            static let close = String(localized: "common.button.close", defaultValue: "Close")
            static let done = String(localized: "common.button.done", defaultValue: "Done")
            static let edit = String(localized: "common.button.edit", defaultValue: "Edit")
        }

        enum Label {
            static let loading = String(localized: "common.label.loading", defaultValue: "Loading...")
            static let pleaseWait = String(localized: "common.label.pleaseWait", defaultValue: "Please wait")
            static let unknown = String(localized: "common.label.unknown", defaultValue: "Unknown")
        }

        enum Status {
            static let connected = String(localized: "common.status.connected", defaultValue: "Connected")
            static let disconnected = String(localized: "common.status.disconnected", defaultValue: "Disconnected")
            static let notConnected = String(localized: "common.status.notConnected", defaultValue: "Not Connected")
            static let connectedToR2 = String(localized: "common.status.connectedToR2", defaultValue: "Connected to R2")
        }
    }

    // MARK: - Sidebar

    enum Sidebar {
        enum Section {
            static let general = String(localized: "sidebar.section.general", defaultValue: "General")
            static let accounts = String(localized: "sidebar.section.accounts", defaultValue: "Accounts")
        }

        enum Item {
            static let home = String(localized: "sidebar.item.home", defaultValue: "Home")
            static let settings = String(localized: "sidebar.item.settings", defaultValue: "Settings")
        }

        enum Action {
            static let addAccount = String(localized: "sidebar.action.addAccount", defaultValue: "Add Account...")
            static let addBucket = String(localized: "sidebar.action.addBucket", defaultValue: "Add Bucket...")
            static let disconnect = String(localized: "sidebar.action.disconnect", defaultValue: "Disconnect")
        }
    }

    // MARK: - Files

    enum Files {
        enum Toolbar {
            static let searchPlaceholder = String(localized: "files.toolbar.search.placeholder", defaultValue: "Search files...")
            static let newFolder = String(localized: "files.toolbar.newFolder", defaultValue: "New Folder")
            static let upload = String(localized: "files.toolbar.upload", defaultValue: "Upload")
            static let download = String(localized: "files.toolbar.download", defaultValue: "Download")
            static let deleteAction = String(localized: "files.toolbar.delete", defaultValue: "Delete")
            static let goUp = String(localized: "files.toolbar.goUp", defaultValue: "Go Up")
            static let copyLink = String(localized: "files.toolbar.copyLink", defaultValue: "Copy Link")
        }

        enum Empty {
            static let title = String(localized: "files.empty.title", defaultValue: "Folder is Empty")

            static let bucketDescription = String(localized: "files.empty.bucket.description",
                defaultValue: "This bucket has no files or folders.\nUse the buttons above to upload files or create folders.\nOr drag and drop files here.")

            static let folderDescription = String(localized: "files.empty.folder.description",
                defaultValue: "This folder has no files or folders.\nUse the buttons above to upload files or create folders.\nOr drag and drop files here.")

            static let clickUpload = String(localized: "files.empty.clickUpload", defaultValue: "Click \"Upload\" button")
            static let clickNewFolder = String(localized: "files.empty.clickNewFolder", defaultValue: "Click \"New Folder\" button")
            static let orDragDrop = String(localized: "files.empty.orDragDrop", defaultValue: "Or drag and drop files here")
        }

        enum ViewMode {
            static let list = String(localized: "files.viewMode.list", defaultValue: "List")
            static let table = String(localized: "files.viewMode.table", defaultValue: "Table")
            static let icons = String(localized: "files.viewMode.icons", defaultValue: "Icons")
        }

        enum IconSize {
            static let small = String(localized: "files.iconSize.small", defaultValue: "Small")
            static let medium = String(localized: "files.iconSize.medium", defaultValue: "Medium")
            static let large = String(localized: "files.iconSize.large", defaultValue: "Large")
            static let extraLarge = String(localized: "files.iconSize.extraLarge", defaultValue: "Extra Large")
        }

        enum Filter {
            static let all = String(localized: "files.filter.all", defaultValue: "All")
            static let folders = String(localized: "files.filter.folders", defaultValue: "Folders")
            static let images = String(localized: "files.filter.images", defaultValue: "Images")
            static let videos = String(localized: "files.filter.videos", defaultValue: "Videos")
            static let documents = String(localized: "files.filter.documents", defaultValue: "Documents")
            static let archives = String(localized: "files.filter.archives", defaultValue: "Archives")
            static let other = String(localized: "files.filter.other", defaultValue: "Other")
        }

        enum Sort {
            static let name = String(localized: "files.sort.name", defaultValue: "Name")
            static let nameDesc = String(localized: "files.sort.nameDesc", defaultValue: "Name (Z-A)")
            static let size = String(localized: "files.sort.size", defaultValue: "Size")
            static let sizeDesc = String(localized: "files.sort.sizeDesc", defaultValue: "Size (Large to Small)")
            static let date = String(localized: "files.sort.date", defaultValue: "Date")
            static let dateDesc = String(localized: "files.sort.dateDesc", defaultValue: "Date (Newest First)")
            static let type = String(localized: "files.sort.type", defaultValue: "Type")
        }

        enum Menu {
            static let filterSection = String(localized: "files.menu.filterSection", defaultValue: "Filter")
            static let sortSection = String(localized: "files.menu.sortSection", defaultValue: "Sort")
        }

        enum FileType {
            static let folder = String(localized: "files.type.folder", defaultValue: "Folder")
            static let image = String(localized: "files.type.image", defaultValue: "Image")
            static let video = String(localized: "files.type.video", defaultValue: "Video")
            static let audio = String(localized: "files.type.audio", defaultValue: "Audio")
            static let pdf = String(localized: "files.type.pdf", defaultValue: "PDF Document")
            static let text = String(localized: "files.type.text", defaultValue: "Text File")
            static let unknown = String(localized: "files.type.unknown", defaultValue: "Unknown Type")
            static let wordDocument = String(localized: "files.type.wordDocument", defaultValue: "Word Document")
            static let excelSpreadsheet = String(localized: "files.type.excelSpreadsheet", defaultValue: "Excel Spreadsheet")
            static let powerPoint = String(localized: "files.type.powerPoint", defaultValue: "PowerPoint")
            static let archive = String(localized: "files.type.archive", defaultValue: "Archive")
            static let htmlDocument = String(localized: "files.type.htmlDocument", defaultValue: "HTML Document")
            static let cssStylesheet = String(localized: "files.type.cssStylesheet", defaultValue: "CSS Stylesheet")
            static let javaScript = String(localized: "files.type.javaScript", defaultValue: "JavaScript")
            static let jsonFile = String(localized: "files.type.jsonFile", defaultValue: "JSON File")
            static let xmlFile = String(localized: "files.type.xmlFile", defaultValue: "XML File")
            static let swiftSource = String(localized: "files.type.swiftSource", defaultValue: "Swift Source")
            static let markdown = String(localized: "files.type.markdown", defaultValue: "Markdown")
            static let document = String(localized: "files.type.document", defaultValue: "Document")

            static func extensionFile(_ ext: String) -> String {
                String(format: NSLocalizedString("files.type.extensionFile", value: "%@ File", comment: ""), ext)
            }
        }

        enum TableColumn {
            static let name = String(localized: "files.tableColumn.name", defaultValue: "Name")
            static let size = String(localized: "files.tableColumn.size", defaultValue: "Size")
            static let modified = String(localized: "files.tableColumn.modified", defaultValue: "Modified")
            static let kind = String(localized: "files.tableColumn.kind", defaultValue: "Kind")
        }

        static func itemsSelected(_ count: Int) -> String {
            String(format: NSLocalizedString("files.selection.count", value: "%d items selected", comment: ""), count)
        }

        enum State {
            static let loadingFileList = String(localized: "files.state.loadingFileList", defaultValue: "Loading file list...")
            static let loadFailed = String(localized: "files.state.loadFailed", defaultValue: "Loading Failed")
            static let notConnectedToR2 = String(localized: "files.state.notConnectedToR2", defaultValue: "Not connected to R2")
            static let configureAccountPrompt = String(localized: "files.state.configureAccountPrompt",
                defaultValue: "Please select \"Account Settings\" in the sidebar to configure your R2 account")
            static let selectBucket = String(localized: "files.state.selectBucket", defaultValue: "Please select a bucket")
            static let selectBucketPrompt = String(localized: "files.state.selectBucketPrompt",
                defaultValue: "Please select \"Buckets\" in the sidebar to select a bucket to operate on")
        }

        enum DropZone {
            static let title = String(localized: "files.dropZone.title", defaultValue: "Drop Files to Upload")
        }

        enum ContextMenu {
            static let download = String(localized: "files.contextMenu.download", defaultValue: "Download")
            static let copyLink = String(localized: "files.contextMenu.copyLink", defaultValue: "Copy Link")
            static let delete = String(localized: "files.contextMenu.delete", defaultValue: "Delete")
            static let moveTo = String(localized: "files.contextMenu.moveTo", defaultValue: "Move to")
            static let parentFolder = String(localized: "files.contextMenu.parentFolder", defaultValue: "Parent Folder (..)")
        }

        static let defaultFileName = String(localized: "files.defaultFileName", defaultValue: "File")
        static let selectDownloadFolder = String(localized: "files.selectDownloadFolder", defaultValue: "Select Download Folder")
    }

    // MARK: - Upload

    enum Upload {
        enum Queue {
            static let title = String(localized: "upload.queue.title", defaultValue: "Upload Queue")

            static func fileCount(_ count: Int) -> String {
                String(format: NSLocalizedString("upload.queue.fileCount", value: "(%d files)", comment: ""), count)
            }

            static func remaining(_ time: String) -> String {
                String(format: NSLocalizedString("upload.queue.remaining", value: "Remaining %@", comment: ""), time)
            }

            static func uploading(_ count: Int) -> String {
                String(format: NSLocalizedString("upload.queue.uploading", value: "%d uploading", comment: ""), count)
            }

            static func pending(_ count: Int) -> String {
                String(format: NSLocalizedString("upload.queue.pending", value: "%d pending", comment: ""), count)
            }

            static func completed(_ count: Int) -> String {
                String(format: NSLocalizedString("upload.queue.completed", value: "%d completed", comment: ""), count)
            }

            static func failed(_ count: Int) -> String {
                String(format: NSLocalizedString("upload.queue.failed", value: "%d failed", comment: ""), count)
            }
        }

        enum Status {
            static let pending = String(localized: "upload.status.pending", defaultValue: "Pending")
            static let uploading = String(localized: "upload.status.uploading", defaultValue: "Uploading")
            static let completed = String(localized: "upload.status.completed", defaultValue: "Completed")
            static let cancelled = String(localized: "upload.status.cancelled", defaultValue: "Cancelled")

            static func failed(_ error: String) -> String {
                String(format: NSLocalizedString("upload.status.failed", value: "Failed: %@", comment: ""), error)
            }
        }

        enum Action {
            static let retryFailed = String(localized: "upload.action.retryFailed", defaultValue: "Retry Failed")
            static let clearCompleted = String(localized: "upload.action.clearCompleted", defaultValue: "Clear Completed")
        }

        static func uploadingFile(_ name: String) -> String {
            String(format: NSLocalizedString("upload.uploadingFile", value: "Uploading '%@'...", comment: ""), name)
        }
    }

    // MARK: - Move

    enum Move {
        enum Queue {
            static let title = String(localized: "move.queue.title", defaultValue: "Move Queue")
        }

        enum Status {
            static let moving = String(localized: "move.status.moving", defaultValue: "Moving")
            static let completed = String(localized: "move.status.completed", defaultValue: "Moved")

            static func failed(_ error: String) -> String {
                String(format: NSLocalizedString("move.status.failed", value: "Move failed: %@", comment: ""), error)
            }
        }

        enum Message {
            static let moveFailed = String(localized: "move.message.moveFailed", defaultValue: "Move Failed")
            static let noMoveNeeded = String(localized: "move.message.noMoveNeeded", defaultValue: "No Move Needed")
            static let alreadyAtDestination = String(localized: "move.message.alreadyAtDestination", defaultValue: "File is already at the destination")
        }

        static let rootDirectory = String(localized: "move.rootDirectory", defaultValue: "Root")
    }

    // MARK: - Account

    enum Account {
        enum Settings {
            static let title = String(localized: "account.settings.title", defaultValue: "Settings")
            static let subtitle = String(localized: "account.settings.subtitle", defaultValue: "Manage your R2 accounts")
            static let sectionTitle = String(localized: "account.settings.section", defaultValue: "Account")
            static let noAccounts = String(localized: "account.settings.noAccounts", defaultValue: "No accounts")
        }

        enum Add {
            static let title = String(localized: "account.add.title", defaultValue: "Add Account")
            static let accountInfo = String(localized: "account.add.accountInfo", defaultValue: "Account Info")
            static let credentials = String(localized: "account.add.credentials", defaultValue: "Credentials")
            static let endpoint = String(localized: "account.add.endpoint", defaultValue: "Endpoint")
            static let publicDomains = String(localized: "account.add.publicDomains", defaultValue: "Public Domains")
            static let testingConnection = String(localized: "account.add.testingConnection", defaultValue: "Testing connection...")
        }

        enum Edit {
            static let title = String(localized: "account.edit.title", defaultValue: "Edit Account")
            static let saving = String(localized: "account.edit.saving", defaultValue: "Saving...")
        }

        enum Field {
            static let displayName = String(localized: "account.field.displayName", defaultValue: "Display Name")
            static let accountID = String(localized: "account.field.accountID", defaultValue: "Account ID")
            static let accessKeyID = String(localized: "account.field.accessKeyID", defaultValue: "Access Key ID")
            static let secretAccessKey = String(localized: "account.field.secretAccessKey", defaultValue: "Secret Access Key")
            static let secretAccessKeyHint = String(localized: "account.field.secretAccessKeyHint", defaultValue: "Leave empty to keep unchanged")
            static let endpointURL = String(localized: "account.field.endpointURL", defaultValue: "Endpoint URL")
            static let endpointHint = String(localized: "account.field.endpointHint",
                defaultValue: "Leave empty for default: https://{accountID}.r2.cloudflarestorage.com")
        }

        enum Domain {
            static let placeholder = String(localized: "account.domain.placeholder", defaultValue: "cdn.example.com")
            static let hint = String(localized: "account.domain.hint", defaultValue: "Optional. Used for generating share links and thumbnail preview.")
            static let setDefault = String(localized: "account.domain.setDefault", defaultValue: "Set default")
            static let defaultLabel = String(localized: "account.domain.defaultLabel", defaultValue: "Default")
        }

        enum Delete {
            static let title = String(localized: "account.delete.title", defaultValue: "Delete Account")

            static func confirmation(_ name: String) -> String {
                String(format: NSLocalizedString("account.delete.confirmation", value: "Are you sure you want to delete account '%@'?\n\nThis will remove all associated credentials.", comment: ""), name)
            }
        }

        enum Status {
            static func bucketsCount(_ count: Int) -> String {
                String(format: NSLocalizedString("account.status.bucketsCount", value: "%d buckets", comment: ""), count)
            }

            static func domainsCount(_ count: Int) -> String {
                String(format: NSLocalizedString("account.status.domainsCount", value: "%d domains", comment: ""), count)
            }
        }
    }

    // MARK: - Bucket

    enum Bucket {
        enum Add {
            static let title = String(localized: "bucket.add.title", defaultValue: "Add Bucket")
            static let namePlaceholder = String(localized: "bucket.add.namePlaceholder", defaultValue: "Bucket Name")
        }

        enum Select {
            static let title = String(localized: "bucket.select.title", defaultValue: "Select Bucket")
            static let prompt = String(localized: "bucket.select.prompt", defaultValue: "Please enter the R2 bucket name you want to access")
            static let nameLabel = String(localized: "bucket.select.nameLabel", defaultValue: "Bucket Name")
            static let nameHint = String(localized: "bucket.select.nameHint",
                defaultValue: "Bucket name is usually a combination of lowercase letters, numbers, and hyphens")
            static let connectButton = String(localized: "bucket.select.connectButton", defaultValue: "Connect to Bucket")
            static let connecting = String(localized: "bucket.select.connecting", defaultValue: "Connecting...")
        }

        enum Status {
            static func selected(_ name: String) -> String {
                String(format: NSLocalizedString("bucket.status.selected", value: "Selected: %@", comment: ""), name)
            }
        }

        enum Tips {
            static let title = String(localized: "bucket.tips.title", defaultValue: "Tips")
            static let tip1 = String(localized: "bucket.tips.tip1", defaultValue: "Make sure the bucket is created in Cloudflare R2 console")
            static let tip2 = String(localized: "bucket.tips.tip2", defaultValue: "Make sure your API Token has permission to access this bucket")
            static let tip3 = String(localized: "bucket.tips.tip3", defaultValue: "Bucket name is case-sensitive")
        }

        enum Action {
            static let enterFiles = String(localized: "bucket.action.enterFiles", defaultValue: "Manage Files")
            static let switchBucket = String(localized: "bucket.action.switchBucket", defaultValue: "Switch Bucket")

            static func attemptingConnection(_ bucket: String) -> String {
                String(format: NSLocalizedString("bucket.action.attemptingConnection", value: "Attempting to connect to: %@", comment: ""), bucket)
            }
        }
    }

    // MARK: - Folder

    enum Folder {
        enum Create {
            static let title = String(localized: "folder.create.title", defaultValue: "Create New Folder")
            static let namePlaceholder = String(localized: "folder.create.namePlaceholder", defaultValue: "Enter folder name")
            static let nameLabel = String(localized: "folder.create.nameLabel", defaultValue: "Folder Name")
            static let invalidCharsHint = String(localized: "folder.create.invalidCharsHint",
                defaultValue: "Folder name cannot contain: \\ / : * ? \" < > |")
            static let validName = String(localized: "folder.create.validName", defaultValue: "Folder name is valid")
            static let invalidName = String(localized: "folder.create.invalidName", defaultValue: "Folder name contains invalid characters")
            static let createButton = String(localized: "folder.create.button", defaultValue: "Create Folder")
        }
    }

    // MARK: - Welcome

    enum Welcome {
        static let title = String(localized: "welcome.title", defaultValue: "OwlUploader")
        static let subtitle = String(localized: "welcome.subtitle", defaultValue: "Professional R2 File Management Tool")
        static let getStarted = String(localized: "welcome.getStarted", defaultValue: "Get Started")
        static let navigationTitle = String(localized: "welcome.navigationTitle", defaultValue: "Welcome")

        enum Feature {
            static let fileManagementTitle = String(localized: "welcome.feature.fileManagement.title", defaultValue: "File Management")
            static let fileManagementDesc = String(localized: "welcome.feature.fileManagement.desc", defaultValue: "Browse and manage files in R2 buckets")

            static let uploadTitle = String(localized: "welcome.feature.upload.title", defaultValue: "File Upload")
            static let uploadDesc = String(localized: "welcome.feature.upload.desc", defaultValue: "Quickly upload local files to R2 storage")

            static let folderTitle = String(localized: "welcome.feature.folder.title", defaultValue: "Create Folders")
            static let folderDesc = String(localized: "welcome.feature.folder.desc", defaultValue: "Create and organize folders in R2")

            static let securityTitle = String(localized: "welcome.feature.security.title", defaultValue: "Secure Connection")
            static let securityDesc = String(localized: "welcome.feature.security.desc", defaultValue: "Store credentials securely with Keychain")
        }

        enum Status {
            static let configurePrompt = String(localized: "welcome.status.configurePrompt", defaultValue: "Please configure your R2 account to get started")
            static let selectBucketPrompt = String(localized: "welcome.status.selectBucketPrompt", defaultValue: "Account connected. Please select a bucket to operate on")
            static let configureAccount = String(localized: "welcome.status.configureAccount", defaultValue: "Configure Account")
            static let selectBucket = String(localized: "welcome.status.selectBucket", defaultValue: "Select Bucket")
            static let reconfigureAccount = String(localized: "welcome.status.reconfigureAccount", defaultValue: "Reconfigure Account")
            static let startManaging = String(localized: "welcome.status.startManaging", defaultValue: "Start Managing Files")
            static let readyToManage = String(localized: "welcome.status.readyToManage", defaultValue: "You're ready to start managing files!")

            static func currentBucket(_ name: String) -> String {
                String(format: NSLocalizedString("welcome.status.currentBucket", value: "Current bucket: %@", comment: ""), name)
            }
        }
    }

    // MARK: - About

    enum About {
        static let title = String(localized: "about.title", defaultValue: "About")

        static func version(_ version: String) -> String {
            String(format: NSLocalizedString("about.version", value: "Version %@", comment: ""), version)
        }

        static let copyright = String(localized: "about.copyright", defaultValue: "© 2025 OwlUploader. All rights reserved.")
    }

    // MARK: - Settings

    enum Settings {
        static let language = String(localized: "settings.language", defaultValue: "Language")
        static let selectLanguage = String(localized: "settings.selectLanguage", defaultValue: "Select Language")
        static let languageHint = String(localized: "settings.languageHint", defaultValue: "App needs to restart for language change to take effect")
        static let followSystem = String(localized: "settings.followSystem", defaultValue: "Follow System")

        enum General {
            static let title = String(localized: "settings.general.title", defaultValue: "General")
        }

        enum Restart {
            static let title = String(localized: "settings.restart.title", defaultValue: "Restart Required")
            static let message = String(localized: "settings.restart.message", defaultValue: "The language change will take effect after restarting the app.")
            static let restartNow = String(localized: "settings.restart.restartNow", defaultValue: "Restart Now")
            static let later = String(localized: "settings.restart.later", defaultValue: "Later")
        }

        enum Upload {
            static let title = String(localized: "settings.upload.title", defaultValue: "Upload Settings")
            static let concurrentUploads = String(localized: "settings.upload.concurrentUploads", defaultValue: "Concurrent Uploads")
            static let concurrentHint = String(localized: "settings.upload.concurrentHint", defaultValue: "Higher values may speed up batch uploads, but might cause network congestion")
        }

        enum Move {
            static let title = String(localized: "settings.move.title", defaultValue: "Move Settings")
            static let concurrentMoves = String(localized: "settings.move.concurrentMoves", defaultValue: "Concurrent Moves")
            static let concurrentHint = String(localized: "settings.move.concurrentHint", defaultValue: "Number of files to move simultaneously")
        }

        enum Theme {
            static let title = String(localized: "settings.theme.title", defaultValue: "Appearance")
            static let selectTheme = String(localized: "settings.theme.selectTheme", defaultValue: "Theme")
            static let followSystem = String(localized: "settings.theme.followSystem", defaultValue: "Follow System")
            static let light = String(localized: "settings.theme.light", defaultValue: "Light")
            static let dark = String(localized: "settings.theme.dark", defaultValue: "Dark")
        }
    }

    // MARK: - Alerts

    enum Alert {
        enum Disconnect {
            static let title = String(localized: "alert.disconnect.title", defaultValue: "Disconnect")

            static func message(_ account: String) -> String {
                String(format: NSLocalizedString("alert.disconnect.message", value: "Are you sure you want to disconnect '%@'?", comment: ""), account)
            }

            static let description = String(localized: "alert.disconnect.description",
                defaultValue: "Disconnecting will clear the current session state, including selected bucket and file list.")
        }

        enum Delete {
            static let title = String(localized: "alert.delete.title", defaultValue: "Confirm Delete")

            static func fileMessage(_ name: String, _ size: String) -> String {
                String(format: NSLocalizedString("alert.delete.file.message", value: "Are you sure you want to delete file '%@'?\n\nFile size: %@", comment: ""), name, size)
            }

            static func folderMessage(_ name: String, _ count: Int) -> String {
                String(format: NSLocalizedString("alert.delete.folder.message", value: "Are you sure you want to delete folder '%@'?\n\nThis folder contains %d files and cannot be recovered.", comment: ""), name, count)
            }

            static func emptyFolderMessage(_ name: String) -> String {
                String(format: NSLocalizedString("alert.delete.emptyFolder.message", value: "Are you sure you want to delete empty folder '%@'?", comment: ""), name)
            }

            static func batchMessage(_ count: Int) -> String {
                String(format: NSLocalizedString("alert.delete.batch.message", value: "Delete %d files?", comment: ""), count)
            }

            static let irreversible = String(localized: "alert.delete.irreversible", defaultValue: "This action cannot be undone.")
        }
    }

    // MARK: - Preview

    enum Preview {
        static let loading = String(localized: "preview.loading", defaultValue: "Loading preview...")
        static let cannotPreview = String(localized: "preview.cannotPreview", defaultValue: "Cannot Preview")
        static let unsupportedType = String(localized: "preview.unsupportedType", defaultValue: "This file type is not supported for preview")
        static let cannotLoadImage = String(localized: "preview.cannotLoadImage", defaultValue: "Cannot load image")
        static let cannotLoadVideo = String(localized: "preview.cannotLoadVideo", defaultValue: "Cannot load video")
        static let cannotLoadPDF = String(localized: "preview.cannotLoadPDF", defaultValue: "Cannot load PDF")
        static let cannotLoadText = String(localized: "preview.cannotLoadText", defaultValue: "Cannot load text content")

        static func fileType(_ ext: String) -> String {
            String(format: NSLocalizedString("preview.fileType", value: "File type: %@", comment: ""), ext)
        }
    }

    // MARK: - Diagnostics

    enum Diagnostics {
        static let title = String(localized: "diagnostics.title", defaultValue: "Upload Diagnostics")
        static let subtitle = String(localized: "diagnostics.subtitle", defaultValue: "Check upload function configuration and status")
        static let checking = String(localized: "diagnostics.checking", defaultValue: "Checking configuration...")
        static let startDiagnostics = String(localized: "diagnostics.startDiagnostics", defaultValue: "Start Diagnostics")
        static let systemDiagnostics = String(localized: "diagnostics.systemDiagnostics", defaultValue: "System Diagnostics")
        static let clickToStart = String(localized: "diagnostics.clickToStart", defaultValue: "Click \"Start Diagnostics\" to check upload function status")
        static let itemsToCheck = String(localized: "diagnostics.itemsToCheck", defaultValue: "Items to check:")
        static let issuesFound = String(localized: "diagnostics.issuesFound", defaultValue: "Issues found:")
        static let suggestions = String(localized: "diagnostics.suggestions", defaultValue: "Suggestions:")
        static let allChecksPassed = String(localized: "diagnostics.allChecksPassed", defaultValue: "All checks passed")
        static let canUseUpload = String(localized: "diagnostics.canUseUpload", defaultValue: "You can use the file upload function")
        static let uploadReady = String(localized: "diagnostics.uploadReady", defaultValue: "Upload Ready")
        static let issuesNeedResolving = String(localized: "diagnostics.issuesNeedResolving", defaultValue: "Issues need to be resolved")

        enum CheckItem {
            static let accountConnection = String(localized: "diagnostics.checkItem.accountConnection", defaultValue: "Account connection status")
            static let bucketSelection = String(localized: "diagnostics.checkItem.bucketSelection", defaultValue: "Bucket selection status")
            static let accountConfig = String(localized: "diagnostics.checkItem.accountConfig", defaultValue: "Account configuration")
            static let endpointURL = String(localized: "diagnostics.checkItem.endpointURL", defaultValue: "Endpoint URL format")
            static let clientInit = String(localized: "diagnostics.checkItem.clientInit", defaultValue: "Client initialization")
        }
    }

    // MARK: - Help Tooltips

    enum Help {
        static let editAccount = String(localized: "help.editAccount", defaultValue: "Edit account")
        static let deleteAccount = String(localized: "help.deleteAccount", defaultValue: "Delete account")
        static let goUp = String(localized: "help.goUp", defaultValue: "Go to parent directory (Cmd+Up)")
        static let refresh = String(localized: "help.refresh", defaultValue: "Refresh (Cmd+R)")
        static let clearSelection = String(localized: "help.clearSelection", defaultValue: "Clear Selection (Esc)")
        static let newFolder = String(localized: "help.newFolder", defaultValue: "New Folder")
        static let uploadFile = String(localized: "help.uploadFile", defaultValue: "Upload File")
        static let filter = String(localized: "help.filter", defaultValue: "Filter")
        static let sort = String(localized: "help.sort", defaultValue: "Sort")
        static let download = String(localized: "help.download", defaultValue: "Download")
        static let copyLink = String(localized: "help.copyLink", defaultValue: "Copy Link")
        static let delete = String(localized: "help.delete", defaultValue: "Delete")
        static let previousFile = String(localized: "help.previousFile", defaultValue: "Previous (←)")
        static let nextFile = String(localized: "help.nextFile", defaultValue: "Next (→)")
        static let back = String(localized: "help.back", defaultValue: "Back")
        static let forward = String(localized: "help.forward", defaultValue: "Forward")
        static let moreOptions = String(localized: "help.moreOptions", defaultValue: "More Options")
        static let closeEsc = String(localized: "help.closeEsc", defaultValue: "Close (ESC)")
    }

    // MARK: - Commands

    enum Commands {
        static let settings = String(localized: "commands.settings", defaultValue: "Settings...")
        static let newFolder = String(localized: "commands.newFolder", defaultValue: "New Folder")
        static let selectAll = String(localized: "commands.selectAll", defaultValue: "Select All")
        static let deselectAll = String(localized: "commands.deselectAll", defaultValue: "Deselect All")
        static let refresh = String(localized: "commands.refresh", defaultValue: "Refresh")
        static let goUp = String(localized: "commands.goUp", defaultValue: "Go to Parent Directory")
        static let view = String(localized: "commands.view", defaultValue: "View")
        static let listView = String(localized: "commands.listView", defaultValue: "List View")
        static let tableView = String(localized: "commands.tableView", defaultValue: "Table View")
        static let iconView = String(localized: "commands.iconView", defaultValue: "Icon View")
    }

    // MARK: - Save Panel

    enum SavePanel {
        static let saveFile = String(localized: "savePanel.saveFile", defaultValue: "Save File")
        static let selectDownloadFolder = String(localized: "savePanel.selectDownloadFolder", defaultValue: "Select Download Folder")
    }
}

// MARK: - Error Messages

extension L {
    enum Error {
        // MARK: - Account Errors

        enum Account {
            static let notConfigured = String(localized: "error.account.notConfigured",
                defaultValue: "R2 account not configured. Please configure your R2 account first.")
            static let notConfiguredSuggestion = String(localized: "error.account.notConfigured.suggestion",
                defaultValue: "Go to Account Settings to configure your R2 account.")

            static let invalidCredentials = String(localized: "error.account.invalidCredentials",
                defaultValue: "Invalid R2 credentials. Please check your Access Key ID and Secret Access Key.")
            static let invalidCredentialsSuggestion = String(localized: "error.account.invalidCredentials.suggestion",
                defaultValue: "Please verify and re-enter your Access Key ID and Secret Access Key.")

            static let authenticationFailed = String(localized: "error.account.authenticationFailed",
                defaultValue: "Authentication failed. Please check your account credentials.")
            static let authenticationFailedSuggestion = String(localized: "error.account.authenticationFailed.suggestion",
                defaultValue: "Please reconfigure your account credentials.")

            static let invalidAccount = String(localized: "error.account.invalidAccount",
                defaultValue: "Invalid account configuration")
            static let invalidSecretKey = String(localized: "error.account.invalidSecretKey",
                defaultValue: "Invalid Secret Access Key")
            static let accountNotFound = String(localized: "error.account.accountNotFound",
                defaultValue: "Account not found")
            static let saveFailure = String(localized: "error.account.saveFailure",
                defaultValue: "Failed to save account configuration")
        }

        // MARK: - Network Errors

        enum Network {
            static func error(_ description: String) -> String {
                String(format: NSLocalizedString("error.network.general", value: "Network connection error: %@", comment: ""), description)
            }
            static let errorSuggestion = String(localized: "error.network.general.suggestion",
                defaultValue: "Please check your network connection and try again.")

            static let timeout = String(localized: "error.network.timeout",
                defaultValue: "Connection timed out. Please check your network connection and try again.")
            static let timeoutSuggestion = String(localized: "error.network.timeout.suggestion",
                defaultValue: "Check network connection stability and retry.")

            static let dnsResolutionFailed = String(localized: "error.network.dnsResolutionFailed",
                defaultValue: "DNS resolution failed. Please check if the endpoint URL is correct or if network connection is working.")
            static let dnsResolutionFailedSuggestion = String(localized: "error.network.dnsResolutionFailed.suggestion",
                defaultValue: "Verify endpoint URL is correct and check network DNS settings.")

            static let sslCertificateError = String(localized: "error.network.sslCertificateError",
                defaultValue: "SSL certificate verification failed. Please check if the endpoint URL supports HTTPS.")
            static let sslCertificateErrorSuggestion = String(localized: "error.network.sslCertificateError.suggestion",
                defaultValue: "Verify endpoint URL uses HTTPS protocol and has a valid certificate.")

            static func endpointNotReachable(_ endpoint: String) -> String {
                String(format: NSLocalizedString("error.network.endpointNotReachable", value: "Cannot connect to endpoint '%@'. Please check if the URL is correct and service is available.", comment: ""), endpoint)
            }
            static let endpointNotReachableSuggestion = String(localized: "error.network.endpointNotReachable.suggestion",
                defaultValue: "Check the following: 1) Endpoint URL format (should be https://accountID.r2.cloudflarestorage.com); 2) Network connection; 3) Firewall allows HTTPS; 4) Cloudflare R2 service availability.")
        }

        // MARK: - Bucket Errors

        enum Bucket {
            static func notFound(_ name: String) -> String {
                String(format: NSLocalizedString("error.bucket.notFound", value: "Bucket '%@' does not exist or you don't have access permission.", comment: ""), name)
            }
            static let notFoundSuggestion = String(localized: "error.bucket.notFound.suggestion",
                defaultValue: "Select an existing bucket or create a new one in Cloudflare console.")
        }

        // MARK: - File Errors

        enum File {
            static func notFound(_ name: String) -> String {
                String(format: NSLocalizedString("error.file.notFound", value: "File '%@' does not exist.", comment: ""), name)
            }

            static func invalidName(_ name: String) -> String {
                String(format: NSLocalizedString("error.file.invalidName", value: "File name '%@' contains invalid characters. Please use a valid file name.", comment: ""), name)
            }

            static func uploadFailed(_ name: String, _ error: String) -> String {
                String(format: NSLocalizedString("error.file.uploadFailed", value: "Failed to upload file '%@': %@", comment: ""), name, error)
            }

            static func downloadFailed(_ name: String, _ error: String) -> String {
                String(format: NSLocalizedString("error.file.downloadFailed", value: "Failed to download file '%@': %@", comment: ""), name, error)
            }

            static func deleteFailed(_ name: String, _ error: String) -> String {
                String(format: NSLocalizedString("error.file.deleteFailed", value: "Failed to delete file '%@': %@", comment: ""), name, error)
            }

            static func accessDenied(_ name: String) -> String {
                String(format: NSLocalizedString("error.file.accessDenied", value: "Cannot access file '%@'. Application doesn't have permission to read this file.", comment: ""), name)
            }
            static let accessDeniedSuggestion = String(localized: "error.file.accessDenied.suggestion",
                defaultValue: "Try these solutions: 1) Move file to Documents folder or Desktop; 2) Check file permissions; 3) Reselect file for upload.")

            static func sizeExceeded(_ name: String) -> String {
                String(format: NSLocalizedString("error.file.sizeExceeded", value: "File '%@' exceeds size limit. Maximum file size is 5GB.", comment: ""), name)
            }
            static let sizeExceededSuggestion = String(localized: "error.file.sizeExceeded.suggestion",
                defaultValue: "Select a file smaller than 5GB for upload.")

            static let noFiles = String(localized: "error.file.noFiles",
                defaultValue: "No valid files detected")
        }

        // MARK: - Folder Errors

        enum Folder {
            static func createFailed(_ name: String, _ error: String) -> String {
                String(format: NSLocalizedString("error.folder.createFailed", value: "Failed to create folder '%@': %@", comment: ""), name, error)
            }
        }

        // MARK: - Permission Errors

        enum Permission {
            static func denied(_ operation: String) -> String {
                String(format: NSLocalizedString("error.permission.denied", value: "Insufficient permission to perform '%@'. Please check your account permissions.", comment: ""), operation)
            }
            static let deniedSuggestion = String(localized: "error.permission.denied.suggestion",
                defaultValue: "Contact administrator to check your account permission settings.")
        }

        // MARK: - Storage Errors

        enum Storage {
            static let quotaExceeded = String(localized: "error.storage.quotaExceeded",
                defaultValue: "Storage quota exceeded. Cannot upload more files. Please clear space or upgrade account.")
            static let quotaExceededSuggestion = String(localized: "error.storage.quotaExceeded.suggestion",
                defaultValue: "Delete unnecessary files or contact administrator to expand capacity.")
        }

        // MARK: - Server Errors

        enum Server {
            static func error(_ message: String) -> String {
                String(format: NSLocalizedString("error.server.error", value: "Server error: %@", comment: ""), message)
            }
        }

        // MARK: - Service Errors

        enum Service {
            static let r2NotInitialized = String(localized: "error.service.r2NotInitialized",
                defaultValue: "R2 service not initialized")
        }

        // MARK: - Unknown Errors

        enum Unknown {
            static func error(_ description: String) -> String {
                String(format: NSLocalizedString("error.unknown", value: "Unknown error: %@", comment: ""), description)
            }
        }

        // MARK: - Keychain Errors

        enum Keychain {
            static let invalidData = String(localized: "error.keychain.invalidData",
                defaultValue: "Invalid data format")
            static let itemNotFound = String(localized: "error.keychain.itemNotFound",
                defaultValue: "Item not found")
            static let duplicateItem = String(localized: "error.keychain.duplicateItem",
                defaultValue: "Item already exists")
            static func unexpectedError(_ status: Int32) -> String {
                String(format: NSLocalizedString("error.keychain.unexpectedError", value: "Keychain operation failed (status code: %d)", comment: ""), status)
            }
        }
    }
}

// MARK: - User Feedback Messages

extension L {
    enum Message {
        // MARK: - Success Messages

        enum Success {
            // Upload
            static let uploadComplete = String(localized: "message.success.upload.title", defaultValue: "Upload Complete")

            static func uploadDescription(_ fileName: String) -> String {
                String(format: NSLocalizedString("message.success.upload.description", value: "%@ uploaded successfully", comment: ""), fileName)
            }

            static func uploadToBucket(_ fileName: String, _ bucket: String) -> String {
                String(format: NSLocalizedString("message.success.upload.toBucket", value: "File '%@' uploaded to %@ successfully", comment: ""), fileName, bucket)
            }

            static func uploadBatchDescription(_ count: Int) -> String {
                String(format: NSLocalizedString("message.success.upload.batch", value: "%d files uploaded", comment: ""), count)
            }

            // Download
            static let downloadComplete = String(localized: "message.success.download.title", defaultValue: "Download Complete")

            static func downloadDescription(_ fileName: String) -> String {
                String(format: NSLocalizedString("message.success.download.description", value: "%@ saved successfully", comment: ""), fileName)
            }

            static func downloadBatchDescription(_ count: Int) -> String {
                String(format: NSLocalizedString("message.success.download.batch", value: "%d files downloaded", comment: ""), count)
            }

            // Delete
            static let deleteComplete = String(localized: "message.success.delete.title", defaultValue: "Deleted Successfully")

            static func deleteFileDescription(_ fileName: String) -> String {
                String(format: NSLocalizedString("message.success.delete.file", value: "File '%@' deleted successfully", comment: ""), fileName)
            }

            static func deleteFolderDescription(_ folderName: String, _ count: Int) -> String {
                String(format: NSLocalizedString("message.success.delete.folder", value: "Folder '%@' and %d files deleted", comment: ""), folderName, count)
            }

            static func deleteBatchDescription(_ count: Int) -> String {
                String(format: NSLocalizedString("message.success.delete.batch", value: "%d files deleted", comment: ""), count)
            }

            // Folder
            static let folderCreated = String(localized: "message.success.folder.created.title", defaultValue: "Created Successfully")

            static func folderCreatedDescription(_ name: String) -> String {
                String(format: NSLocalizedString("message.success.folder.created.description", value: "Folder '%@' created successfully", comment: ""), name)
            }

            // Account
            static let accountAdded = String(localized: "message.success.account.added.title", defaultValue: "Account Added")

            static func accountAddedDescription(_ name: String) -> String {
                String(format: NSLocalizedString("message.success.account.added.description", value: "'%@' connected successfully", comment: ""), name)
            }

            static let accountSaved = String(localized: "message.success.account.saved.title", defaultValue: "Saved Successfully")

            static func accountSavedDescription(_ name: String) -> String {
                String(format: NSLocalizedString("message.success.account.saved.description", value: "Account '%@' updated", comment: ""), name)
            }

            static let accountDeleted = String(localized: "message.success.account.deleted.title", defaultValue: "Account Deleted")

            static func accountDeletedDescription(_ name: String) -> String {
                String(format: NSLocalizedString("message.success.account.deleted.description", value: "'%@' removed from list", comment: ""), name)
            }

            // Bucket
            static let bucketAdded = String(localized: "message.success.bucket.added.title", defaultValue: "Bucket Added")

            static func bucketAddedDescription(_ name: String) -> String {
                String(format: NSLocalizedString("message.success.bucket.added.description", value: "'%@' added successfully", comment: ""), name)
            }

            // Connection
            static let connected = String(localized: "message.success.connected.title", defaultValue: "Connected")

            static func connectedDescription(_ bucket: String) -> String {
                String(format: NSLocalizedString("message.success.connected.description", value: "Connected to '%@'", comment: ""), bucket)
            }

            static func connectedToBucket(_ bucket: String) -> String {
                String(format: NSLocalizedString("message.success.connected.toBucket", value: "Connected to bucket '%@' successfully", comment: ""), bucket)
            }

            static let autoConnected = String(localized: "message.success.autoConnected.title", defaultValue: "Auto Connected")

            static func autoConnectedDescription(_ bucket: String) -> String {
                String(format: NSLocalizedString("message.success.autoConnected.description", value: "Connected to default bucket '%@'", comment: ""), bucket)
            }

            static let disconnected = String(localized: "message.success.disconnected.title", defaultValue: "Disconnected Successfully")
            static let disconnectedDescription = String(localized: "message.success.disconnected.description",
                defaultValue: "Disconnected from R2 service. You can reconfigure your account.")

            // Link
            static let linkCopied = String(localized: "message.success.linkCopied.title", defaultValue: "Link Copied")
            static let linkCopiedDescription = String(localized: "message.success.linkCopied.description", defaultValue: "File URL copied to clipboard")
        }

        // MARK: - Error Messages

        enum Error {
            static let uploadFailed = String(localized: "message.error.upload.title", defaultValue: "Upload Failed")
            static let downloadFailed = String(localized: "message.error.download.title", defaultValue: "Download Failed")
            static let deleteFailed = String(localized: "message.error.delete.title", defaultValue: "Delete Failed")
            static let connectionFailed = String(localized: "message.error.connection.title", defaultValue: "Connection Failed")
            static let saveFailed = String(localized: "message.error.save.title", defaultValue: "Save Failed")
            static let importFailed = String(localized: "message.error.import.title", defaultValue: "Import Failed")
            static let autoConnectionFailed = String(localized: "message.error.autoConnection.title", defaultValue: "Auto Connection Failed")
            static let connectionTestFailed = String(localized: "message.error.connectionTest.title", defaultValue: "Connection test failed")

            static let cannotUpload = String(localized: "message.error.cannotUpload", defaultValue: "Cannot Upload")
            static let cannotDelete = String(localized: "message.error.cannotDelete", defaultValue: "Cannot Delete")
            static let serviceNotReady = String(localized: "message.error.serviceNotReady",
                defaultValue: "Service not ready. Please connect your account and select a bucket first.")
            static let noBucketSelected = String(localized: "message.error.noBucketSelected",
                defaultValue: "Please select a bucket first")
            static let enterBucketName = String(localized: "message.error.enterBucketName",
                defaultValue: "Please enter bucket name")

            static func fileNotExists(_ fileName: String) -> String {
                String(format: NSLocalizedString("message.error.fileNotExists", value: "Cannot find file '%@'. Please reselect.", comment: ""), fileName)
            }

            static func fileTooLarge(_ fileName: String, _ size: String) -> String {
                String(format: NSLocalizedString("message.error.fileTooLarge", value: "File '%@' is %@, exceeds 5GB limit", comment: ""), fileName, size)
            }

            static let filePermissionDenied = String(localized: "message.error.filePermissionDenied",
                defaultValue: "File Permission Denied")

            static func filePermissionDeniedDetail(_ fileName: String) -> String {
                String(format: NSLocalizedString("message.error.filePermissionDenied.detail", value: "Cannot access file '%@'. Application doesn't have permission to read this file. Suggestions: 1) Move file to Documents folder or Desktop; 2) Check file permissions; 3) Reselect file for upload.", comment: ""), fileName)
            }

            static func fileReadFailed(_ fileName: String, _ error: String) -> String {
                String(format: NSLocalizedString("message.error.fileReadFailed", value: "Cannot read file '%@': %@", comment: ""), fileName, error)
            }

            static func cannotDeleteFile(_ name: String, _ error: String) -> String {
                String(format: NSLocalizedString("message.error.cannotDeleteFile", value: "Failed to delete file '%@': %@", comment: ""), name, error)
            }

            static func cannotDeleteFolder(_ name: String, _ error: String) -> String {
                String(format: NSLocalizedString("message.error.cannotDeleteFolder", value: "Failed to delete folder '%@': %@", comment: ""), name, error)
            }

            static func cannotConnectToBucket(_ name: String) -> String {
                String(format: NSLocalizedString("message.error.cannotConnectToBucket", value: "Cannot connect to default bucket '%@'. Please try manually.", comment: ""), name)
            }

            static let dragFailed = String(localized: "message.error.dragFailed", defaultValue: "Drag Failed")
            static let noValidFiles = String(localized: "message.error.noValidFiles", defaultValue: "No Valid Files")
            static let allFilesInvalid = String(localized: "message.error.allFilesInvalid",
                defaultValue: "All dragged files do not meet upload requirements")

            static func dragProcessFailed(_ error: String) -> String {
                String(format: NSLocalizedString("message.error.dragProcessFailed", value: "Error processing dragged files: %@", comment: ""), error)
            }
        }

        // MARK: - Warning Messages

        enum Warning {
            static let noFilesSelected = String(localized: "message.warning.noFilesSelected.title", defaultValue: "No Files Selected")
            static let selectFilesToDelete = String(localized: "message.warning.selectFilesToDelete",
                defaultValue: "Please select files to delete")
            static let selectFilesToDownload = String(localized: "message.warning.selectFilesToDownload",
                defaultValue: "Please select files to download")

            static let partialDelete = String(localized: "message.warning.partialDelete.title", defaultValue: "Partially Deleted")

            static func partialDeleteDescription(_ success: Int, _ failed: Int) -> String {
                String(format: NSLocalizedString("message.warning.partialDelete.description", value: "%d succeeded, %d failed", comment: ""), success, failed)
            }

            static let partialDownload = String(localized: "message.warning.partialDownload.title", defaultValue: "Partially Downloaded")
        }

        // MARK: - Info Messages

        enum Info {
            static let accountDisconnected = String(localized: "message.info.accountDisconnected", defaultValue: "Account disconnected")
        }
    }
}
