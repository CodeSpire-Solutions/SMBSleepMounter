//
//  ShareStore.swift
//  SMBSleepMounter
//
//  Created by CodeSpire-Solutions on 20.04.2026
//

import Combine
import Foundation

@MainActor
final class ShareStore: ObservableObject {
    @Published var shares: [SMBShare] = [] {
        didSet { persistShares() }
    }

    @Published var recentLog: [String] = [] {
        didSet {
            // Keep memory bounded.
            if recentLog.count > 200 {
                recentLog = Array(recentLog.suffix(200))
            }
        }
    }

    private let sharesKey = "shares_json_v1"

    init() {
        loadShares()
        appendLog("App started.")
    }

    func appendLog(_ message: String) {
        let df = DateFormatter()
        df.locale = Locale(identifier: "en_US_POSIX")
        df.dateFormat = "yyyy-MM-dd HH:mm:ss"
        recentLog.append("[\(df.string(from: Date()))] \(message)")
    }

    private func loadShares() {
        guard let data = UserDefaults.standard.data(forKey: sharesKey) else {
            shares = []
            return
        }
        do {
            shares = try JSONDecoder().decode([SMBShare].self, from: data)
        } catch {
            shares = []
            appendLog("Failed to load shares: \(error.localizedDescription)")
        }
    }

    private func persistShares() {
        do {
            let data = try JSONEncoder().encode(shares)
            UserDefaults.standard.set(data, forKey: sharesKey)
        } catch {
            appendLog("Failed to save shares: \(error.localizedDescription)")
        }
    }
}
