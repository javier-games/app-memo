//
//  AppConfiguration.swift
//  Memo
//

import Foundation

/// Build-wide switches.
enum AppConfiguration {

    /// Whether this build replicates decks through CloudKit.
    ///
    /// Sync has no switch of its own in the app: with this on, decks follow
    /// the iCloud account signed in on the device, and with no account they
    /// stay on the device. It needs three things outside this file:
    ///
    /// 1. The **Memo** target signed with `Memo/Memo.entitlements` (iCloud with
    ///    CloudKit and the container `iCloud.com.javier.memo`, plus Push
    ///    Notifications) and the remote-notification background mode.
    /// 2. An App ID in the developer portal with those capabilities and that
    ///    container, which takes a paid Apple Developer Program membership.
    /// 3. The CloudKit schema deployed to production; see the README.
    ///
    /// Set it to `false` for a build that cannot be signed that way.
    static let isCloudSyncAvailable = true

    /// The client ID of the GitHub OAuth app that signs users in for
    /// repository sync, with its device flow enabled.
    ///
    /// Not a secret: the device flow uses no client secret, and the ID alone
    /// grants nothing. Empty hides the feature, which is right for a build
    /// with no app registered.
    static let gitHubClientID = ""

    static var isRepositorySyncAvailable: Bool { !gitHubClientID.isEmpty }

    /// Subsystem used for all `Logger` instances.
    ///
    /// Derived from the bundle identifier rather than hardcoded, so it follows
    /// the target instead of drifting when the identifier changes — which it
    /// does, for instance when signing with a free personal team.
    static let loggingSubsystem = Bundle.main.bundleIdentifier ?? "com.javier.memo"
}
