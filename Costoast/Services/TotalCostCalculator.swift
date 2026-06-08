//
//  TotalCostCalculator.swift
//  Costoast
//
//  Created by 池田洋平 on 2026/06/08.
//

import Foundation

struct TotalCostSummary: Equatable {
    var totalJPY: Decimal
    var activeCardCount: Int
    var includedCardCount: Int
    var excludedCardCount: Int
    var rateFetchedAt: Date?
    var sourceName: String?
    var hasConversionErrors: Bool
}

final class TotalCostCalculator {
    func summarize(cards: [BillingCard]) -> TotalCostSummary {
        let convertedAmounts = cards.compactMap(\.currentConvertedAmount)
        let total = convertedAmounts.reduce(Decimal.zero) { partialResult, convertedAmount in
            partialResult + convertedAmount.jpyAmount
        }
        let latestRate = convertedAmounts.max { lhs, rhs in
            lhs.rateFetchedAt < rhs.rateFetchedAt
        }

        return TotalCostSummary(
            totalJPY: total,
            activeCardCount: cards.count,
            includedCardCount: convertedAmounts.count,
            excludedCardCount: cards.count - convertedAmounts.count,
            rateFetchedAt: latestRate?.rateFetchedAt,
            sourceName: latestRate?.sourceName,
            hasConversionErrors: cards.contains { $0.lastConversionError != nil }
        )
    }
}
