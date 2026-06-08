//
//  BillingCardRowView.swift
//  Costoast
//
//  Created by 池田洋平 on 2026/06/08.
//

import SwiftUI

struct BillingCardRowView: View {
    let card: BillingCard
    let onEdit: () -> Void
    let onDelete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                Text(card.name)
                    .font(.headline)

                Spacer()

                HStack(spacing: 8) {
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

                Text("Billing data is not connected yet.")
                    .foregroundStyle(.secondary)
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
            createdAt: Date(),
            updatedAt: Date()
        ),
        onEdit: {},
        onDelete: {}
    )
    .padding()
    .frame(width: 800)
}
