//
//  MenuBarView.swift
//  SMBSleepMounter
//
//  Created by CodeSpire-Solutions on 20.04.2026
//

import AppKit
import ServiceManagement
import SwiftUI

struct MenuBarView: View {
    @ObservedObject var store: ShareStore
    @ObservedObject var settings: AppSettingsStore
    @ObservedObject var loginItem: LoginItemManager
    let mounter: SMBMounter

    // Keep the menu simple and "macOS-native": mostly menus, toggles, dividers.
    var body: some View {
        SettingsLink {
            Label("Settings…", systemImage: "gear")
        }
        .simultaneousGesture(TapGesture().onEnded {
            // Ensure the app is reachable via Cmd-Tab while Settings are open.
            NSApp.setActivationPolicy(.regular)
            NSApp.activate(ignoringOtherApps: true)
        })

        Divider()

        Button("Mount All Enabled Shares") {
            Task {
                store.appendLog("Manual: mount all requested.")
                for share in store.shares where share.enabled {
                    await mounter.mountNow(share)
                }
            }
        }
        .disabled(store.shares.filter { $0.enabled }.isEmpty)

        Menu("Shares") {
            if store.shares.isEmpty {
                Text("No shares configured.")
            } else {
                ForEach(store.shares) { share in
                    Menu(share.name) {
                        Button("Mount Now") {
                            Task { await mounter.mountNow(share) }
                        }

                        Divider()

                        Toggle("Enable Automatic Mounting", isOn: binding(for: share, keyPath: \.enabled))
                        Toggle("Mount on Wake", isOn: binding(for: share, keyPath: \.mountOnWake))

                        Divider()

                        Button("Remove Share", role: .destructive) {
                            if let idx = store.shares.firstIndex(where: { $0.id == share.id }) {
                                store.shares.remove(at: idx)
                                store.appendLog("Deleted share '\(share.name)'.")
                            }
                        }
                    }
                }
            }
        }

        Divider()

        Toggle("Launch at Login", isOn: Binding(
            get: { loginItem.isEnabled },
            set: { loginItem.setEnabled($0) }
        ))
        .onAppear { loginItem.refresh() }

        Text("Login Item: \(loginItem.statusLabel)")
            .font(.caption)
            .foregroundStyle(.secondary)

        if let err = loginItem.lastError {
            Text(err)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }

        Divider()

        Toggle("Mount on Launch", isOn: $settings.mountOnLaunch)
        Toggle("Periodic Remount", isOn: $settings.periodicRemountEnabled)

        Picker("Interval", selection: $settings.periodicMinutes) {
            Text("1 min").tag(1)
            Text("2 min").tag(2)
            Text("5 min").tag(5)
            Text("10 min").tag(10)
            Text("15 min").tag(15)
            Text("30 min").tag(30)
            Text("60 min").tag(60)
            Text("120 min").tag(120)
        }
        .disabled(!settings.periodicRemountEnabled)

        Divider()

        Menu("Recent Log") {
            let last = store.recentLog.suffix(12)
            if last.isEmpty {
                Text("No log entries yet.")
            } else {
                ForEach(Array(last), id: \.self) { line in
                    Text(line)
                }
            }
        }

        Divider()

        Button("Quit App", role: .destructive) {
            NSApp.terminate(nil)
        }
    }

    private func binding(for share: SMBShare, keyPath: WritableKeyPath<SMBShare, Bool>) -> Binding<Bool> {
        Binding(
            get: {
                store.shares.first(where: { $0.id == share.id })?[keyPath: keyPath] ?? false
            },
            set: { newValue in
                guard let idx = store.shares.firstIndex(where: { $0.id == share.id }) else { return }
                store.shares[idx][keyPath: keyPath] = newValue
            }
        )
    }

}

private extension LoginItemManager {
    var statusLabel: String {
        switch status {
        case .notRegistered: return "Not registered"
        case .enabled: return "Enabled"
        case .requiresApproval: return "Requires approval"
        case .notFound: return "Not found"
        @unknown default: return "Unknown"
        }
    }
}
