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
    var note: String?
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
        .githubCopilot: [
            preset(.githubCopilot, "Free", .usd, .monthly),
            preset(.githubCopilot, "Pro", .usd, .monthly),
            preset(.githubCopilot, "Pro+", .usd, .monthly),
            preset(.githubCopilot, "Business", .usd, .monthly),
            preset(.githubCopilot, "Enterprise", .usd, .monthly),
            preset(.githubCopilot, "Custom", .usd, .custom)
        ],
        .deepl: [
            preset(.deepl, "DeepL Pro", .jpy, .monthly),
            preset(.deepl, "DeepL Write", .jpy, .monthly),
            preset(.deepl, "DeepL API", .jpy, .monthly, note: "DeepL API is handled as a fixed subscription card here; API usage is not fetched."),
            preset(.deepl, "Team", .jpy, .monthly),
            preset(.deepl, "Custom", .jpy, .custom)
        ],
        .adobeCreativeCloud: [
            preset(.adobeCreativeCloud, "All Apps", .jpy, .monthly),
            preset(.adobeCreativeCloud, "Single App", .jpy, .monthly),
            preset(.adobeCreativeCloud, "Photography", .jpy, .monthly),
            preset(.adobeCreativeCloud, "Acrobat Pro", .jpy, .monthly),
            preset(.adobeCreativeCloud, "Creative Cloud Standard", .jpy, .monthly),
            preset(.adobeCreativeCloud, "Creative Cloud Pro", .jpy, .monthly),
            preset(.adobeCreativeCloud, "Custom", .jpy, .custom)
        ],
        .dropbox: [
            preset(.dropbox, "Basic", .jpy, .monthly),
            preset(.dropbox, "Plus", .jpy, .monthly),
            preset(.dropbox, "Family", .jpy, .monthly),
            preset(.dropbox, "Professional", .jpy, .monthly),
            preset(.dropbox, "Standard", .jpy, .monthly),
            preset(.dropbox, "Advanced", .jpy, .monthly),
            preset(.dropbox, "Custom", .jpy, .custom)
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
        .disneyPlus: [
            preset(.disneyPlus, "Standard", .jpy, .monthly),
            preset(.disneyPlus, "Premium", .jpy, .monthly),
            preset(.disneyPlus, "Annual Standard", .jpy, .yearly),
            preset(.disneyPlus, "Annual Premium", .jpy, .yearly),
            preset(.disneyPlus, "Custom", .jpy, .custom)
        ],
        .appleTvPlus: [
            preset(.appleTvPlus, "Monthly", .jpy, .monthly),
            preset(.appleTvPlus, "Annual", .jpy, .yearly),
            preset(.appleTvPlus, "Apple One", .jpy, .monthly, note: "This may overlap with Apple One."),
            preset(.appleTvPlus, "Custom", .jpy, .custom)
        ],
        .appleMusic: [
            preset(.appleMusic, "Individual", .jpy, .monthly, note: "This may overlap with Apple One."),
            preset(.appleMusic, "Family", .jpy, .monthly, note: "This may overlap with Apple One."),
            preset(.appleMusic, "Student", .jpy, .monthly, note: "This may overlap with Apple One."),
            preset(.appleMusic, "Custom", .jpy, .custom, note: "This may overlap with Apple One.")
        ],
        .appleArcade: [
            preset(.appleArcade, "Monthly", .jpy, .monthly, note: "This may overlap with Apple One."),
            preset(.appleArcade, "Annual", .jpy, .yearly, note: "This may overlap with Apple One."),
            preset(.appleArcade, "Custom", .jpy, .custom, note: "This may overlap with Apple One.")
        ],
        .iTunesMatch: [
            preset(.iTunesMatch, "Annual", .jpy, .yearly),
            preset(.iTunesMatch, "Custom", .jpy, .custom)
        ],
        .hulu: [
            preset(.hulu, "Monthly", .jpy, .monthly),
            preset(.hulu, "Disney+ Set", .jpy, .monthly, note: "This may overlap with Disney+."),
            preset(.hulu, "Custom", .jpy, .custom)
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
        ],
        .dazn: [
            preset(.dazn, "Monthly", .jpy, .monthly),
            preset(.dazn, "Annual", .jpy, .yearly),
            preset(.dazn, "Annual Paid Monthly", .jpy, .custom),
            preset(.dazn, "Custom", .jpy, .custom)
        ],
        .spotifyPremium: [
            preset(.spotifyPremium, "Individual", .jpy, .monthly),
            preset(.spotifyPremium, "Duo", .jpy, .monthly),
            preset(.spotifyPremium, "Family", .jpy, .monthly),
            preset(.spotifyPremium, "Student", .jpy, .monthly),
            preset(.spotifyPremium, "Custom", .jpy, .custom)
        ],
        .nintendoSwitchOnline: [
            preset(.nintendoSwitchOnline, "Individual 1 Month", .jpy, .monthly),
            preset(.nintendoSwitchOnline, "Individual 3 Months", .jpy, .custom),
            preset(.nintendoSwitchOnline, "Individual 12 Months", .jpy, .yearly),
            preset(.nintendoSwitchOnline, "Family 12 Months", .jpy, .yearly),
            preset(.nintendoSwitchOnline, "Individual + Expansion Pack 12 Months", .jpy, .yearly),
            preset(.nintendoSwitchOnline, "Family + Expansion Pack 12 Months", .jpy, .yearly),
            preset(.nintendoSwitchOnline, "Custom", .jpy, .custom)
        ],
        .playStationPlus: [
            preset(.playStationPlus, "Essential 1 Month", .jpy, .monthly),
            preset(.playStationPlus, "Essential 3 Months", .jpy, .custom),
            preset(.playStationPlus, "Essential 12 Months", .jpy, .yearly),
            preset(.playStationPlus, "Extra 1 Month", .jpy, .monthly),
            preset(.playStationPlus, "Extra 3 Months", .jpy, .custom),
            preset(.playStationPlus, "Extra 12 Months", .jpy, .yearly),
            preset(.playStationPlus, "Premium 1 Month", .jpy, .monthly),
            preset(.playStationPlus, "Premium 3 Months", .jpy, .custom),
            preset(.playStationPlus, "Premium 12 Months", .jpy, .yearly),
            preset(.playStationPlus, "Deluxe", .jpy, .custom),
            preset(.playStationPlus, "Custom", .jpy, .custom)
        ],
        .xboxGamePass: [
            preset(.xboxGamePass, "Core", .jpy, .monthly),
            preset(.xboxGamePass, "Standard", .jpy, .monthly),
            preset(.xboxGamePass, "PC Game Pass", .jpy, .monthly),
            preset(.xboxGamePass, "Ultimate", .jpy, .monthly),
            preset(.xboxGamePass, "Custom", .jpy, .custom)
        ],
        .kindleUnlimited: [
            preset(.kindleUnlimited, "Monthly", .jpy, .monthly),
            preset(.kindleUnlimited, "Campaign", .jpy, .custom),
            preset(.kindleUnlimited, "Custom", .jpy, .custom)
        ],
        .audible: [
            preset(.audible, "Monthly", .jpy, .monthly),
            preset(.audible, "Annual", .jpy, .yearly),
            preset(.audible, "Custom", .jpy, .custom)
        ],
        .appleOne: [
            preset(.appleOne, "Individual", .jpy, .monthly, note: "This plan may overlap with Apple Music, Apple TV+, Apple Arcade, Apple Fitness+, or iCloud+ cards."),
            preset(.appleOne, "Family", .jpy, .monthly, note: "This plan may overlap with Apple Music, Apple TV+, Apple Arcade, Apple Fitness+, or iCloud+ cards."),
            preset(.appleOne, "Premier", .jpy, .monthly, note: "This plan may overlap with Apple Music, Apple TV+, Apple Arcade, Apple Fitness+, or iCloud+ cards."),
            preset(.appleOne, "Custom", .jpy, .custom, note: "This plan may overlap with Apple Music, Apple TV+, Apple Arcade, Apple Fitness+, or iCloud+ cards.")
        ],
        .appleFitnessPlus: [
            preset(.appleFitnessPlus, "Monthly", .jpy, .monthly, note: "This may overlap with Apple One."),
            preset(.appleFitnessPlus, "Annual", .jpy, .yearly, note: "This may overlap with Apple One."),
            preset(.appleFitnessPlus, "Custom", .jpy, .custom, note: "This may overlap with Apple One.")
        ],
        .iCloudPlus: [
            preset(.iCloudPlus, "50GB", .jpy, .monthly, note: "This may overlap with Apple One."),
            preset(.iCloudPlus, "200GB", .jpy, .monthly, note: "This may overlap with Apple One."),
            preset(.iCloudPlus, "2TB", .jpy, .monthly, note: "This may overlap with Apple One."),
            preset(.iCloudPlus, "6TB", .jpy, .monthly, note: "This may overlap with Apple One."),
            preset(.iCloudPlus, "12TB", .jpy, .monthly, note: "This may overlap with Apple One."),
            preset(.iCloudPlus, "Custom", .jpy, .custom, note: "This may overlap with Apple One.")
        ],
        .googleOne: [
            preset(.googleOne, "100GB", .jpy, .monthly),
            preset(.googleOne, "200GB", .jpy, .monthly),
            preset(.googleOne, "2TB", .jpy, .monthly),
            preset(.googleOne, "5TB", .jpy, .monthly),
            preset(.googleOne, "10TB", .jpy, .monthly),
            preset(.googleOne, "Google AI Pro", .jpy, .monthly, note: "Some Google One AI plans may include additional Google services. Check for overlapping cards."),
            preset(.googleOne, "Google AI Ultra", .jpy, .monthly, note: "Some Google One AI plans may include additional Google services. Check for overlapping cards."),
            preset(.googleOne, "Custom", .jpy, .custom)
        ],
        .microsoft365: [
            preset(.microsoft365, "Personal", .jpy, .yearly),
            preset(.microsoft365, "Family", .jpy, .yearly),
            preset(.microsoft365, "Basic", .jpy, .monthly),
            preset(.microsoft365, "Premium", .jpy, .monthly),
            preset(.microsoft365, "Business Basic", .jpy, .monthly),
            preset(.microsoft365, "Business Standard", .jpy, .monthly),
            preset(.microsoft365, "Custom", .jpy, .custom)
        ],
        .onePassword: [
            preset(.onePassword, "Individual", .usd, .monthly),
            preset(.onePassword, "Families", .usd, .monthly),
            preset(.onePassword, "Teams", .usd, .monthly),
            preset(.onePassword, "Business", .usd, .monthly),
            preset(.onePassword, "Custom", .usd, .custom)
        ]
    ]

    private static func preset(
        _ service: BillingService,
        _ name: String,
        _ currency: CurrencyCode,
        _ billingCycle: BillingCycle,
        note: String? = nil
    ) -> SubscriptionPlanPreset {
        SubscriptionPlanPreset(
            id: "\(service.rawValue)-\(name.lowercased().replacingOccurrences(of: " ", with: "-"))",
            service: service,
            name: name,
            currency: currency,
            amount: nil,
            billingCycle: billingCycle,
            isAmountEditable: true,
            note: note
        )
    }
}
