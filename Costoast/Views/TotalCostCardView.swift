//
//  TotalCostCardView.swift
//  Costoast
//
//  Created by 池田洋平 on 2026/06/08.
//

import SwiftUI

struct TotalCostCardView: View {
    let summary: TotalCostSummary

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Total")
                .font(.headline)

            Text("\(BillingCardFormat.jpy(summary.totalJPY)) estimated")
                .font(.title2)
                .fontWeight(.semibold)

            VStack(alignment: .leading, spacing: 6) {
                if summary.activeCardCount == 0 {
                    Text("No billing cards yet.")
                } else if summary.excludedCardCount == 0 {
                    Text("Based on \(summary.activeCardCount) active \(cardLabel(summary.activeCardCount))")
                } else {
                    Text("Based on \(summary.includedCardCount) of \(summary.activeCardCount) active \(cardLabel(summary.activeCardCount))")
                    Text("\(summary.excludedCardCount) \(cardLabel(summary.excludedCardCount)) excluded from total")
                        .foregroundStyle(.secondary)
                }

                if let rateFetchedAt = summary.rateFetchedAt {
                    Text("FX updated: \(BillingCardFormat.jstDateTime(rateFetchedAt))")
                        .foregroundStyle(.secondary)
                } else if summary.hasConversionErrors {
                    Text("FX rate unavailable")
                        .foregroundStyle(.secondary)
                    Text("Showing original amounts only.")
                        .foregroundStyle(.secondary)
                }
            }
            .font(.body)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(24)
        .background(.background, in: RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(.quaternary, lineWidth: 1)
        }
    }

    private func cardLabel(_ count: Int) -> String {
        count == 1 ? "card" : "cards"
    }
}

#Preview {
    TotalCostCardView(
        summary: TotalCostSummary(
            totalJPY: 18420,
            activeCardCount: 4,
            includedCardCount: 3,
            excludedCardCount: 1,
            rateFetchedAt: Date(),
            sourceName: "Frankfurter",
            hasConversionErrors: false
        )
    )
    .padding()
    .frame(width: 800)
}
