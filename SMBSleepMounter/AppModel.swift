//
//  AppModel.swift
//  SMBSleepMounter
//
//  Created by CodeSpire-Solutions on 20.04.2026
//  Seriously this was my first project in Swift, it's quite complicated to learn.
//

import Combine
import Foundation

@MainActor
final class AppModel: ObservableObject {
    let store: ShareStore
    let settings: AppSettingsStore
    let loginItem: LoginItemManager
    let mounter: SMBMounter
    private let sleepWakeMonitor: SleepWakeMonitor
    private var periodicTimer: Timer?
    private var cancellables: Set<AnyCancellable> = []

    init() {
        let store = ShareStore()
        let mounter = SMBMounter(store: store)
        let settings = AppSettingsStore()
        self.store = store
        self.settings = settings
        self.loginItem = LoginItemManager()
        self.mounter = mounter

        // Keep a strong reference to the monitor so it stays active while the app runs.
        // Important: don't capture `self` here; `self` isn't fully initialized until
        // `sleepWakeMonitor` is assigned.
        self.sleepWakeMonitor = SleepWakeMonitor { event in
            switch event {
            case .didWake:
                Task { await mounter.mountEligibleShares(reason: "Wake") }
            case .willSleep:
                store.appendLog("Sleep detected.")
            }
        }

        // Automatic behavior:
        // - mount on launch (after a short delay to let the user session/network settle)
        // - remount periodically (helps with VPN / flaky Wi-Fi / NAS reboots)
        if settings.mountOnLaunch {
            let launchSnapshot = store.shares.filter { $0.enabled && $0.mountOnWake }
            Task {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                await mounter.mountShares(launchSnapshot, reason: "Launch")
            }
        }

        settings.$periodicRemountEnabled
            .combineLatest(settings.$periodicMinutes)
            .sink { [weak self] _, _ in
                self?.restartPeriodicTimer()
            }
            .store(in: &cancellables)

        restartPeriodicTimer()
    }

    private func restartPeriodicTimer() {
        periodicTimer?.invalidate()
        periodicTimer = nil

        guard settings.periodicRemountEnabled else { return }
        let minutes = max(1, min(120, settings.periodicMinutes))
        let interval = TimeInterval(minutes * 60)

        // Timer runs on the main run loop; mount work is async.
        periodicTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [store, mounter] _ in
            store.appendLog("Periodic: checking/mounting enabled shares.")
            Task { await mounter.mountEligibleShares(reason: "Periodic") }
        }
    }
}
