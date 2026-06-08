//
//  BillingProviderRegistry.swift
//  Costoast
//
//  Created by 池田洋平 on 2026/06/08.
//

import Foundation

final class BillingProviderRegistry {
    private let manualAmountProvider = ManualAmountProvider()
    private let subscriptionPlanProvider = SubscriptionPlanProvider()
    private let openAIProvider = OpenAIAPIUsageProvider()
    private let awsProvider = AWSBillingProvider()
    private let unsupportedProvider = UnsupportedBillingProvider()

    func provider(for card: BillingCard) -> BillingProvider {
        switch card.sourceType {
        case .manualAmount:
            manualAmountProvider
        case .subscriptionPlan:
            subscriptionPlanProvider
        case .apiUsage:
            switch card.service {
            case .openAiApi:
                openAIProvider
            case .aws:
                awsProvider
            default:
                unsupportedProvider
            }
        }
    }
}

private struct UnsupportedBillingProvider: BillingProvider {
    let service: BillingService = .manual

    func fetchBilling(for card: BillingCard, credentials: BillingCredentials?) async throws -> BillingProviderResult {
        throw BillingProviderError.unsupportedProvider
    }
}
