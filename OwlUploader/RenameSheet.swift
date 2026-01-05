//
//  RenameSheet.swift
//  OwlUploader
//
//  Rename file/folder sheet component
//  Used to rename files and folders with validation
//

import SwiftUI

struct RenameSheet: View {

    // MARK: - Bindings

    /// Whether the sheet is presented
    @Binding var isPresented: Bool

    /// The file to rename
    let file: FileObject

    /// New name input
    @State private var newName: String = ""

    /// Input focus state
    @FocusState private var isTextFieldFocused: Bool

    /// Whether renaming is in progress
    @State private var isRenaming: Bool = false

    /// Rename callback: (file, newName)
    let onRename: (FileObject, String) -> Void

    // MARK: - Computed Properties

    /// Original file name (without trailing slash for folders)
    private var originalName: String {
        if file.isDirectory {
            let name = file.name
            return name.hasSuffix("/") ? String(name.dropLast()) : name
        }
        return file.name
    }

    /// Whether the name is valid
    private var isValidName: Bool {
        let trimmedName = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return false }

        // Check for illegal characters
        // S3/R2 key naming rules:
        // Cannot contain: \ / : * ? " < > |
        let illegalCharacters = CharacterSet(charactersIn: "\\/:*?\"<>|")
        let hasIllegalChars = trimmedName.rangeOfCharacter(from: illegalCharacters) != nil

        return !hasIllegalChars
    }

    /// Whether the name has changed
    private var hasChanges: Bool {
        newName.trimmingCharacters(in: .whitespacesAndNewlines) != originalName
    }

    /// Rename button is enabled
    private var canRename: Bool {
        return isValidName && hasChanges && !isRenaming
    }

    /// Validation status text and color
    private var validationStatus: (text: String, color: Color)? {
        let trimmedName = newName.trimmingCharacters(in: .whitespacesAndNewlines)

        if trimmedName.isEmpty {
            return nil
        }

        if !isValidName {
            return (L.Rename.invalidName, .red)
        }

        if !hasChanges {
            return (L.Rename.sameName, .orange)
        }

        return (L.Rename.validName, .green)
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 20) {
            // Title
            Text(L.Rename.title)
                .font(.title2)
                .fontWeight(.semibold)

            // Input section
            VStack(alignment: .leading, spacing: 8) {
                Text(L.Rename.nameLabel)
                    .font(.headline)
                    .foregroundColor(.primary)

                TextField(L.Rename.namePlaceholder, text: $newName)
                    .textFieldStyle(.roundedBorder)
                    .focused($isTextFieldFocused)
                    .onSubmit {
                        if canRename {
                            performRename()
                        }
                    }

                // Hints and validation info
                VStack(alignment: .leading, spacing: 4) {
                    Text(L.Rename.invalidCharsHint)
                        .font(.caption)
                        .foregroundColor(.secondary)

                    if let status = validationStatus {
                        Text(status.text)
                            .font(.caption)
                            .foregroundColor(status.color)
                    }
                }
            }

            // Button section
            HStack(spacing: 12) {
                // Cancel button
                Button(L.Common.Button.cancel) {
                    dismissSheet()
                }
                .keyboardShortcut(.escape, modifiers: [])
                .buttonStyle(.bordered)

                Spacer()

                // Rename button
                Button(L.Rename.renameButton) {
                    performRename()
                }
                .keyboardShortcut(.return, modifiers: [])
                .buttonStyle(.borderedProminent)
                .disabled(!canRename)

                if isRenaming {
                    ProgressView()
                        .scaleEffect(0.8)
                }
            }
        }
        .padding(24)
        .frame(width: 400)
        .background(Color(NSColor.windowBackgroundColor))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.2), radius: 10, x: 0, y: 5)
        .onAppear {
            print("📝 [RenameSheet] onAppear - file: \(file.name), originalName: \(originalName)")
            // Pre-fill with original name
            newName = originalName
            // Focus on text field after a short delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                isTextFieldFocused = true
            }
        }
    }

    // MARK: - Methods

    /// Perform rename
    private func performRename() {
        guard canRename else { return }

        let trimmedName = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        isRenaming = true

        // Call rename callback
        onRename(file, trimmedName)

        // Dismiss sheet immediately, rename is async
        dismissSheet()
    }

    /// Dismiss sheet
    private func dismissSheet() {
        newName = ""
        isRenaming = false
        isPresented = false
    }
}

// MARK: - Preview

#Preview {
    RenameSheet(
        isPresented: .constant(true),
        file: FileObject(
            name: "example.txt",
            key: "test/example.txt",
            size: 1024,
            lastModifiedDate: Date(),
            isDirectory: false
        ),
        onRename: { file, newName in
            print("Rename: \(file.name) -> \(newName)")
        }
    )
    .frame(width: 500, height: 300)
}
