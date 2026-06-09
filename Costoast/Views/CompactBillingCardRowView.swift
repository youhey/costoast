//
//  CompactBillingCardRowView.swift
//  Costoast
//
//  Created by Codex on 2026/06/08.
//

import SwiftUI

struct CompactBillingCardRowView: View {
    let card: BillingCard
    let amountColumnWidths: BillingCardAmountColumnWidths

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            logoView

            Text(card.name)
                .font(.headline)
                .fontWeight(.semibold)
                .lineLimit(1)

            Spacer(minLength: 16)

            jpyAmountView

            Text(originalAmountText)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .multilineTextAlignment(.trailing)
                .frame(width: amountColumnWidths.originalAmount, alignment: .trailing)
        }
        .font(.body)
        .frame(maxWidth: .infinity, minHeight: 42, alignment: .leading)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Color.primary.opacity(0.12))
                .frame(height: 1)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("compact-billing-card-row-\(card.id.uuidString)")
    }

    @ViewBuilder
    private var logoView: some View {
        Group {
            switch card.service.serviceIcon {
            case .asset(let assetName):
                Image(assetName)
                    .resizable()
                    .scaledToFit()
            case .symbol(let systemName):
                Image(systemName: systemName)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: 28, height: 28)
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private var jpyAmountView: some View {
        HStack(alignment: .firstTextBaseline, spacing: Self.amountColumnSpacing) {
            Text(monthlyAmountText)
                .font(.system(size: 17, weight: .semibold))
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

    private static let amountColumnSpacing: CGFloat = 8
}

#Preview {
    VStack(spacing: 10) {
        CompactBillingCardRowView(
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
            amountColumnWidths: .compact(for: [])
        )
    }
    .padding()
    .frame(width: 800)
}
