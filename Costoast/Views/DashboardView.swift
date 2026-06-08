//
//  DashboardView.swift
//  Costoast
//
//  Created by 池田洋平 on 2026/06/08.
//

import SwiftUI

struct DashboardView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 28) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Costoast")
                    .font(.system(size: 34, weight: .semibold, design: .rounded))

                Text("Your costs, served fresh.")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }

            EmptyDashboardView()

            Spacer(minLength: 0)
        }
        .padding(32)
        .frame(minWidth: 640, idealWidth: 800, maxWidth: .infinity, minHeight: 280, alignment: .topLeading)
    }
}

#Preview {
    DashboardView()
}
