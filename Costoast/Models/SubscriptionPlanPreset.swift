//
//  SubscriptionPlanPreset.swift
//  Costoast
//
//  Created by Codex on 2026/06/08.
//

import Foundation

struct SubscriptionPlanPreset: Identifiable, Codable, Equatable {
    var id: String
    var service: BillingService
    var name: String
    var currency: CurrencyCode
    var amount: Decimal?
    var billingCycle: BillingCycle
    var isAmountEditable: Bool
}

enum SubscriptionPlanPresetCatalog {
    static func presets(for service: BillingService?) -> [SubscriptionPlanPreset] {
        guard let service else {
            return []
        }

        return presetsByService[service] ?? []
    }

    private static let presetsByService: [BillingService: [SubscriptionPlanPreset]] = [
        .openAiChatGpt: [
            preset(.openAiChatGpt, "Free", .usd, .monthly),
            preset(.openAiChatGpt, "Plus", .usd, .monthly),
            preset(.openAiChatGpt, "Pro", .usd, .monthly),
            preset(.openAiChatGpt, "Team", .usd, .monthly),
            preset(.openAiChatGpt, "Custom", .usd, .custom)
        ],
        .youtube: [
            preset(.youtube, "Individual", .jpy, .monthly),
            preset(.youtube, "Family", .jpy, .monthly),
            preset(.youtube, "Student", .jpy, .monthly),
            preset(.youtube, "Custom", .jpy, .custom)
        ],
        .netflix: [
            preset(.netflix, "Standard with ads", .jpy, .monthly),
            preset(.netflix, "Standard", .jpy, .monthly),
            preset(.netflix, "Premium", .jpy, .monthly),
            preset(.netflix, "Custom", .jpy, .custom)
        ],
        .appleTvPlus: [
            preset(.appleTvPlus, "Monthly", .jpy, .monthly),
            preset(.appleTvPlus, "Annual", .jpy, .yearly),
            preset(.appleTvPlus, "Apple One", .jpy, .monthly),
            preset(.appleTvPlus, "Custom", .jpy, .custom)
        ],
        .amazon: [
            preset(.amazon, "Monthly", .jpy, .monthly),
            preset(.amazon, "Annual", .jpy, .yearly),
            preset(.amazon, "Student", .jpy, .monthly),
            preset(.amazon, "Custom", .jpy, .custom)
        ],
        .niconicoPremium: [
            preset(.niconicoPremium, "Monthly", .jpy, .monthly),
            preset(.niconicoPremium, "Custom", .jpy, .custom)
        ],
        .abema: [
            preset(.abema, "ABEMA Premium", .jpy, .monthly),
            preset(.abema, "Custom", .jpy, .custom)
        ],
        .dAnimeStore: [
            preset(.dAnimeStore, "Monthly", .jpy, .monthly),
            preset(.dAnimeStore, "Custom", .jpy, .custom)
        ],
        .dmmTv: [
            preset(.dmmTv, "Monthly", .jpy, .monthly),
            preset(.dmmTv, "Custom", .jpy, .custom)
        ],
        .uNext: [
            preset(.uNext, "Monthly", .jpy, .monthly),
            preset(.uNext, "Custom", .jpy, .custom)
        ]
    ]

    private static func preset(
        _ service: BillingService,
        _ name: String,
        _ currency: CurrencyCode,
        _ billingCycle: BillingCycle
    ) -> SubscriptionPlanPreset {
        SubscriptionPlanPreset(
            id: "\(service.rawValue)-\(name.lowercased().replacingOccurrences(of: " ", with: "-"))",
            service: service,
            name: name,
            currency: currency,
            amount: nil,
            billingCycle: billingCycle,
            isAmountEditable: true
        )
    }
}
