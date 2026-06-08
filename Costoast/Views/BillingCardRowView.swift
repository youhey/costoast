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

                    Spacer(minLength: 12)

                    CardActionButtons(
                        isRefreshing: isRefreshing,
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
    }

    @ViewBuilder
    private var logoView: some View {
        Image(card.service.logoAssetName)
            .resizable()
            .scaledToFit()
            .frame(width: 46, height: 46)
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
        } else if card.sourceType == .apiUsage {
            Text("Not configured")
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

private extension BillingService {
    var logoAssetName: String {
        switch self {
        case .aws:
            "LogoAWS"
        case .gcp:
            "LogoGCP"
        case .azure:
            "LogoAzure"
        case .cloudflare:
            "LogoCloudflare"
        case .laravelCloud:
            "LogoLaravelCloud"
        case .openAiChatGpt, .openAiCodex, .openAiApi:
            "LogoOpenAI"
        case .claude, .claudeCode:
            "LogoClaude"
        case .deepl:
            "LogoDeepL"
        case .youtube:
            "LogoYoutube"
        case .amazon, .yodobashi, .yahooShopping, .mercari, .manual:
            "LogoUnknown"
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
            lastBillingResult: nil,
            lastRefreshError: nil,
            lastConvertedAmount: nil,
            lastConversionError: nil,
            createdAt: Date(),
            updatedAt: Date()
        ),
        isRefreshing: false,
        onRefresh: {},
        onEdit: {},
        onDelete: {}
    )
    .padding()
    .frame(width: 800)
}
