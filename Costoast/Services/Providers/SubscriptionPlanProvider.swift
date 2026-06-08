//
//  SubscriptionPlanProvider.swift
//  Costoast
//
//  Created by 池田洋平 on 2026/06/08.
//

import Foundation

struct SubscriptionPlanProvider: BillingProvider {
    let service: BillingService = .manual

    func fetchBilling(for card: BillingCard, credentials: BillingCredentials?) async throws -> BillingProviderResult {
        let period: BillingPeriod
        switch card.billingCycle {
        case .monthly:
            period = BillingPeriodCalculator.currentMonthlyPeriod(startDay: card.billingStartDay)
        case .yearly:
            period = BillingPeriodCalculator.currentYearlyPeriod(startDay: card.billingStartDay)
        case .custom:
            period = BillingPeriod(start: nil, end: nil, nextBillingDate: nil)
        }

        return BillingProviderResult(
            periodStart: period.start,
            periodEnd: period.end,
            nextBillingDate: period.nextBillingDate,
            originalAmount: card.amount.map { Money(value: $0, currency: card.currency) },
            amountKind: .subscription,
            fetchedAt: Date(),
            dataFreshness: .manual,
            message: card.planName
        )
    }
}
