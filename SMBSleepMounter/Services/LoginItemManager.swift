//
//  LoginItemManager.swift
//  SMBSleepMounter
//
//  Created by CodeSpire-Solutions on 20.04.2026
//

import Combine
import Foundation
import ServiceManagement

@MainActor
final class LoginItemManager: ObservableObject {
    @Published private(set) var isEnabled: Bool = false
    @Published private(set) var status: SMAppService.Status = .notRegistered
    @Published private(set) var lastError: String? = nil

    init() {
        refresh()
    }

    func refresh() {
        let st = SMAppService.mainApp.status
        status = st
        isEnabled = (st == .enabled)
    }

    func setEnabled(_ enabled: Bool) {
        lastError = nil
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            lastError = error.localizedDescription
        }
        refresh()
    }

    func openLoginItemsSettings() {
        if #available(macOS 13.0, *) {
            SMAppService.openSystemSettingsLoginItems()
        }
    }
}
