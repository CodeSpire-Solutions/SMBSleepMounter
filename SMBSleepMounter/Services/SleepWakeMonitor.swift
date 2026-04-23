//
//  SleepWakeMonitor.swift
//  SMBSleepMounter
//
//  Created by CodeSpire-Solutions on 20.04.2026
//

import AppKit
import Foundation

final class SleepWakeMonitor {
    enum Event {
        case willSleep
        case didWake
    }

    private var observers: [NSObjectProtocol] = []
    private let onEvent: (Event) -> Void

    init(onEvent: @escaping (Event) -> Void) {
        self.onEvent = onEvent

        let nc = NSWorkspace.shared.notificationCenter
        observers.append(nc.addObserver(forName: NSWorkspace.willSleepNotification, object: nil, queue: .main) { [weak self] _ in
            self?.onEvent(.willSleep)
        })
        observers.append(nc.addObserver(forName: NSWorkspace.didWakeNotification, object: nil, queue: .main) { [weak self] _ in
            self?.onEvent(.didWake)
        })
    }

    deinit {
        let nc = NSWorkspace.shared.notificationCenter
        for o in observers {
            nc.removeObserver(o)
        }
    }
}

