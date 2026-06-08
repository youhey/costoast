//
//  BillingCard.swift
//  Costoast
//
//  Created by 池田洋平 on 2026/06/08.
//

import Foundation

struct BillingCard: Identifiable, Codable, Equatable {
    var id: UUID
    var name: String
    var service: BillingService
    var sourceType: BillingSourceType
    var displayOrder: Int

    var planName: String?
    var currency: CurrencyCode
    var amount: Decimal?
    var billingCycle: BillingCycle
    var billingStartDay: Int?

    var lastBillingResult: BillingProviderResult?
    var lastRefreshError: String?

    var createdAt: Date
    var updatedAt: Date
}

enum BillingService: String, Codable, CaseIterable, Identifiable {
    case aws
    case gcp
    case azure
    case cloudflare
    case laravelCloud
    case openAiChatGpt
    case openAiCodex
    case openAiApi
    case claude
    case claudeCode
    case deepl
    case youtube
    case amazon
    case yodobashi
    case yahooShopping
    case mercari
    case manual

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .aws:
            "AWS"
        case .gcp:
            "GCP"
        case .azure:
            "Azure"
        case .cloudflare:
            "Cloudflare"
        case .laravelCloud:
            "Laravel Cloud"
        case .openAiChatGpt:
            "OpenAI ChatGPT"
        case .openAiCodex:
            "OpenAI Codex"
        case .openAiApi:
            "OpenAI API"
        case .claude:
            "Claude"
        case .claudeCode:
            "Claude Code"
        case .deepl:
            "DeepL"
        case .youtube:
            "YouTube"
        case .amazon:
            "Amazon"
        case .yodobashi:
            "Yodobashi"
        case .yahooShopping:
            "Yahoo Shopping"
        case .mercari:
            "Mercari"
        case .manual:
            "Manual"
        }
    }
}

enum BillingSourceType: String, Codable, CaseIterable, Identifiable {
    case apiUsage
    case subscriptionPlan
    case manualAmount

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .apiUsage:
            "API Usage"
        case .subscriptionPlan:
            "Subscription Plan"
        case .manualAmount:
            "Manual Amount"
        }
    }
}

enum BillingCycle: String, Codable, CaseIterable, Identifiable {
    case monthly
    case yearly
    case custom

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .monthly:
            "Monthly"
        case .yearly:
            "Yearly"
        case .custom:
            "Custom"
        }
    }
}

enum CurrencyCode: String, Codable, CaseIterable, Identifiable {
    case jpy = "JPY"
    case usd = "USD"
    case eur = "EUR"

    var id: String { rawValue }

    nonisolated init?(externalValue: String) {
        self.init(rawValue: externalValue.uppercased())
    }
}

enum BillingCardFormat {
    nonisolated static func decimal(_ decimal: Decimal) -> String {
        NSDecimalNumber(decimal: decimal).stringValue
    }
}

struct Money: Codable, Equatable {
    var value: Decimal
    var currency: CurrencyCode
}

struct BillingProviderResult: Codable, Equatable {
    var periodStart: Date?
    var periodEnd: Date?
    var nextBillingDate: Date?

    var originalAmount: Money?
    var amountKind: BillingAmountKind

    var fetchedAt: Date
    var dataFreshness: BillingDataFreshness
    var message: String?
}

enum BillingAmountKind: String, Codable {
    case estimated
    case finalized
    case subscription
    case manual
    case usageToDate
    case unavailable
}

enum BillingDataFreshness: String, Codable {
    case realtime
    case hourly
    case daily
    case delayed
    case manual
    case unknown
}
