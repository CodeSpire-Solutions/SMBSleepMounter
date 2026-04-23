//
//  AppDelegate.swift
//  SMBSleepMounter
//
//  Created by CodeSpire-Solutions on 20.04.2026
//

import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Default: menu bar app without a Dock icon.
        // When the Settings window opens, we temporarily switch to `.regular` so the user
        // can Cmd-Tab back to it, then revert on close (see SettingsView).
        NSApp.setActivationPolicy(.accessory)
    }
}
