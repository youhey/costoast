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
}

enum BillingCardFormat {
    nonisolated static func decimal(_ decimal: Decimal) -> String {
        NSDecimalNumber(decimal: decimal).stringValue
    }
}
