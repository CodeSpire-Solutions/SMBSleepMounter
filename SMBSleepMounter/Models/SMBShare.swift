//
//  SMBShare.swift
//  SMBSleepMounter
//
//  Created by CodeSpire-Solutions on 20.04.2026
//

import Foundation

struct SMBShare: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var name: String
    var urlString: String
    var enabled: Bool = true
    var mountOnWake: Bool = true

    var url: URL? { URL(string: urlString) }
}

