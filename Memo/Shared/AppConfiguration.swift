//
//  AppConfiguration.swift
//  Memo
//

import Foundation

/// Build-wide switches.
enum AppConfiguration {

    /// Whether the app replicates decks through CloudKit.
    ///
    /// Currently `false`, because CloudKit requires a paid Apple Developer
    /// Program membership. A free personal team cannot provision the iCloud or
    /// Push Notifications capabilities, so a build carrying those entitlements
    /// fails to sign at all.
    ///
    /// Everything sync needs is still in place — the models keep the shape
    /// CloudKit requires (defaults on every property, optional relationships
    /// with inverses, no unique constraints, explicit sort indices), so turning
    /// this on later needs no migration and no model changes.
    ///
    /// To enable, once a paid membership is available:
    ///
    /// 1. Set this to `true`.
    /// 2. In the **Memo** target → **Signing & Capabilities**, add **iCloud**
    ///    with **CloudKit** ticked and the container
    ///    `iCloud.com.javier.memo`, plus **Background Modes → Remote
    ///    notifications** and **Push Notifications**. That restores
    ///    `CODE_SIGN_ENTITLEMENTS = Memo/Memo.entitlements`, which is still in
    ///    the repository and still correct.
    ///
    /// Until both are done the app runs entirely on-device. Nothing else in the
    /// codebase branches on this beyond ``MemoModelContainer`` and
    /// ``CloudSyncStatus``.
    static let isCloudSyncEnabled = false

    /// Subsystem used for all `Logger` instances.
    ///
    /// Derived from the bundle identifier rather than hardcoded, so it follows
    /// the target instead of drifting when the identifier changes — which it
    /// does, for instance when signing with a free personal team.
    static let loggingSubsystem = Bundle.main.bundleIdentifier ?? "com.javier.memo"
}
