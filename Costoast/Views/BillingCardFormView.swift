//
//  BillingCardFormView.swift
//  Costoast
//
//  Created by 池田洋平 on 2026/06/08.
//

import SwiftUI

struct BillingCardFormView: View {
    private let card: BillingCard?
    private let displayOrder: Int
    private let onSave: (BillingCard) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var name: String
    @State private var service: BillingService
    @State private var sourceType: BillingSourceType
    @State private var planName: String
    @State private var currency: CurrencyCode
    @State private var amountText: String
    @State private var billingCycle: BillingCycle
    @State private var billingStartDayText: String

    init(card: BillingCard?, displayOrder: Int, onSave: @escaping (BillingCard) -> Void) {
        self.card = card
        self.displayOrder = displayOrder
        self.onSave = onSave

        _name = State(initialValue: card?.name ?? "")
        _service = State(initialValue: card?.service ?? .manual)
        _sourceType = State(initialValue: card?.sourceType ?? .manualAmount)
        _planName = State(initialValue: card?.planName ?? "")
        _currency = State(initialValue: card?.currency ?? .jpy)
        _amountText = State(initialValue: card?.amount.map(BillingCardFormat.decimal) ?? "")
        _billingCycle = State(initialValue: card?.billingCycle ?? .monthly)
        _billingStartDayText = State(initialValue: card?.billingStartDay.map(String.init) ?? "")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text(card == nil ? "Add Billing Card" : "Edit Billing Card")
                .font(.title2)
                .fontWeight(.semibold)

            Form {
                TextField("Name", text: $name)

                Picker("Service", selection: $service) {
                    ForEach(BillingService.allCases) { service in
                        Text(service.displayName).tag(service)
                    }
                }

                Picker("Source Type", selection: $sourceType) {
                    ForEach(BillingSourceType.allCases) { sourceType in
                        Text(sourceType.displayName).tag(sourceType)
                    }
                }

                if sourceType == .subscriptionPlan {
                    TextField("Plan Name", text: $planName)
                }

                if sourceType == .subscriptionPlan || sourceType == .manualAmount {
                    Picker("Currency", selection: $currency) {
                        ForEach(CurrencyCode.allCases) { currency in
                            Text(currency.rawValue).tag(currency)
                        }
                    }

                    TextField("Amount", text: $amountText)

                    Picker("Billing Cycle", selection: $billingCycle) {
                        ForEach(BillingCycle.allCases) { billingCycle in
                            Text(billingCycle.displayName).tag(billingCycle)
                        }
                    }
                }

                TextField("Billing Start Day", text: $billingStartDayText)

                Text("API credentials will be added in a later phase.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            if !validationMessages.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(validationMessages, id: \.self) { message in
                        Text(message)
                    }
                }
                .font(.callout)
                .foregroundStyle(.red)
            }

            HStack {
                Spacer()
                Button("Cancel") {
                    dismiss()
                }
                Button(card == nil ? "Add" : "Save") {
                    save()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(!validationMessages.isEmpty)
            }
        }
        .padding(24)
        .frame(width: 460)
    }

    private var validationMessages: [String] {
        var messages: [String] = []

        if trimmedName.isEmpty {
            messages.append("Name is required.")
        }

        if !trimmedAmountText.isEmpty {
            if let amount = parsedAmount {
                if NSDecimalNumber(decimal: amount).compare(NSDecimalNumber.zero) == .orderedAscending {
                    messages.append("Amount must be 0 or greater.")
                }
            } else {
                messages.append("Amount must be a valid number.")
            }
        }

        if !trimmedBillingStartDayText.isEmpty {
            if let billingStartDay = parsedBillingStartDay {
                if billingStartDay < 1 || billingStartDay > 31 {
                    messages.append("Billing Start Day must be between 1 and 31.")
                }
            } else {
                messages.append("Billing Start Day must be a valid number.")
            }
        }

        return messages
    }

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var trimmedPlanName: String {
        planName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var trimmedAmountText: String {
        amountText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var trimmedBillingStartDayText: String {
        billingStartDayText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var parsedAmount: Decimal? {
        guard !trimmedAmountText.isEmpty else {
            return nil
        }

        return Decimal(string: trimmedAmountText)
    }

    private var parsedBillingStartDay: Int? {
        guard !trimmedBillingStartDayText.isEmpty else {
            return nil
        }

        return Int(trimmedBillingStartDayText)
    }

    private func save() {
        guard validationMessages.isEmpty else {
            return
        }

        let now = Date()
        let savesPlanDetails = sourceType == .subscriptionPlan
        let savesAmountDetails = sourceType == .subscriptionPlan || sourceType == .manualAmount

        let billingCard = BillingCard(
            id: card?.id ?? UUID(),
            name: trimmedName,
            service: service,
            sourceType: sourceType,
            displayOrder: card?.displayOrder ?? displayOrder,
            planName: savesPlanDetails && !trimmedPlanName.isEmpty ? trimmedPlanName : nil,
            currency: currency,
            amount: savesAmountDetails ? parsedAmount : nil,
            billingCycle: savesAmountDetails ? billingCycle : .monthly,
            billingStartDay: parsedBillingStartDay,
            createdAt: card?.createdAt ?? now,
            updatedAt: now
        )

        onSave(billingCard)
        dismiss()
    }
}

#Preview {
    BillingCardFormView(card: nil, displayOrder: 0) { _ in }
}
