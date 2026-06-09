//
//  BillingCardRowView.swift
//  Costoast
//
//  Created by 池田洋平 on 2026/06/08.
//

import AppKit
import SwiftUI

struct BillingCardRowView: View {
    let card: BillingCard
    let amountColumnWidths: BillingCardAmountColumnWidths
    let isRefreshing: Bool
    let isPinned: Bool
    let canMoveUp: Bool
    let canMoveDown: Bool
    let onTogglePinned: () -> Void
    let onMoveUp: () -> Void
    let onMoveDown: () -> Void
    let onRefresh: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            pinButton
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

                    jpyAmountView

                    Text(originalAmountText)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .multilineTextAlignment(.trailing)
                        .frame(width: amountColumnWidths.originalAmount, alignment: .trailing)

                    Text("Last updated: \(lastUpdatedText)")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .multilineTextAlignment(.trailing)
                        .frame(width: amountColumnWidths.lastUpdated, alignment: .trailing)
                }

                statusView
            }
            .font(.body)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .frame(height: Self.cardHeight, alignment: .center)
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

    private var pinButton: some View {
        Button(action: onTogglePinned) {
            Image(systemName: isPinned ? "pin.fill" : "pin")
                .font(.system(size: 15, weight: .semibold))
                .frame(width: 24, height: 30)
                .foregroundStyle(isPinned ? .yellow : .secondary)
        }
        .buttonStyle(.plain)
        .opacity(isPinned ? 1 : 0.45)
        .accessibilityLabel(isPinned ? "Unpin Card" : "Pin Card")
        .accessibilityIdentifier("pin-card-\(card.id.uuidString)")
        .help(isPinned ? "Unpin Card" : "Pin Card")
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
                .lineLimit(1)
        } else if let error = card.lastRefreshError {
            Text(error)
                .foregroundStyle(.red)
                .lineLimit(1)
        } else if let message = card.lastBillingResult?.message {
            Text(message)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        } else if card.sourceType == .apiUsage && card.lastBillingResult == nil {
            Text("Not configured")
                .foregroundStyle(.secondary)
                .lineLimit(1)
        } else if (card.sourceType == .subscriptionPlan || card.sourceType == .manualAmount) && card.currentOriginalAmount == nil {
            Text("Amount not set")
                .foregroundStyle(.secondary)
                .lineLimit(1)
        } else if card.currentOriginalAmount == nil {
            Text("Amount unavailable")
                .foregroundStyle(.secondary)
                .lineLimit(1)
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

    @ViewBuilder
    private var jpyAmountView: some View {
        HStack(alignment: .firstTextBaseline, spacing: Self.amountColumnSpacing) {
            Text(monthlyAmountText)
                .font(.system(size: 20, weight: .semibold))
                .lineLimit(1)
                .multilineTextAlignment(.trailing)
                .frame(width: amountColumnWidths.monthlyAmount, alignment: .trailing)

            Text(preMonthlyEquivalentAmountText)
                .font(.body)
                .fontWeight(.regular)
                .lineLimit(1)
                .multilineTextAlignment(.leading)
                .frame(width: amountColumnWidths.preMonthlyEquivalentAmount, alignment: .leading)
        }
    }

    private var originalAmountText: String {
        card.originalAmountDisplayText
    }

    private var monthlyAmountText: String {
        card.monthlyEquivalentAmountDisplayText
    }

    private var preMonthlyEquivalentAmountText: String {
        card.preMonthlyEquivalentAmountDisplayText
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

    private static let amountColumnSpacing: CGFloat = 8
    private static let cardHeight: CGFloat = 118
}

struct BillingCardAmountColumnWidths {
    var monthlyAmount: CGFloat
    var preMonthlyEquivalentAmount: CGFloat
    var originalAmount: CGFloat
    var lastUpdated: CGFloat

    static func cards(for cards: [BillingCard]) -> BillingCardAmountColumnWidths {
        BillingCardAmountColumnWidths(
            monthlyAmount: width(for: cards.map(\.monthlyEquivalentAmountDisplayText), font: .systemFont(ofSize: 20, weight: .semibold)),
            preMonthlyEquivalentAmount: width(for: cards.map(\.preMonthlyEquivalentAmountDisplayText), font: .systemFont(ofSize: NSFont.systemFontSize, weight: .regular)),
            originalAmount: width(for: cards.map(\.originalAmountDisplayText), font: .systemFont(ofSize: NSFont.systemFontSize, weight: .regular)),
            lastUpdated: width(for: cards.map(\.lastUpdatedDisplayText), font: .systemFont(ofSize: NSFont.systemFontSize, weight: .regular))
        )
    }

    static func compact(for cards: [BillingCard]) -> BillingCardAmountColumnWidths {
        BillingCardAmountColumnWidths(
            monthlyAmount: width(for: cards.map(\.monthlyEquivalentAmountDisplayText), font: .systemFont(ofSize: 17, weight: .semibold)),
            preMonthlyEquivalentAmount: width(for: cards.map(\.preMonthlyEquivalentAmountDisplayText), font: .systemFont(ofSize: NSFont.systemFontSize, weight: .regular)),
            originalAmount: width(for: cards.map(\.originalAmountDisplayText), font: .systemFont(ofSize: NSFont.systemFontSize, weight: .regular)),
            lastUpdated: 0
        )
    }

    private static func width(for texts: [String], font: NSFont) -> CGFloat {
        let maxWidth = texts
            .filter { !$0.isEmpty }
            .map { ($0 as NSString).size(withAttributes: [.font: font]).width }
            .max() ?? 0

        return ceil(maxWidth) + (maxWidth > 0 ? 4 : 0)
    }
}

extension BillingCard {
    var isPinned: Bool {
        pinnedAt != nil
    }

    var monthlyEquivalentAmountDisplayText: String {
        guard let monthlyAmount = currentMonthlyEquivalentJPYAmount else {
            return "JPY unavailable"
        }

        return BillingCardFormat.jpy(monthlyAmount)
    }

    var preMonthlyEquivalentAmountDisplayText: String {
        guard billingCycle.monthlyEquivalentMultiplier != 1,
              let convertedAmount = currentConvertedAmount else {
            return ""
        }

        return "/ \(BillingCardFormat.jpy(convertedAmount.jpyAmount))"
    }

    var originalAmountDisplayText: String {
        guard let originalAmount = currentOriginalAmount else {
            return "( -- )"
        }

        return "( \(BillingCardFormat.money(originalAmount)) )"
    }

    var lastUpdatedDisplayText: String {
        "Last updated: \(BillingCardFormat.jstDateTime(lastBillingResult?.fetchedAt ?? updatedAt))"
    }
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
            .asset("LogoPixiv")
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
            pinnedAt: nil,
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
        amountColumnWidths: .cards(for: []),
        isRefreshing: false,
        isPinned: false,
        canMoveUp: false,
        canMoveDown: true,
        onTogglePinned: {},
        onMoveUp: {},
        onMoveDown: {},
        onRefresh: {},
        onEdit: {},
        onDelete: {}
    )
    .padding()
    .frame(width: 800)
}
