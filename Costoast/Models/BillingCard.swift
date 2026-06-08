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

    var gcpConfiguration: GCPBillingConfiguration?
    var azureConfiguration: AzureBillingConfiguration?
    var cloudflareConfiguration: CloudflareBillingConfiguration?
    var laravelCloudConfiguration: LaravelCloudBillingConfiguration?
    var openAICodexConfiguration: OpenAICodexBillingConfiguration?
    var deepLAPIConfiguration: DeepLAPIBillingConfiguration?

    var lastBillingResult: BillingProviderResult?
    var lastRefreshError: String?
    var lastConvertedAmount: ConvertedAmount?
    var lastConversionError: String?

    var createdAt: Date
    var updatedAt: Date
}

struct GCPBillingConfiguration: Codable, Equatable {
    var projectID: String
    var datasetID: String
    var tableName: String
    var billingAccountID: String?
}

struct AzureBillingConfiguration: Codable, Equatable {
    var tenantID: String
    var clientID: String
    var subscriptionID: String?
    var scope: String?
}

struct CloudflareBillingConfiguration: Codable, Equatable {
    var accountID: String
}

struct LaravelCloudBillingConfiguration: Codable, Equatable {
    var organizationID: String?
}

struct OpenAICodexBillingConfiguration: Codable, Equatable {
    var organizationID: String?
    var projectID: String?
    var apiKeyID: String?
    var lineItemFilter: String?
}

struct DeepLAPIBillingConfiguration: Codable, Equatable {
    var apiPlanType: DeepLAPIPlanType
    var monthlyBaseAmount: Decimal?
    var monthlyBaseCurrency: CurrencyCode
    var includedCharacters: Int?
    var overageUnitCharacters: Int?
    var overageUnitAmount: Decimal?
    var overageCurrency: CurrencyCode
}

enum DeepLAPIPlanType: String, Codable, CaseIterable, Identifiable {
    case free
    case pro
    case custom

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .free:
            "Free"
        case .pro:
            "Pro"
        case .custom:
            "Custom"
        }
    }
}

enum BillingService: String, Codable, CaseIterable, Identifiable {
    case aws
    case gcp
    case azure
    case cloudflare
    case laravelCloud
    case githubCopilot
    case openAiChatGpt
    case openAiCodex
    case openAiApi
    case claude
    case claudeCode
    case deepl
    case deepLApi
    case adobeCreativeCloud
    case dropbox
    case youtube
    case netflix
    case disneyPlus
    case appleTvPlus
    case appleMusic
    case appleArcade
    case iTunesMatch
    case hulu
    case amazon
    case niconicoPremium
    case abema
    case dAnimeStore
    case dmmTv
    case uNext
    case dazn
    case spotifyPremium
    case nintendoSwitchOnline
    case playStationPlus
    case xboxGamePass
    case kindleUnlimited
    case audible
    case appleOne
    case appleFitnessPlus
    case iCloudPlus
    case googleOne
    case microsoft365
    case onePassword
    case pixiv
    case amazonShopping
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
        case .githubCopilot:
            "GitHub Copilot"
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
        case .deepLApi:
            "DeepL API"
        case .adobeCreativeCloud:
            "Adobe Creative Cloud"
        case .dropbox:
            "Dropbox"
        case .youtube:
            "YouTube Premium"
        case .netflix:
            "Netflix"
        case .disneyPlus:
            "Disney+"
        case .appleTvPlus:
            "Apple TV+"
        case .appleMusic:
            "Apple Music"
        case .appleArcade:
            "Apple Arcade"
        case .iTunesMatch:
            "iTunes Match"
        case .hulu:
            "Hulu"
        case .amazon:
            "Amazon Prime"
        case .niconicoPremium:
            "niconico Premium"
        case .abema:
            "ABEMA"
        case .dAnimeStore:
            "d Anime Store"
        case .dmmTv:
            "DMM TV"
        case .uNext:
            "U-NEXT"
        case .dazn:
            "DAZN"
        case .spotifyPremium:
            "Spotify Premium"
        case .nintendoSwitchOnline:
            "Nintendo Switch Online"
        case .playStationPlus:
            "PlayStation Plus"
        case .xboxGamePass:
            "Xbox Game Pass"
        case .kindleUnlimited:
            "Kindle Unlimited"
        case .audible:
            "Audible"
        case .appleOne:
            "Apple One"
        case .appleFitnessPlus:
            "Apple Fitness+"
        case .iCloudPlus:
            "iCloud+"
        case .googleOne:
            "Google One"
        case .microsoft365:
            "Microsoft 365"
        case .onePassword:
            "1Password"
        case .pixiv:
            "pixiv"
        case .amazonShopping:
            "Amazon"
        case .yodobashi:
            "Yodobashi"
        case .yahooShopping:
            "Yahoo Shopping"
        case .mercari:
            "Mercari"
        case .manual:
            "Manual Amount"
        }
    }
}

enum BillingServiceGroup: String, CaseIterable, Identifiable {
    case cloudDev
    case entertainment
    case lifestyle
    case shopping
    case manual

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .cloudDev:
            "Cloud/Dev"
        case .entertainment:
            "Entertainment"
        case .lifestyle:
            "Lifestyle"
        case .shopping:
            "Shopping"
        case .manual:
            "Manual"
        }
    }

    var services: [BillingService] {
        switch self {
        case .cloudDev:
            [
                .aws,
                .gcp,
                .azure,
                .cloudflare,
                .laravelCloud,
                .openAiApi,
                .openAiCodex,
                .openAiChatGpt,
                .githubCopilot,
                .deepl,
                .deepLApi,
                .adobeCreativeCloud,
                .dropbox
            ]
        case .entertainment:
            [
                .youtube,
                .netflix,
                .disneyPlus,
                .appleTvPlus,
                .appleMusic,
                .appleArcade,
                .iTunesMatch,
                .hulu,
                .abema,
                .uNext,
                .niconicoPremium,
                .dAnimeStore,
                .dmmTv,
                .dazn,
                .spotifyPremium,
                .nintendoSwitchOnline,
                .playStationPlus,
                .xboxGamePass
            ]
        case .lifestyle:
            [
                .amazon,
                .kindleUnlimited,
                .audible,
                .appleOne,
                .appleFitnessPlus,
                .iCloudPlus,
                .googleOne,
                .microsoft365,
                .onePassword,
                .pixiv
            ]
        case .shopping:
            [
                .amazonShopping,
                .yodobashi,
                .yahooShopping,
                .mercari
            ]
        case .manual:
            [
                .manual
            ]
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

    nonisolated static func money(_ money: Money) -> String {
        "\(money.currency.rawValue) \(localizedDecimal(money.value, fractionDigits: money.currency.fractionDigits))"
    }

    nonisolated static func jpy(_ decimal: Decimal) -> String {
        "¥\(localizedDecimal(decimal, fractionDigits: 0))"
    }

    nonisolated static func jstDateTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm z"
        formatter.timeZone = TimeZone(identifier: "Asia/Tokyo")
        return formatter.string(from: date)
    }

    private nonisolated static func localizedDecimal(_ decimal: Decimal, fractionDigits: Int) -> String {
        let rounded = rounded(decimal, scale: fractionDigits)
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = ","
        formatter.usesGroupingSeparator = true
        formatter.minimumFractionDigits = fractionDigits
        formatter.maximumFractionDigits = fractionDigits
        return formatter.string(from: NSDecimalNumber(decimal: rounded)) ?? NSDecimalNumber(decimal: rounded).stringValue
    }

    private nonisolated static func rounded(_ decimal: Decimal, scale: Int) -> Decimal {
        var value = decimal
        var result = Decimal()
        NSDecimalRound(&result, &value, scale, .plain)
        return result
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

struct ExchangeRateSnapshot: Codable, Equatable {
    var baseCurrency: CurrencyCode
    var rates: [CurrencyCode: Decimal]
    var fetchedAt: Date
    var sourceName: String
}

struct ConvertedAmount: Codable, Equatable {
    var original: Money
    var jpyAmount: Decimal
    var rate: Decimal
    var rateFetchedAt: Date
    var sourceName: String
    var isEstimated: Bool
}

extension CurrencyCode {
    nonisolated var fractionDigits: Int {
        switch self {
        case .jpy:
            0
        case .usd, .eur:
            2
        }
    }
}

extension BillingCard {
    var currentOriginalAmount: Money? {
        if let originalAmount = lastBillingResult?.originalAmount {
            return originalAmount
        }

        guard let amount else {
            return nil
        }

        return Money(value: amount, currency: currency)
    }

    var totalEligibleOriginalAmount: Money? {
        if lastBillingResult?.amountKind == .unavailable {
            return nil
        }

        return currentOriginalAmount
    }

    var currentConvertedAmount: ConvertedAmount? {
        guard
            let originalAmount = totalEligibleOriginalAmount,
            let lastConvertedAmount,
            lastConvertedAmount.original == originalAmount
        else {
            return nil
        }

        return lastConvertedAmount
    }
}
