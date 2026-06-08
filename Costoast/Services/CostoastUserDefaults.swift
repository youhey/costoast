//
//  CostoastUserDefaults.swift
//  Costoast
//
//  Created by Codex on 2026/06/08.
//

import Foundation

enum CostoastUserDefaults {
#if DEBUG
    private static let uiTestSuiteName = "youhey.Costoast.UITests"
#endif

    static var current: UserDefaults {
#if DEBUG
        if ProcessInfo.processInfo.environment["COSTOAST_UI_TEST_SEED_REORDER"] == "1" {
            return UserDefaults(suiteName: uiTestSuiteName) ?? .standard
        }
#endif

        return .standard
    }

#if DEBUG
    static func resetUITestSuiteIfNeeded() {
        guard ProcessInfo.processInfo.environment["COSTOAST_UI_TEST_SEED_REORDER"] == "1" else {
            return
        }

        UserDefaults.standard.removePersistentDomain(forName: uiTestSuiteName)
    }
#endif
}
