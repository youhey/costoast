//
//  CostoastApp.swift
//  Costoast
//
//  Created by 池田洋平 on 2026/06/08.
//

import SwiftUI

@main
struct CostoastApp: App {
    var body: some Scene {
        WindowGroup {
            DashboardView()
        }
        .defaultSize(width: 800, height: 360)
    }
}
