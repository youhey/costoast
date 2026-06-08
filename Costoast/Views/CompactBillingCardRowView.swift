//
//  CompactBillingCardRowView.swift
//  Costoast
//
//  Created by Codex on 2026/06/08.
//

import SwiftUI

struct CompactBillingCardRowView: View {
    let card: BillingCard

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            logoView

            Text(card.name)
                .font(.headline)
                .fontWeight(.semibold)
                .lineLimit(1)

            Spacer(minLength: 16)

            Text(jpyAmountText)
                .font(.system(size: 17, weight: .semibold))
                .lineLimit(1)
                .multilineTextAlignment(.trailing)

            Text(originalAmountText)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .multilineTextAlignment(.trailing)
        }
        .font(.body)
        .frame(maxWidth: .infinity, minHeight: 54, alignment: .leading)
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(.background, in: RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(.quaternary, lineWidth: 1)
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
        .frame(width: 32, height: 32)
        .accessibilityHidden(true)
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
}

struct CompactAddBillingCardRowView: View {
    var action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.secondary)

                Text("Add Card")
                    .font(.headline)
            }
            .frame(maxWidth: .infinity, minHeight: 44, alignment: .center)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(backgroundColor, in: RoundedRectangle(cornerRadius: 8))
            .overlay {
                RoundedRectangle(cornerRadius: 8)
                    .stroke(.quaternary.opacity(isHovered ? 1 : 0.65), lineWidth: 1)
            }
        }
        .buttonStyle(CompactAddBillingCardButtonStyle(isHovered: isHovered))
        .accessibilityLabel("Add Card")
        .help("Add Card")
        .onHover { isHovered = $0 }
    }

    private var backgroundColor: Color {
        isHovered ? Color.primary.opacity(0.05) : Color.primary.opacity(0.025)
    }
}

private struct CompactAddBillingCardButtonStyle: ButtonStyle {
    var isHovered: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.99 : 1)
            .animation(.easeOut(duration: 0.08), value: configuration.isPressed)
            .animation(.easeOut(duration: 0.12), value: isHovered)
    }
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
            )
        )

        CompactAddBillingCardRowView {}
    }
    .padding()
    .frame(width: 800)
}
