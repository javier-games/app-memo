//
//  AppConfiguration.swift
//  Memo
//

import Foundation

/// Build-wide switches.
enum AppConfiguration {

    /// Whether the app replicates decks through CloudKit.
    ///
    /// Needs three things outside this file, or the app quietly stays
    /// on-device:
    ///
    /// 1. The **Memo** target signed with `Memo/Memo.entitlements` (iCloud with
    ///    CloudKit and the container `iCloud.com.javier.memo`, plus Push
    ///    Notifications) and the remote-notification background mode.
    /// 2. An App ID in the developer portal with those capabilities and that
    ///    container, which takes a paid Apple Developer Program membership.
    /// 3. The CloudKit schema deployed to production; see the README.
    ///
    /// Turning this off needs no migration: the store is the same file either
    /// way. Nothing else in the codebase branches on this beyond
    /// ``MemoModelContainer`` and ``CloudSyncStatus``.
    static let isCloudSyncEnabled = true

    /// Subsystem used for all `Logger` instances.
    ///
    /// Derived from the bundle identifier rather than hardcoded, so it follows
    /// the target instead of drifting when the identifier changes — which it
    /// does, for instance when signing with a free personal team.
    static let loggingSubsystem = Bundle.main.bundleIdentifier ?? "com.javier.memo"
}
