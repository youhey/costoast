//
//  BillingCardRowView.swift
//  Costoast
//
//  Created by 池田洋平 on 2026/06/08.
//

import SwiftUI

struct BillingCardRowView: View {
    let card: BillingCard
    let isRefreshing: Bool
    let canMoveUp: Bool
    let canMoveDown: Bool
    let onMoveUp: () -> Void
    let onMoveDown: () -> Void
    let onRefresh: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 18) {
            logoView

            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .center, spacing: 14) {
                    Text(card.service.displayName)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .lineLimit(1)
                        .accessibilityIdentifier("billing-card-name-\(card.id.uuidString)")

                    Text(card.sourceType.displayName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .overlay {
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .stroke(.gray.opacity(0.35), lineWidth: 1)
                        }

                    Text(card.service.serviceGroupLabel)
                        .font(.caption)
                        .foregroundStyle(card.service.serviceGroupColor)
                        .lineLimit(1)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .overlay {
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .stroke(card.service.serviceGroupColor.opacity(0.75), lineWidth: 1)
                        }

                    Spacer(minLength: 12)

                    CardActionButtons(
                        cardID: card.id,
                        isRefreshing: isRefreshing,
                        canMoveUp: canMoveUp,
                        canMoveDown: canMoveDown,
                        onMoveUp: onMoveUp,
                        onMoveDown: onMoveDown,
                        onRefresh: onRefresh,
                        onEdit: onEdit,
                        onDelete: onDelete
                    )
                }

                HStack(alignment: .firstTextBaseline, spacing: 14) {
                    Text(periodText)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)

                    Spacer(minLength: 16)

                    Text(jpyAmountText)
                        .font(.system(size: 20, weight: .semibold))
                        .lineLimit(1)
                        .multilineTextAlignment(.trailing)

                    Text(originalAmountText)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .multilineTextAlignment(.trailing)

                    Text("Last updated: \(lastUpdatedText)")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .multilineTextAlignment(.trailing)
                }

                statusView
            }
            .font(.body)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(.background, in: RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(.quaternary, lineWidth: 1)
        }
        .overlay(alignment: .leading) {
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(card.service.serviceGroupColor)
                .frame(width: 5)
                .padding(.vertical, 10)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("billing-card-row-\(card.id.uuidString)")
    }

    @ViewBuilder
    private var logoView: some View {
        Group {
            switch card.service.serviceIcon {
            case .asset(let assetName):
                Image(assetName)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 46, height: 46)
            case .symbol(let systemName):
                Image(systemName: systemName)
                    .font(.system(size: 34, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 46, height: 46)
            }
        }
        .frame(width: 78)
        .frame(maxHeight: .infinity)
        .padding(.vertical, 8)
        .background(Color.primary.opacity(0.035), in: RoundedRectangle(cornerRadius: 8))
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private var statusView: some View {
        if isRefreshing {
            Text("Loading...")
                .foregroundStyle(.secondary)
        } else if let error = card.lastRefreshError {
            Text(error)
                .foregroundStyle(.red)
        } else if let message = card.lastBillingResult?.message {
            Text(message)
                .foregroundStyle(.secondary)
        } else if card.sourceType == .apiUsage && card.lastBillingResult == nil {
            Text("Not configured")
                .foregroundStyle(.secondary)
        } else if (card.sourceType == .subscriptionPlan || card.sourceType == .manualAmount) && card.currentOriginalAmount == nil {
            Text("Amount not set")
                .foregroundStyle(.secondary)
        } else if card.currentOriginalAmount == nil {
            Text("Amount unavailable")
                .foregroundStyle(.secondary)
        }
    }

    private var periodText: String {
        guard
            let periodStart = card.lastBillingResult?.periodStart,
            let periodEnd = card.lastBillingResult?.periodEnd
        else {
            return "No period"
        }

        return "\(Self.dateOnlyFormatter.string(from: periodStart)) - \(Self.dateOnlyFormatter.string(from: periodEnd))"
    }

    private var jpyAmountText: String {
        guard let convertedAmount = card.currentConvertedAmount else {
            return "JPY unavailable"
        }

        return BillingCardFormat.jpy(convertedAmount.jpyAmount)
    }

    private var originalAmountText: String {
        guard let originalAmount = card.currentOriginalAmount else {
            return "( -- )"
        }

        return "( \(BillingCardFormat.money(originalAmount)) )"
    }

    private var lastUpdatedText: String {
        BillingCardFormat.jstDateTime(card.lastBillingResult?.fetchedAt ?? card.updatedAt)
    }

    private static let dateOnlyFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy/MM/dd"
        formatter.timeZone = TimeZone(identifier: "Asia/Tokyo")
        return formatter
    }()

}

extension BillingService {
    enum ServiceIcon {
        case asset(String)
        case symbol(String)
    }

    var serviceIcon: ServiceIcon {
        switch self {
        case .aws:
            .asset("LogoAWS")
        case .gcp:
            .asset("LogoGCP")
        case .azure:
            .asset("LogoAzure")
        case .cloudflare:
            .asset("LogoCloudflare")
        case .laravelCloud:
            .asset("LogoLaravelCloud")
        case .githubCopilot:
            .asset("LogoGithub")
        case .openAiChatGpt, .openAiCodex, .openAiApi:
            .asset("LogoOpenAI")
        case .claude, .claudeCode:
            .asset("LogoClaude")
        case .deepl:
            .asset("LogoDeepL")
        case .deepLApi:
            .asset("LogoDeepL")
        case .adobeCreativeCloud:
            .asset("LogoAdobe")
        case .dropbox:
            .asset("LogoDropbox")
        case .youtube:
            .asset("LogoYoutube")
        case .netflix:
            .asset("LogoNetflix")
        case .disneyPlus:
            .asset("LogoDisneyPlus")
        case .uNext:
            .asset("LogoUNext")
        case .dazn:
            .asset("LogoDAZN")
        case .appleTvPlus:
            .asset("LogoAppleTVPlus")
        case .appleMusic:
            .asset("LogoAppleMusic")
        case .appleArcade:
            .asset("LogoAppleArcade")
        case .iTunesMatch:
            .asset("LogoITunes")
        case .hulu:
            .asset("LogoHulu")
        case .dAnimeStore:
            .asset("LogoDAnimeStore")
        case .dmmTv:
            .asset("LogoDMM")
        case .spotifyPremium:
            .asset("LogoSpotify")
        case .nintendoSwitchOnline:
            .asset("LogoNintendoSwitchOnline")
        case .playStationPlus:
            .asset("LogoPlayStationPlus")
        case .xboxGamePass:
            .asset("LogoXboxGamePass")
        case .abema:
            .asset("LogoABEMA")
        case .amazon:
            .asset("LogoAmazonPrime")
        case .niconicoPremium:
            .asset("LogoNiconico")
        case .kindleUnlimited:
            .asset("LogoAmazonKindle")
        case .audible:
            .asset("LogoAudible")
        case .appleOne:
            .asset("LogoAppleOne")
        case .appleFitnessPlus:
            .asset("LogoApple")
        case .iCloudPlus:
            .asset("LogoICloud")
        case .googleOne:
            .asset("LogoGoogleOne")
        case .microsoft365:
            .asset("LogoMicrosoft365")
        case .onePassword:
            .asset("Logo1Password")
        case .pixiv:
            .symbol("paintbrush.fill")
        case .amazonShopping:
            .asset("LogoAmazon")
        case .yahooShopping:
            .asset("LogoYahooShopping")
        case .mercari:
            .asset("LogoMercari")
        case .yodobashi, .manual:
            .asset("LogoUnknown")
        }
    }

    var serviceGroupLabel: String {
        if self == .manual {
            return "Manual"
        }

        return serviceGroup?.displayName ?? "Unknown"
    }

    var serviceGroupColor: Color {
        if self == .manual {
            return .gray
        }

        guard let serviceGroup else {
            return .gray
        }

        switch serviceGroup {
        case .cloudDev:
            return .blue
        case .entertainment:
            return .pink
        case .lifestyle:
            return .green
        case .shopping:
            return .orange
        case .manual:
            return .gray
        }
    }
}

#Preview {
    BillingCardRowView(
        card: BillingCard(
            id: UUID(),
            name: "OpenAI API",
            service: .openAiApi,
            sourceType: .apiUsage,
            displayOrder: 0,
            planName: nil,
            currency: .jpy,
            amount: nil,
            billingCycle: .monthly,
            billingStartDay: nil,
            gcpConfiguration: nil,
            azureConfiguration: nil,
            cloudflareConfiguration: nil,
            laravelCloudConfiguration: nil,
            openAICodexConfiguration: nil,
            deepLAPIConfiguration: nil,
            lastBillingResult: nil,
            lastRefreshError: nil,
            lastConvertedAmount: nil,
            lastConversionError: nil,
            createdAt: Date(),
            updatedAt: Date()
        ),
        isRefreshing: false,
        canMoveUp: false,
        canMoveDown: true,
        onMoveUp: {},
        onMoveDown: {},
        onRefresh: {},
        onEdit: {},
        onDelete: {}
    )
    .padding()
    .frame(width: 800)
}
