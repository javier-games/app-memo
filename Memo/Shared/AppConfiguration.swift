//
//  AppConfiguration.swift
//  Memo
//

import Foundation

/// Build-wide switches.
enum AppConfiguration {

    /// Whether this build is able to replicate decks through CloudKit.
    ///
    /// Being able to is not the same as doing it: sync stays off until the
    /// user turns it on, which is ``CloudSyncPreference``'s business. This
    /// switch is for builds that cannot sync at all, and needs three things
    /// outside this file to be `true`:
    ///
    /// 1. The **Memo** target signed with `Memo/Memo.entitlements` (iCloud with
    ///    CloudKit and the container `iCloud.com.javier.memo`, plus Push
    ///    Notifications) and the remote-notification background mode.
    /// 2. An App ID in the developer portal with those capabilities and that
    ///    container, which takes a paid Apple Developer Program membership.
    /// 3. The CloudKit schema deployed to production; see the README.
    static let isCloudSyncAvailable = true

    /// Subsystem used for all `Logger` instances.
    ///
    /// Derived from the bundle identifier rather than hardcoded, so it follows
    /// the target instead of drifting when the identifier changes — which it
    /// does, for instance when signing with a free personal team.
    static let loggingSubsystem = Bundle.main.bundleIdentifier ?? "com.javier.memo"
}
