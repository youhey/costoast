//
//  DashboardPreferences.swift
//  Costoast
//
//  Created by Codex on 2026/06/08.
//

import Foundation

enum CardSortMode: String, Codable, CaseIterable, Identifiable {
    case custom
    case nameAsc
    case serviceGroup
    case amountDesc
    case amountAsc

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .custom:
            "Custom Order"
        case .nameAsc:
            "Name"
        case .serviceGroup:
            "Group"
        case .amountDesc:
            "Amount ↓"
        case .amountAsc:
            "Amount ↑"
        }
    }
}

struct DashboardPreferences: Codable, Equatable {
    var sortMode: CardSortMode = .custom
}

enum DashboardPreferencesStore {
    private static let storageKey = "dashboardPreferences"

    static func load(userDefaults: UserDefaults = .standard) -> DashboardPreferences {
        guard let data = userDefaults.data(forKey: storageKey) else {
            return DashboardPreferences()
        }

        return (try? JSONDecoder().decode(DashboardPreferences.self, from: data)) ?? DashboardPreferences()
    }

    static func save(_ preferences: DashboardPreferences, userDefaults: UserDefaults = .standard) {
        guard let data = try? JSONEncoder().encode(preferences) else {
            return
        }

        userDefaults.set(data, forKey: storageKey)
    }
}
