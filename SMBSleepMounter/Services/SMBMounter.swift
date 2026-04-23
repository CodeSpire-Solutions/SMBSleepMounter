//
//  SMBMounter.swift
//  SMBSleepMounter
//
//  Created by CodeSpire-Solutions on 20.04.2026
//

import AppKit
import Foundation
import NetFS

@MainActor
final class SMBMounter {
    private let store: ShareStore
    private var inFlight: Set<String> = []
    private var lastAttempt: [String: Date] = [:]
    private var mountAllTask: Task<Void, Never>?

    init(store: ShareStore) {
        self.store = store
    }

    func mountEligibleShares(reason: String) async {
        let eligible = store.shares.filter { $0.enabled && $0.mountOnWake }
        await mountShares(eligible, reason: reason)
    }

    func mountShares(_ shares: [SMBShare], reason: String) async {
        // Coalesce overlapping triggers (wake + periodic + manual).
        if let task = mountAllTask {
            await task.value
            return
        }

        let eligible = shares
        guard !eligible.isEmpty else {
            store.appendLog("\(reason): no eligible shares configured.")
            return
        }

        let task = Task {
            store.appendLog("\(reason): mounting \(eligible.count) share(s)...")
            for share in eligible {
                if reason == "Periodic" {
                    store.appendLog("Periodic: checking '\(share.name)'.")
                }
                await mountShareNoUI(share, reason: reason)
            }
            store.appendLog("\(reason): done.")
        }
        mountAllTask = task
        await task.value
        mountAllTask = nil
    }

    func mountNow(_ share: SMBShare) async {
        await mountShareInteractive(share, maxWaitSeconds: 30, reason: "Manual")
    }

    // Automatic mounting should never display authentication dialogs.
    // It uses NetFS with "NoUI" and will silently fail if credentials aren't available.
    private func mountShareNoUI(_ share: SMBShare, reason: String) async {
        guard let url = validatedSMBURL(from: share.urlString) else {
            store.appendLog("\(reason): invalid SMB URL for '\(share.name)': \(share.urlString)")
            return
        }

        guard let identity = normalizedIdentity(for: url) else {
            store.appendLog("\(reason): invalid SMB identity for '\(share.name)': \(share.urlString)")
            return
        }

        // If we're already trying to mount this share, don't spam Finder and trigger multiple auth dialogs.
        if inFlight.contains(identity) {
            store.appendLog("\(reason): '\(share.name)' mount already in progress; skipping duplicate request.")
            return
        }

        // Throttle repeated attempts (e.g. launch + wake close together).
        let now = Date()
        if let last = lastAttempt[identity], now.timeIntervalSince(last) < 20 {
            store.appendLog("\(reason): '\(share.name)' attempted recently; skipping.")
            return
        }
        lastAttempt[identity] = now

        if isShareMounted(url: url) {
            store.appendLog("\(reason): '\(share.name)' already mounted.")
            return
        }

        inFlight.insert(identity)
        defer { inFlight.remove(identity) }

        store.appendLog("\(reason): mounting '\(share.name)' (no UI)...")

        let status = await netFSMountNoUI(url: url)
        if status == 0 || isShareMounted(url: url) {
            store.appendLog("\(reason): '\(share.name)' mounted.")
        } else {
            store.appendLog("\(reason): failed to mount '\(share.name)' (status \(status)).")
            store.appendLog("\(reason): hint: mount once in Finder and save credentials in Keychain to avoid prompts.")
        }
    }

    // Manual mount can trigger the standard macOS authentication UI via Finder.
    private func mountShareInteractive(_ share: SMBShare, maxWaitSeconds: Int, reason: String) async {
        guard let url = validatedSMBURL(from: share.urlString) else {
            store.appendLog("\(reason): invalid SMB URL for '\(share.name)': \(share.urlString)")
            return
        }

        if isShareMounted(url: url) {
            store.appendLog("\(reason): '\(share.name)' already mounted.")
            return
        }

        store.appendLog("\(reason): mounting '\(share.name)'...")
        _ = NSWorkspace.shared.open(url)

        let deadline = Date().addingTimeInterval(TimeInterval(max(5, maxWaitSeconds)))
        while Date() < deadline {
            if isShareMounted(url: url) {
                store.appendLog("\(reason): '\(share.name)' mounted.")
                return
            }
            try? await Task.sleep(nanoseconds: 1_000_000_000)
        }

        store.appendLog("\(reason): failed to mount '\(share.name)' (timeout).")
    }

    private func netFSMountNoUI(url: URL) async -> Int {
        // NetFSMountURLSync is synchronous and may take a while; run it off the main actor.
        let task = Task.detached(priority: .utility) {
            var openOptions = NSMutableDictionary()
            openOptions[kNAUIOptionKey as String] = kNAUIOptionNoUI
            openOptions[kNetFSUseAuthenticationInfoKey as String] = true
            openOptions[kNetFSNoUserPreferencesKey as String] = true

            var mountpoints: Unmanaged<CFArray>?
            let status = NetFSMountURLSync(url as CFURL, nil, nil, nil, openOptions, nil, &mountpoints)
            return Int(status)
        }
        return await task.value
    }

    private func validatedSMBURL(from urlString: String) -> URL? {
        guard let url = URL(string: urlString) else { return nil }
        guard let scheme = url.scheme?.lowercased(), scheme == "smb" else { return nil }
        guard url.host != nil else { return nil }
        // Must have at least one path segment, e.g. /ShareName
        let trimmed = url.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard !trimmed.isEmpty else { return nil }
        return url
    }

    // Detect mount status without shelling out (sandbox-friendly):
    // `volumeURLForRemountingKey` is typically an smb:// URL for SMB volumes.
    private func isShareMounted(url: URL) -> Bool {
        guard let target = normalizedIdentity(for: url) else { return false }

        let keys: [URLResourceKey] = [.volumeURLForRemountingKey]
        let volumes = FileManager.default.mountedVolumeURLs(includingResourceValuesForKeys: keys, options: []) ?? []
        for v in volumes {
            guard let values = try? v.resourceValues(forKeys: Set(keys)),
                  let remount = values.volumeURLForRemounting else { continue }
            guard let candidate = normalizedIdentity(for: remount) else { continue }
            if candidate == target { return true }
        }
        return false
    }

    private func normalizedIdentity(for url: URL) -> String? {
        guard let scheme = url.scheme?.lowercased(), scheme == "smb" else { return nil }
        guard let host = url.host?.lowercased() else { return nil }

        // Ignore userinfo (username/password), compare host + normalized path only.
        let path = url.path.trimmingCharacters(in: CharacterSet(charactersIn: "/")).lowercased()
        guard !path.isEmpty else { return nil }
        return "\(host)/\(path)"
    }
}
