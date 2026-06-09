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

enum AutoRefreshInterval: String, Codable, CaseIterable, Identifiable {
    case off
    case fiveMinutes
    case thirtyMinutes
    case oneHour
    case twoHours
    case sixHours

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .off:
            "No"
        case .fiveMinutes:
            "5 m"
        case .thirtyMinutes:
            "30 m"
        case .oneHour:
            "1 h"
        case .twoHours:
            "2 h"
        case .sixHours:
            "6 h"
        }
    }

    var seconds: TimeInterval? {
        switch self {
        case .off:
            nil
        case .fiveMinutes:
            5 * 60
        case .thirtyMinutes:
            30 * 60
        case .oneHour:
            60 * 60
        case .twoHours:
            2 * 60 * 60
        case .sixHours:
            6 * 60 * 60
        }
    }
}

struct DashboardPreferences: Codable, Equatable {
    var sortMode: CardSortMode = .custom
    var viewMode: DashboardViewMode = .cards
    var autoRefreshInterval: AutoRefreshInterval = .off

    init(
        sortMode: CardSortMode = .custom,
        viewMode: DashboardViewMode = .cards,
        autoRefreshInterval: AutoRefreshInterval = .off
    ) {
        self.sortMode = sortMode
        self.viewMode = viewMode
        self.autoRefreshInterval = autoRefreshInterval
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        sortMode = try container.decodeIfPresent(CardSortMode.self, forKey: .sortMode) ?? .custom
        viewMode = try container.decodeIfPresent(DashboardViewMode.self, forKey: .viewMode) ?? .cards
        autoRefreshInterval = try container.decodeIfPresent(AutoRefreshInterval.self, forKey: .autoRefreshInterval) ?? .off
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
