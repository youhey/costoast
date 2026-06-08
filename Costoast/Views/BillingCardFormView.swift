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
    @State private var service: BillingService?
    @State private var sourceType: BillingSourceType?
    @State private var selectedPlanPresetID: String?
    @State private var planName: String
    @State private var currency: CurrencyCode
    @State private var amountText: String
    @State private var billingCycle: BillingCycle
    @State private var billingStartDayText: String
    @State private var apiKey: String = ""
    @State private var organizationID: String = ""
    @State private var awsAccessKeyID: String = ""
    @State private var awsSecretAccessKey: String = ""
    @State private var gcpProjectID: String
    @State private var gcpDatasetID: String
    @State private var gcpTableName: String
    @State private var gcpBillingAccountID: String
    @State private var gcpServiceAccountJSON: String = ""
    @State private var azureTenantID: String
    @State private var azureClientID: String
    @State private var azureSubscriptionID: String
    @State private var azureScope: String
    @State private var azureClientSecret: String = ""
    @State private var cloudflareAccountID: String
    @State private var cloudflareApiToken: String = ""
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
        _service = State(initialValue: card?.service)
        _sourceType = State(initialValue: Self.initialSourceType(for: card))
        _selectedPlanPresetID = State(initialValue: Self.initialPlanPresetID(for: card))
        _planName = State(initialValue: card?.planName ?? "")
        _currency = State(initialValue: card?.currency ?? .jpy)
        _amountText = State(initialValue: card?.amount.map(BillingCardFormat.decimal) ?? "")
        _billingCycle = State(initialValue: card?.billingCycle ?? .monthly)
        _billingStartDayText = State(initialValue: card?.billingStartDay.map(String.init) ?? "")
        _gcpProjectID = State(initialValue: card?.gcpConfiguration?.projectID ?? "")
        _gcpDatasetID = State(initialValue: card?.gcpConfiguration?.datasetID ?? "")
        _gcpTableName = State(initialValue: card?.gcpConfiguration?.tableName ?? "")
        _gcpBillingAccountID = State(initialValue: card?.gcpConfiguration?.billingAccountID ?? "")
        _azureTenantID = State(initialValue: card?.azureConfiguration?.tenantID ?? "")
        _azureClientID = State(initialValue: card?.azureConfiguration?.clientID ?? "")
        _azureSubscriptionID = State(initialValue: card?.azureConfiguration?.subscriptionID ?? "")
        _azureScope = State(initialValue: card?.azureConfiguration?.scope ?? "")
        _cloudflareAccountID = State(initialValue: card?.cloudflareConfiguration?.accountID ?? "")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text(card == nil ? "Add Billing Card" : "Edit Billing Card")
                .font(.title2)
                .fontWeight(.semibold)

            Form {
                TextField("Name", text: $name)

                Picker("Service", selection: $service) {
                    Text("none").tag(Optional<BillingService>.none)
                    Divider()
                    ForEach(BillingService.allCases) { service in
                        Text(service.displayName).tag(Optional(service))
                    }
                }
                .onChange(of: service) { previousService, selectedService in
                    updateSourceTypeForServiceChange(from: previousService, to: selectedService)
                }

                if Self.allowsSourceTypeSelection(service) {
                    Picker("Source Type", selection: $sourceType) {
                        Text("none").tag(Optional<BillingSourceType>.none)
                        Divider()
                        ForEach(BillingSourceType.allCases) { sourceType in
                            Text(sourceType.displayName).tag(Optional(sourceType))
                        }
                    }
                }

                if sourceType == .subscriptionPlan {
                    let presets = SubscriptionPlanPresetCatalog.presets(for: service)
                    if !presets.isEmpty {
                        Picker("Plan Preset", selection: $selectedPlanPresetID) {
                            Text("none").tag(Optional<String>.none)
                            Divider()
                            ForEach(presets) { preset in
                                Text(preset.name).tag(Optional(preset.id))
                            }
                        }
                        .onChange(of: selectedPlanPresetID) { _, selectedPresetID in
                            applySelectedPlanPreset(selectedPresetID)
                        }

                        Text("Plan amounts are editable because subscription prices may vary by region, billing method, and future price changes.")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }

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

                providerConfigurationFields
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
    private var providerConfigurationFields: some View {
        if sourceType == .apiUsage && service == .gcp {
            Section("GCP Billing Export") {
                TextField("Project ID", text: $gcpProjectID)
                TextField("Dataset ID", text: $gcpDatasetID)
                TextField("Table Name", text: $gcpTableName)
                TextField("Billing Account ID", text: $gcpBillingAccountID)
            }
        } else if sourceType == .apiUsage && service == .azure {
            Section("Azure Cost Management") {
                TextField("Tenant ID", text: $azureTenantID)
                TextField("Client ID", text: $azureClientID)
                TextField("Subscription ID", text: $azureSubscriptionID)
                TextField("Scope", text: $azureScope)
            }
        } else if sourceType == .apiUsage && service == .cloudflare {
            Section("Cloudflare Billing") {
                TextField("Account ID", text: $cloudflareAccountID)
            }
        }
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
        } else if sourceType == .apiUsage && service == .gcp {
            Section("GCP Credentials") {
                TextEditor(text: $gcpServiceAccountJSON)
                    .font(.system(.body, design: .monospaced))
                    .frame(minHeight: 120)
                Text("Paste a service account JSON key. Stored securely in macOS Keychain.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        } else if sourceType == .apiUsage && service == .azure {
            Section("Azure Credentials") {
                SecureField("Client Secret", text: $azureClientSecret)
                Text("Stored securely in macOS Keychain.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        } else if sourceType == .apiUsage && service == .cloudflare {
            Section("Cloudflare Credentials") {
                SecureField("API Token", text: $cloudflareApiToken)
                Text("Stored securely in macOS Keychain.")
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

        if service == nil {
            messages.append("Service is required.")
        }

        if sourceType == nil {
            messages.append("Source Type is required.")
        }

        if sourceType == .apiUsage {
            if service == .gcp {
                if trimmedGCPProjectID.isEmpty {
                    messages.append("GCP Project ID is required.")
                }
                if trimmedGCPDatasetID.isEmpty {
                    messages.append("GCP Dataset ID is required.")
                }
                if trimmedGCPTableName.isEmpty {
                    messages.append("GCP Table Name is required.")
                }
            } else if service == .azure {
                if trimmedAzureTenantID.isEmpty {
                    messages.append("Azure Tenant ID is required.")
                }
                if trimmedAzureClientID.isEmpty {
                    messages.append("Azure Client ID is required.")
                }
                if trimmedAzureSubscriptionID.isEmpty && trimmedAzureScope.isEmpty {
                    messages.append("Azure Subscription ID or Scope is required.")
                }
            } else if service == .cloudflare && trimmedCloudflareAccountID.isEmpty {
                messages.append("Cloudflare Account ID is required.")
            }
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

    private var trimmedGCPProjectID: String {
        gcpProjectID.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var trimmedGCPDatasetID: String {
        gcpDatasetID.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var trimmedGCPTableName: String {
        gcpTableName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var trimmedGCPBillingAccountID: String {
        gcpBillingAccountID.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var trimmedAzureTenantID: String {
        azureTenantID.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var trimmedAzureClientID: String {
        azureClientID.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var trimmedAzureSubscriptionID: String {
        azureSubscriptionID.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var trimmedAzureScope: String {
        azureScope.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var trimmedCloudflareAccountID: String {
        cloudflareAccountID.trimmingCharacters(in: .whitespacesAndNewlines)
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
        guard let service, let sourceType else {
            return
        }

        let now = Date()
        let savesPlanDetails = sourceType == .subscriptionPlan
        let savesAmountDetails = sourceType == .subscriptionPlan || sourceType == .manualAmount
        let gcpConfiguration = service == .gcp && sourceType == .apiUsage ? GCPBillingConfiguration(
            projectID: trimmedGCPProjectID,
            datasetID: trimmedGCPDatasetID,
            tableName: trimmedGCPTableName,
            billingAccountID: trimmedGCPBillingAccountID.nilIfEmpty
        ) : nil
        let azureConfiguration = service == .azure && sourceType == .apiUsage ? AzureBillingConfiguration(
            tenantID: trimmedAzureTenantID,
            clientID: trimmedAzureClientID,
            subscriptionID: trimmedAzureSubscriptionID.nilIfEmpty,
            scope: trimmedAzureScope.nilIfEmpty
        ) : nil
        let cloudflareConfiguration = service == .cloudflare && sourceType == .apiUsage ? CloudflareBillingConfiguration(
            accountID: trimmedCloudflareAccountID
        ) : nil

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
            gcpConfiguration: gcpConfiguration,
            azureConfiguration: azureConfiguration,
            cloudflareConfiguration: cloudflareConfiguration,
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
            gcpServiceAccountJSON = credentials.gcpServiceAccountJSON ?? ""
            azureClientSecret = credentials.azureClientSecret ?? ""
            cloudflareApiToken = credentials.cloudflareApiToken ?? ""
            credentialError = nil
        } catch {
            credentialError = error.localizedDescription
        }
    }

    private func updateSourceTypeForServiceChange(from previousService: BillingService?, to selectedService: BillingService?) {
        selectedPlanPresetID = nil

        if Self.requiresAPIUsage(selectedService) {
            sourceType = .apiUsage
            resetPlanFields()
            return
        }

        if Self.requiresSubscriptionPlan(selectedService) {
            sourceType = .subscriptionPlan
            resetPlanFields()
            return
        }

        if !Self.allowsSourceTypeSelection(previousService) {
            sourceType = nil
            resetPlanFields()
            return
        }
    }

    private func applySelectedPlanPreset(_ selectedPresetID: String?) {
        guard
            let selectedPresetID,
            let preset = SubscriptionPlanPresetCatalog.presets(for: service).first(where: { $0.id == selectedPresetID })
        else {
            return
        }

        planName = preset.name
        currency = preset.currency
        amountText = preset.amount.map(BillingCardFormat.decimal) ?? ""
        billingCycle = preset.billingCycle
    }

    private func resetPlanFields() {
        planName = ""
        amountText = ""
        billingCycle = .monthly
    }

    private static func initialSourceType(for card: BillingCard?) -> BillingSourceType? {
        if requiresAPIUsage(card?.service) {
            return .apiUsage
        }

        if requiresSubscriptionPlan(card?.service) {
            return .subscriptionPlan
        }

        return card?.sourceType
    }

    private static func initialPlanPresetID(for card: BillingCard?) -> String? {
        guard
            let card,
            card.sourceType == .subscriptionPlan,
            let planName = card.planName
        else {
            return nil
        }

        return SubscriptionPlanPresetCatalog.presets(for: card.service)
            .first { $0.name == planName }?
            .id
    }

    private static func allowsSourceTypeSelection(_ selectedService: BillingService?) -> Bool {
        !requiresAPIUsage(selectedService) && !requiresSubscriptionPlan(selectedService)
    }

    private static func requiresAPIUsage(_ selectedService: BillingService?) -> Bool {
        switch selectedService {
        case .aws, .azure, .gcp, .cloudflare, .openAiApi:
            true
        case .openAiChatGpt, .openAiCodex, .claude, .claudeCode, .deepl, .youtube, .netflix, .appleTvPlus, .amazon, .niconicoPremium, .abema, .dAnimeStore, .dmmTv, .uNext, .yodobashi, .yahooShopping, .mercari, .manual, .laravelCloud, nil:
            false
        }
    }

    private static func requiresSubscriptionPlan(_ selectedService: BillingService?) -> Bool {
        switch selectedService {
        case .openAiChatGpt, .youtube, .netflix, .appleTvPlus, .amazon, .niconicoPremium, .abema, .dAnimeStore, .dmmTv, .uNext:
            true
        case .aws, .gcp, .azure, .cloudflare, .laravelCloud, .openAiCodex, .openAiApi, .claude, .claudeCode, .deepl, .yodobashi, .yahooShopping, .mercari, .manual, nil:
            false
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
                    awsRegion: nil,
                    gcpServiceAccountJSON: nil,
                    azureClientSecret: nil,
                    cloudflareApiToken: nil
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
                    awsRegion: "us-east-1",
                    gcpServiceAccountJSON: nil,
                    azureClientSecret: nil,
                    cloudflareApiToken: nil
                ),
                for: card.id
            )
        } else if sourceType == .apiUsage && service == .gcp {
            try credentialStore.saveCredentials(
                BillingCredentials(
                    apiKey: nil,
                    organizationID: nil,
                    awsAccessKeyID: nil,
                    awsSecretAccessKey: nil,
                    awsRegion: nil,
                    gcpServiceAccountJSON: gcpServiceAccountJSON.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty,
                    azureClientSecret: nil,
                    cloudflareApiToken: nil
                ),
                for: card.id
            )
        } else if sourceType == .apiUsage && service == .azure {
            try credentialStore.saveCredentials(
                BillingCredentials(
                    apiKey: nil,
                    organizationID: nil,
                    awsAccessKeyID: nil,
                    awsSecretAccessKey: nil,
                    awsRegion: nil,
                    gcpServiceAccountJSON: nil,
                    azureClientSecret: azureClientSecret.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty,
                    cloudflareApiToken: nil
                ),
                for: card.id
            )
        } else if sourceType == .apiUsage && service == .cloudflare {
            try credentialStore.saveCredentials(
                BillingCredentials(
                    apiKey: nil,
                    organizationID: nil,
                    awsAccessKeyID: nil,
                    awsSecretAccessKey: nil,
                    awsRegion: nil,
                    gcpServiceAccountJSON: nil,
                    azureClientSecret: nil,
                    cloudflareApiToken: cloudflareApiToken.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
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
