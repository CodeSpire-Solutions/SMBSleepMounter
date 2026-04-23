//
//  AppSettingsStore.swift
//  SMBSleepMounter
//
//  Created by CodeSpire-Solutions on 20.04.2026
//

import Combine
import Foundation

@MainActor
final class AppSettingsStore: ObservableObject {
    @Published var mountOnLaunch: Bool = true { didSet { persistIfReady() } }
    @Published var periodicRemountEnabled: Bool = true { didSet { persistIfReady() } }
    @Published var periodicMinutes: Int = 5 { didSet { persistIfReady() } }

    // Prevent didSet from overwriting previously stored values while we're still loading them.
    private var isInitializing: Bool = true

    private struct Keys {
        static let mountOnLaunch = "settings_mount_on_launch_v1"
        static let periodicEnabled = "settings_periodic_enabled_v1"
        static let periodicMinutes = "settings_periodic_minutes_v1"
    }

    init() {
        let d = UserDefaults.standard
        if d.object(forKey: Keys.mountOnLaunch) != nil {
            mountOnLaunch = d.bool(forKey: Keys.mountOnLaunch)
        }
        if d.object(forKey: Keys.periodicEnabled) != nil {
            periodicRemountEnabled = d.bool(forKey: Keys.periodicEnabled)
        }
        if d.object(forKey: Keys.periodicMinutes) != nil {
            periodicMinutes = d.integer(forKey: Keys.periodicMinutes)
        }

        // Basic sanity bounds.
        if periodicMinutes < 1 { periodicMinutes = 1 }
        if periodicMinutes > 120 { periodicMinutes = 120 }

        isInitializing = false
        persist()
    }

    private func persistIfReady() {
        guard !isInitializing else { return }
        persist()
    }

    private func persist() {
        let d = UserDefaults.standard
        d.set(mountOnLaunch, forKey: Keys.mountOnLaunch)
        d.set(periodicRemountEnabled, forKey: Keys.periodicEnabled)
        d.set(periodicMinutes, forKey: Keys.periodicMinutes)
    }
}
