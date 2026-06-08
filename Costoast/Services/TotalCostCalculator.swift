//
//  TotalCostCalculator.swift
//  Costoast
//
//  Created by 池田洋平 on 2026/06/08.
//

import Foundation

struct TotalCostSummary: Equatable {
    var totalJPY: Decimal
    var groupTotalsJPY: [BillingServiceGroup: Decimal]
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
            partialResult + convertedCard.card.billingCycle.monthlyEquivalentMultiplier * convertedCard.convertedAmount.jpyAmount
        }
        let groupTotals = convertedCards.reduce(into: [BillingServiceGroup: Decimal]()) { partialResult, convertedCard in
            guard convertedCard.card.service != .manual,
                  let group = convertedCard.card.service.serviceGroup else {
                return
            }

            let monthlyAmount = convertedCard.card.billingCycle.monthlyEquivalentMultiplier * convertedCard.convertedAmount.jpyAmount
            partialResult[group, default: .zero] += monthlyAmount
        }
        let latestRate = convertedCards.map(\.convertedAmount).max { lhs, rhs in
            lhs.rateFetchedAt < rhs.rateFetchedAt
        }

        return TotalCostSummary(
            totalJPY: total,
            groupTotalsJPY: groupTotals,
            activeCardCount: cards.count,
            includedCardCount: convertedCards.count,
            excludedCardCount: cards.count - convertedCards.count,
            rateFetchedAt: latestRate?.rateFetchedAt,
            sourceName: latestRate?.sourceName,
            hasConversionErrors: cards.contains { $0.lastConversionError != nil }
        )
    }
}

extension BillingService {
    var serviceGroup: BillingServiceGroup? {
        BillingServiceGroup.allCases.first { group in
            group.services.contains(self)
        }
    }
}
