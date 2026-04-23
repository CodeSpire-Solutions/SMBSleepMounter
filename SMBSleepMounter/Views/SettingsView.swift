//
//  SettingsView.swift
//  SMBSleepMounter
//
//  Created by CodeSpire-Solutions on 20.04.2026
//

import AppKit
import SwiftUI

struct SettingsView: View {
    @ObservedObject var store: ShareStore
    @ObservedObject var settings: AppSettingsStore
    let mounter: SMBMounter

    // Use `sheet(item:)` to avoid race conditions between setting the selected share and presenting.
    @State private var editingShare: SMBShare? = nil
    @State private var tab: SettingsTab = .shares

    var body: some View {
        TabView(selection: $tab) {
            sharesTab
                .tabItem { Label("Shares", systemImage: "externaldrive") }
                .tag(SettingsTab.shares)

            automationTab
                .tabItem { Label("Automation", systemImage: "gearshape.2") }
                .tag(SettingsTab.automation)

            logTab
                .tabItem { Label("Log", systemImage: "text.alignleft") }
                .tag(SettingsTab.log)

            aboutTab
                .tabItem { Label("About", systemImage: "info.circle") }
                .tag(SettingsTab.about)
        }
        .padding(16)
        .frame(minWidth: 820, minHeight: 520)
        .onAppear {
            // Make the app reachable via Cmd-Tab while Settings are open.
            NSApp.setActivationPolicy(.regular)
            NSApp.activate(ignoringOtherApps: true)
        }
        .onDisappear {
            // Return to menu-bar-only behavior when Settings close.
            NSApp.setActivationPolicy(.accessory)
        }
        .sheet(item: $editingShare) { draft in
            let isExisting = store.shares.contains(where: { $0.id == draft.id })
            ShareEditorView(
                initial: draft,
                isEditingExisting: isExisting,
                mounter: mounter,
                store: store,
                onDelete: { share in
                    if let idx = store.shares.firstIndex(where: { $0.id == share.id }) {
                        store.shares.remove(at: idx)
                        store.appendLog("Deleted share '\(share.name)'.")
                    }
                },
                onSave: { share in
                    if let existing = store.shares.firstIndex(where: { $0.id == share.id }) {
                        store.shares[existing] = share
                    } else {
                        store.shares.append(share)
                    }
                }
            )
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

    private var sharesTab: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Shares")
                    .font(.title2)
                Spacer()
                Button {
                    // Default new shares to "not enabled" to avoid credential prompts until the user
                    // has saved credentials in Keychain or explicitly tests mounting.
                    editingShare = SMBShare(name: "New Share", urlString: "smb://server/Share", enabled: false, mountOnWake: true)
                } label: {
                    Label("Add Share", systemImage: "plus")
                }
                .buttonStyle(.borderedProminent)
            }

            GroupBox {
                if store.shares.isEmpty {
                    ContentUnavailableView("No shares yet", systemImage: "externaldrive.badge.plus", description: Text("Add a share like smb://server/Share."))
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        ForEach(store.shares) { share in
                            HStack(spacing: 12) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(share.name)
                                    Text(share.urlString)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                }
                                Spacer(minLength: 0)
                                Button {
                                    Task { await mounter.mountNow(share) }
                                } label: {
                                    Image(systemName: "arrow.down.circle")
                                }
                                .buttonStyle(.borderless)
                                .help("Mount now")
                                Toggle("Enabled", isOn: binding(for: share, keyPath: \.enabled))
                                    .labelsHidden()
                                Toggle("On Wake", isOn: binding(for: share, keyPath: \.mountOnWake))
                                    .labelsHidden()
                                Button("Edit") {
                                    editingShare = share
                                }
                            }
                            .padding(.vertical, 4)
                            .contextMenu {
                                Button("Mount Now") {
                                    Task { await mounter.mountNow(share) }
                                }
                                Divider()
                                Button(role: .destructive) {
                                    if let idx = store.shares.firstIndex(where: { $0.id == share.id }) {
                                        store.shares.remove(at: idx)
                                    }
                                } label: {
                                    Text("Delete")
                                }
                            }
                        }
                        .onDelete { idx in
                            store.shares.remove(atOffsets: idx)
                        }
                    }
                }
            } label: {
                Label("Configured Shares", systemImage: "server.rack")
            }

            GroupBox {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Use URLs like `smb://server/Share` or `smb://user@server/Share`.")
                    Text("Passwords are not stored by this app. Save credentials in Finder/Keychain to avoid prompts.")
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 4)
            } label: {
                Label("Notes", systemImage: "key.fill")
            }
        }
    }

    private var automationTab: some View {
        Form {
            Section {
                Toggle("Mount on Launch", isOn: $settings.mountOnLaunch)
                Toggle("Periodic Remount", isOn: $settings.periodicRemountEnabled)
                Stepper(value: $settings.periodicMinutes, in: 1...120) {
                    Text("Interval: \(settings.periodicMinutes) minutes")
                        .monospacedDigit()
                }
                .disabled(!settings.periodicRemountEnabled)
            } header: {
                Text("Automatic Mounting")
            } footer: {
                Text("Periodic remount helps when Wi-Fi, VPN, or NAS availability changes after login.")
            }
        }
        .formStyle(.grouped)
    }

    private var logTab: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Log")
                    .font(.title2)
                Spacer()
                Button {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(store.recentLog.joined(separator: "\n"), forType: .string)
                } label: {
                    Label("Copy", systemImage: "doc.on.doc")
                }
                .buttonStyle(.bordered)
                Button(role: .destructive) {
                    store.recentLog.removeAll()
                } label: {
                    Label("Clear", systemImage: "trash")
                }
                .buttonStyle(.bordered)
            }

            TextEditor(text: .constant(store.recentLog.joined(separator: "\n")))
                .font(.system(.caption, design: .monospaced))
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(.quaternary.opacity(0.25)))
        }
    }

    private var aboutTab: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                Image(nsImage: NSApp.applicationIconImage)
                    .resizable()
                    .frame(width: 56, height: 56)
                    .cornerRadius(12)
                VStack(alignment: .leading, spacing: 2) {
                    Text("SMB Sleep Mounter")
                        .font(.title2)
                    Text(AppInfo.versionLine)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }

            GroupBox {
                VStack(alignment: .leading, spacing: 8) {
                    InfoBlock(
                        items: [
                            ("Behavior", "Mounts enabled SMB shares on launch, wake, and optionally on a schedule."),
                            ("Tip", "If you see login dialogs, mount once in Finder and save credentials in Keychain."),
                        ]
                    )
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            } label: {
                Label("Help", systemImage: "questionmark.circle")
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

private enum SettingsTab {
    case shares
    case automation
    case log
    case about
}

private enum AppInfo {
    static var versionLine: String {
        let v = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?"
        let b = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "?"
        return "Version \(v) (\(b))"
    }
}

private struct InfoBlock: View {
    let items: [(String, String)]

    private let titleWidth: CGFloat = 78

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(items.indices, id: \.self) { idx in
                    Text(items[idx].0)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: titleWidth, alignment: .leading)

            // Single continuous vertical separator line, sized to the content height.
            Divider()

            VStack(alignment: .leading, spacing: 8) {
                ForEach(items.indices, id: \.self) { idx in
                    Text(items[idx].1)
                        .font(.callout)
                        .foregroundStyle(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 2)
        .fixedSize(horizontal: false, vertical: true)
    }
}

private struct ShareEditorView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var share: SMBShare
    let isEditingExisting: Bool
    let mounter: SMBMounter
    let store: ShareStore
    let onDelete: (SMBShare) -> Void
    private let onSave: (SMBShare) -> Void

    init(
        initial: SMBShare,
        isEditingExisting: Bool,
        mounter: SMBMounter,
        store: ShareStore,
        onDelete: @escaping (SMBShare) -> Void,
        onSave: @escaping (SMBShare) -> Void
    ) {
        self._share = State(initialValue: initial)
        self.isEditingExisting = isEditingExisting
        self.mounter = mounter
        self.store = store
        self.onDelete = onDelete
        self.onSave = onSave
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Share")
                .font(.headline)

            Form {
                TextField("Name", text: $share.name)
                TextField("SMB URL", text: $share.urlString)
                Toggle("Enable Automatic Mounting", isOn: $share.enabled)
                Toggle("Mount on Wake", isOn: $share.mountOnWake)
            }

            HStack {
                Button("Test Mount") {
                    Task { await mounter.mountNow(share) }
                }
                Spacer()
                if isEditingExisting {
                    Button(role: .destructive) {
                        onDelete(share)
                        dismiss()
                    } label: {
                        Text("Delete")
                    }
                }
                Button("Cancel") { dismiss() }
                Button("Save") {
                    onSave(share)
                    store.appendLog("Saved share '\(share.name)'.")
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(14)
        .frame(width: 520)
    }
}
