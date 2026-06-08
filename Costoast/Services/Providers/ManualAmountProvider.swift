//
//  ManualAmountProvider.swift
//  Costoast
//
//  Created by 池田洋平 on 2026/06/08.
//

import Foundation

struct ManualAmountProvider: BillingProvider {
    let service: BillingService = .manual

    func fetchBilling(for card: BillingCard, credentials: BillingCredentials?) async throws -> BillingProviderResult {
        let period = BillingPeriodCalculator.currentMonthlyPeriod(startDay: card.billingStartDay)

        return BillingProviderResult(
            periodStart: period.start,
            periodEnd: period.end,
            nextBillingDate: period.nextBillingDate,
            originalAmount: card.amount.map { Money(value: $0, currency: card.currency) },
            amountKind: .manual,
            fetchedAt: Date(),
            dataFreshness: .manual,
            message: card.amount == nil ? "Manual amount is not set." : nil
        )
    }
}
