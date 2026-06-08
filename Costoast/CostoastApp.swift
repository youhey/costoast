//
//  CostoastApp.swift
//  Costoast
//
//  Created by 池田洋平 on 2026/06/08.
//

import SwiftUI

@main
struct CostoastApp: App {
    init() {
#if DEBUG
        CostoastUserDefaults.resetUITestSuiteIfNeeded()
        CostoastUITestSeed.applyIfNeeded(userDefaults: CostoastUserDefaults.current)
#endif
    }

    var body: some Scene {
        WindowGroup {
            DashboardView()
        }
        .defaultSize(width: 800, height: 360)
    }
}
