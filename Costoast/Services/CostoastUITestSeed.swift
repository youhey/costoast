//
//  CostoastUITestSeed.swift
//  Costoast
//
//  Created by Codex on 2026/06/08.
//

import Foundation

enum CostoastUITestSeed {
    static func applyIfNeeded(userDefaults: UserDefaults = CostoastUserDefaults.current) {
        guard ProcessInfo.processInfo.environment["COSTOAST_UI_TEST_SEED_REORDER"] == "1" else {
            return
        }

        let now = Date(timeIntervalSince1970: 1_786_000_000)
        let cards = [
            card(
                id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
                name: "AWS",
                service: .aws,
                displayOrder: 0,
                amount: 100,
                now: now
            ),
            card(
                id: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!,
                name: "Cloudflare",
                service: .cloudflare,
                displayOrder: 1,
                amount: 200,
                now: now
            ),
            card(
                id: UUID(uuidString: "00000000-0000-0000-0000-000000000003")!,
                name: "DeepL API",
                service: .deepLApi,
                displayOrder: 2,
                amount: 300,
                now: now
            )
        ]

        let encoder = JSONEncoder()
        userDefaults.set(try? encoder.encode(cards), forKey: "billingCards")
        userDefaults.set(try? encoder.encode(DashboardPreferences(sortMode: .custom)), forKey: "dashboardPreferences")
    }

    private static func card(
        id: UUID,
        name: String,
        service: BillingService,
        displayOrder: Int,
        amount: Decimal,
        now: Date
    ) -> BillingCard {
        let money = Money(value: amount, currency: .jpy)
        return BillingCard(
            id: id,
            name: name,
            service: service,
            sourceType: .apiUsage,
            displayOrder: displayOrder,
            pinnedAt: nil,
            planName: nil,
            currency: .jpy,
            amount: amount,
            billingCycle: .monthly,
            billingStartDay: nil,
            gcpConfiguration: nil,
            azureConfiguration: nil,
            cloudflareConfiguration: nil,
            laravelCloudConfiguration: nil,
            openAICodexConfiguration: nil,
            deepLAPIConfiguration: nil,
            lastBillingResult: BillingProviderResult(
                periodStart: nil,
                periodEnd: nil,
                nextBillingDate: nil,
                originalAmount: money,
                amountKind: .manual,
                fetchedAt: now,
                dataFreshness: .manual,
                message: nil
            ),
            lastRefreshError: nil,
            lastConvertedAmount: ConvertedAmount(
                original: money,
                jpyAmount: amount,
                rate: 1,
                rateFetchedAt: now,
                sourceName: "UI Test",
                isEstimated: false
            ),
            lastConversionError: nil,
            createdAt: now.addingTimeInterval(TimeInterval(displayOrder)),
            updatedAt: now.addingTimeInterval(TimeInterval(displayOrder))
        )
    }
}
