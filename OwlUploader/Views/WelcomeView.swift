//
//  WelcomeView.swift
//  OwlUploader
//
//  Professional welcome screen with clean design
//  Displays connection status and guides user to next action
//

import SwiftUI

/// Welcome view - professional macOS native style
struct WelcomeView: View {
    /// R2 service instance
    @ObservedObject var r2Service: R2Service

    /// Open settings action
    @Environment(\.openSettings) private var openSettings

    /// Callback to navigate to buckets
    var onNavigateToBuckets: (() -> Void)?

    /// Callback to navigate to files
    var onNavigateToFiles: (() -> Void)?

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // Main content
            VStack(spacing: AppSpacing.xLarge) {
                // App icon with gradient background
                appIconView

                // Title section
                titleSection

                // Status card
                statusCard

                // CTA button
                ctaButton
            }
            .frame(maxWidth: 400)

            Spacer()

            // Bottom hint
            bottomHint
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppColors.windowBackground)
        .navigationTitle(L.Welcome.navigationTitle)
    }

    // MARK: - App Icon View

    private var appIconView: some View {
        ZStack {
            // Gradient circle background
            Circle()
                .fill(
                    LinearGradient(
                        colors: [
                            AppColors.primary.opacity(0.12),
                            AppColors.primary.opacity(0.06)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 140, height: 140)

            // App icon
            if let appIcon = NSApplication.shared.applicationIconImage {
                Image(nsImage: appIcon)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 80, height: 80)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
            }
        }
    }

    // MARK: - Title Section

    private var titleSection: some View {
        VStack(spacing: AppSpacing.small) {
            Text(L.Welcome.title)
                .font(AppTypography.largeTitle)
                .foregroundColor(AppColors.textPrimary)

            Text(L.Welcome.subtitle)
                .font(AppTypography.callout)
                .foregroundColor(AppColors.textSecondary)
        }
    }

    // MARK: - Status Card

    private var statusCard: some View {
        HStack(spacing: AppSpacing.medium) {
            // Status indicator
            Circle()
                .fill(r2Service.isConnected ? AppColors.success : AppColors.textTertiary)
                .frame(width: 8, height: 8)

            // Status text
            VStack(alignment: .leading, spacing: 2) {
                Text(statusTitle)
                    .font(AppTypography.body)
                    .foregroundColor(AppColors.textPrimary)

                Text(statusSubtitle)
                    .font(AppTypography.caption)
                    .foregroundColor(AppColors.textSecondary)
            }

            Spacer()
        }
        .padding(.horizontal, AppSpacing.large)
        .padding(.vertical, AppSpacing.medium)
        .background(AppColors.contentBackground)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(AppColors.separator, lineWidth: 1)
        )
        .cornerRadius(10)
    }

    // MARK: - CTA Button

    private var ctaButton: some View {
        Button(action: handleCTAAction) {
            HStack(spacing: AppSpacing.small) {
                Image(systemName: ctaIcon)
                Text(ctaTitle)
            }
            .frame(minWidth: 180)
        }
        .buttonStyle(.appPrimary)
    }

    // MARK: - Bottom Hint

    private var bottomHint: some View {
        HStack(spacing: AppSpacing.small) {
            Image(systemName: "lightbulb")
                .font(.system(size: 12))
                .foregroundColor(AppColors.textTertiary)

            Text(L.Welcome.Status.selectBucketPrompt)
                .font(AppTypography.caption)
                .foregroundColor(AppColors.textTertiary)
        }
        .padding(.bottom, AppSpacing.xLarge)
        .opacity(r2Service.isConnected ? 1 : 0)
    }

    // MARK: - Computed Properties

    private var statusTitle: String {
        if !r2Service.isConnected {
            return L.Common.Status.notConnected
        } else if let account = R2AccountManager.shared.currentAccount {
            return L.Common.Status.connected + " - " + account.displayName
        } else {
            return L.Common.Status.connected
        }
    }

    private var statusSubtitle: String {
        if !r2Service.isConnected {
            return L.Welcome.Status.configurePrompt
        } else if let bucket = r2Service.selectedBucket {
            return L.Welcome.Status.currentBucket(bucket.name)
        } else {
            return L.Welcome.Status.selectBucketPrompt
        }
    }

    private var ctaTitle: String {
        if !r2Service.isConnected {
            return L.Welcome.Status.configureAccount
        } else if r2Service.selectedBucket == nil {
            return L.Welcome.Status.selectBucket
        } else {
            return L.Welcome.Status.startManaging
        }
    }

    private var ctaIcon: String {
        if !r2Service.isConnected {
            return "gearshape"
        } else if r2Service.selectedBucket == nil {
            return "externaldrive"
        } else {
            return "folder"
        }
    }

    // MARK: - Actions

    private func handleCTAAction() {
        if !r2Service.isConnected {
            openSettings()
        } else if r2Service.selectedBucket == nil {
            onNavigateToBuckets?()
        } else {
            onNavigateToFiles?()
        }
    }
}

// MARK: - Previews

#Preview("Not Connected") {
    WelcomeView(r2Service: R2Service.preview)
}

#Preview("Connected - No Bucket") {
    let service = R2Service.preview
    return WelcomeView(r2Service: service)
}
