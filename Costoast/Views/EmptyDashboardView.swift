//
//  EmptyDashboardView.swift
//  Costoast
//
//  Created by 池田洋平 on 2026/06/08.
//

import SwiftUI

struct EmptyDashboardView: View {
    var onAdd: () -> Void

    var body: some View {
        AddBillingCardView(subtitle: "Add your first billing card.") {
            onAdd()
        }
    }
}

#Preview {
    EmptyDashboardView {}
        .padding()
        .frame(width: 800)
}
