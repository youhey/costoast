//
//  EmptyDashboardView.swift
//  Costoast
//
//  Created by 池田洋平 on 2026/06/08.
//

import SwiftUI

struct EmptyDashboardView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("No billing cards yet.")
                .font(.headline)

            Text("Cards will be added in the next phase.")
                .font(.body)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(24)
        .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 8))
    }
}

#Preview {
    EmptyDashboardView()
        .padding()
        .frame(width: 800)
}
