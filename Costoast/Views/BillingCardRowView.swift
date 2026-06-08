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
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                Text(card.name)
                    .font(.headline)

                Spacer()

                HStack(spacing: 8) {
                    Button(isRefreshing ? "Loading..." : "Refresh", action: onRefresh)
                        .disabled(isRefreshing)
                    Button("Edit", action: onEdit)
                    Button("Delete", role: .destructive, action: onDelete)
                }
                .buttonStyle(.borderless)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Service: \(card.service.displayName)")
                Text("Source: \(card.sourceType.displayName)")

                if let planName = card.planName, !planName.isEmpty {
                    Text("Plan: \(planName)")
                }

                if let amount = card.amount {
                    Text("Amount: \(card.currency.rawValue) \(BillingCardFormat.decimal(amount))")
                }

                if card.sourceType == .subscriptionPlan || card.sourceType == .manualAmount {
                    Text("Cycle: \(card.billingCycle.displayName)")
                }

                if let billingStartDay = card.billingStartDay {
                    Text("Billing Start Day: \(billingStartDay)")
                }

                providerStateView
            }
            .font(.body)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(24)
        .background(.background, in: RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(.quaternary, lineWidth: 1)
        }
    }

    @ViewBuilder
    private var providerStateView: some View {
        if isRefreshing {
            Text("Loading...")
                .foregroundStyle(.secondary)
        } else if let error = card.lastRefreshError {
            Text("Failed to fetch billing data.")
                .foregroundStyle(.red)
            Text(error)
                .foregroundStyle(.red)
        } else if let result = card.lastBillingResult {
            resultView(result)
        } else if let amount = card.amount, card.sourceType == .manualAmount || card.sourceType == .subscriptionPlan {
            Text("Original: \(card.currency.rawValue) \(BillingCardFormat.decimal(amount))")
        } else if card.sourceType == .apiUsage {
            Text("Not configured")
                .foregroundStyle(.secondary)
        } else {
            Text("Billing data is not connected yet.")
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private func resultView(_ result: BillingProviderResult) -> some View {
        if let periodStart = result.periodStart, let periodEnd = result.periodEnd {
            Text("Period: \(Self.dateOnlyFormatter.string(from: periodStart)) - \(Self.dateOnlyFormatter.string(from: periodEnd))")
        }

        if let originalAmount = result.originalAmount {
            Text("Original: \(originalAmount.currency.rawValue) \(BillingCardFormat.decimal(originalAmount.value))")
        } else {
            Text(result.message ?? "Amount unavailable.")
                .foregroundStyle(.secondary)
        }

        Text("Updated: \(Self.dateTimeFormatter.string(from: result.fetchedAt))")
            .foregroundStyle(.secondary)
    }

    private static let dateOnlyFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    private static let dateTimeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm z"
        return formatter
    }()
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
