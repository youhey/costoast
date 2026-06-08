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

enum DashboardViewMode: String, Codable, CaseIterable, Identifiable {
    case cards
    case compact

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .cards:
            "Cards"
        case .compact:
            "Compact"
        }
    }
}

struct DashboardPreferences: Codable, Equatable {
    var sortMode: CardSortMode = .custom
    var viewMode: DashboardViewMode = .cards

    init(sortMode: CardSortMode = .custom, viewMode: DashboardViewMode = .cards) {
        self.sortMode = sortMode
        self.viewMode = viewMode
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        sortMode = try container.decodeIfPresent(CardSortMode.self, forKey: .sortMode) ?? .custom
        viewMode = try container.decodeIfPresent(DashboardViewMode.self, forKey: .viewMode) ?? .cards
    }
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
