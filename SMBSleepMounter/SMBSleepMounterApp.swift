//
//  SMBSleepMounterApp.swift
//  SMBSleepMounter
//
//  Created by CodeSpire-Solutions on 20.04.2026
//

import SwiftUI

@main
struct SMBSleepMounterApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var model = AppModel()
    @AppStorage("menu_bar_extra_inserted_v1") private var isMenuBarExtraInserted: Bool = true

    var body: some Scene {
        // Menu bar agent-style app. Settings are available via the menu item.
        MenuBarExtra("SMB Sleep Mounter", systemImage: "externaldrive", isInserted: $isMenuBarExtraInserted) {
            MenuBarView(store: model.store, settings: model.settings, loginItem: model.loginItem, mounter: model.mounter)
        }
        .menuBarExtraStyle(.menu)

        Settings {
            SettingsView(store: model.store, settings: model.settings, mounter: model.mounter)
        }
    }
}
