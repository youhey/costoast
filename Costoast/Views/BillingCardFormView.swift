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
    private let credentialStore: CredentialStore
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
    @State private var apiKey: String = ""
    @State private var organizationID: String = ""
    @State private var awsAccessKeyID: String = ""
    @State private var awsSecretAccessKey: String = ""
    @State private var credentialError: String?

    init(
        card: BillingCard?,
        displayOrder: Int,
        credentialStore: CredentialStore = CredentialStore(),
        onSave: @escaping (BillingCard) -> Void
    ) {
        self.card = card
        self.displayOrder = displayOrder
        self.credentialStore = credentialStore
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

                credentialFields
            }

            if !validationMessages.isEmpty || credentialError != nil {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(validationMessages, id: \.self) { message in
                        Text(message)
                    }
                    if let credentialError {
                        Text(credentialError)
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
        .frame(width: 520)
        .onAppear(perform: loadCredentials)
    }

    @ViewBuilder
    private var credentialFields: some View {
        if sourceType == .apiUsage && service == .openAiApi {
            Section("OpenAI API Credentials") {
                SecureField("API Key", text: $apiKey)
                TextField("Organization ID", text: $organizationID)
                Text("Used to fetch OpenAI API usage and cost data.\nStored securely in macOS Keychain.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        } else if sourceType == .apiUsage && service == .aws {
            Section("AWS Credentials") {
                TextField("Access Key ID", text: $awsAccessKeyID)
                SecureField("Secret Access Key", text: $awsSecretAccessKey)
                Text("Used to fetch AWS cost data from Cost Explorer.\nStored securely in macOS Keychain.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
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
            lastBillingResult: card?.lastBillingResult,
            lastRefreshError: card?.lastRefreshError,
            lastConvertedAmount: card?.lastConvertedAmount,
            lastConversionError: card?.lastConversionError,
            createdAt: card?.createdAt ?? now,
            updatedAt: now
        )

        do {
            try saveCredentials(for: billingCard)
            credentialError = nil
        } catch {
            credentialError = error.localizedDescription
            return
        }

        onSave(billingCard)
        dismiss()
    }

    private func loadCredentials() {
        guard let card else {
            return
        }

        do {
            guard let credentials = try credentialStore.loadCredentials(for: card.id) else {
                return
            }

            apiKey = credentials.apiKey ?? ""
            organizationID = credentials.organizationID ?? ""
            awsAccessKeyID = credentials.awsAccessKeyID ?? ""
            awsSecretAccessKey = credentials.awsSecretAccessKey ?? ""
            credentialError = nil
        } catch {
            credentialError = error.localizedDescription
        }
    }

    private func saveCredentials(for card: BillingCard) throws {
        if sourceType == .apiUsage && service == .openAiApi {
            try credentialStore.saveCredentials(
                BillingCredentials(
                    apiKey: apiKey.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty,
                    organizationID: organizationID.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty,
                    awsAccessKeyID: nil,
                    awsSecretAccessKey: nil,
                    awsRegion: nil
                ),
                for: card.id
            )
        } else if sourceType == .apiUsage && service == .aws {
            try credentialStore.saveCredentials(
                BillingCredentials(
                    apiKey: nil,
                    organizationID: nil,
                    awsAccessKeyID: awsAccessKeyID.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty,
                    awsSecretAccessKey: awsSecretAccessKey.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty,
                    awsRegion: "us-east-1"
                ),
                for: card.id
            )
        } else {
            try credentialStore.deleteCredentials(for: card.id)
        }
    }
}

#Preview {
    BillingCardFormView(card: nil, displayOrder: 0) { _ in }
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
