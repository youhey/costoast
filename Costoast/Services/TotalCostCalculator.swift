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
        let convertedCards = cards.compactMap { card -> (card: BillingCard, convertedAmount: ConvertedAmount)? in
            guard let convertedAmount = card.currentConvertedAmount else {
                return nil
            }

            return (card, convertedAmount)
        }
        let total = convertedCards.reduce(Decimal.zero) { partialResult, convertedCard in
            partialResult + convertedCard.card.billingCycle.monthlyTotalMultiplier * convertedCard.convertedAmount.jpyAmount
        }
        let latestRate = convertedCards.map(\.convertedAmount).max { lhs, rhs in
            lhs.rateFetchedAt < rhs.rateFetchedAt
        }

        return TotalCostSummary(
            totalJPY: total,
            activeCardCount: cards.count,
            includedCardCount: convertedCards.count,
            excludedCardCount: cards.count - convertedCards.count,
            rateFetchedAt: latestRate?.rateFetchedAt,
            sourceName: latestRate?.sourceName,
            hasConversionErrors: cards.contains { $0.lastConversionError != nil }
        )
    }
}

private extension BillingCycle {
    var monthlyTotalMultiplier: Decimal {
        switch self {
        case .monthly:
            1
        case .yearly:
            Decimal(1) / Decimal(12)
        case .custom:
            1
        }
    }
}
