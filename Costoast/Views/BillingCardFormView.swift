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
    @FocusState private var focusedField: Field?

    @State private var name: String
    @State private var nameIsSuggested: Bool
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
    @State private var laravelCloudOrganizationID: String
    @State private var laravelCloudApiToken: String = ""
    @State private var openAICodexOrganizationID: String
    @State private var openAICodexProjectID: String
    @State private var openAICodexAPIKeyID: String
    @State private var openAICodexLineItemFilter: String
    @State private var openAICodexAdminAPIKey: String = ""
    @State private var deepLAPIPlanType: DeepLAPIPlanType
    @State private var deepLMonthlyBaseAmountText: String
    @State private var deepLMonthlyBaseCurrency: CurrencyCode
    @State private var deepLIncludedCharactersText: String
    @State private var deepLOverageUnitCharactersText: String
    @State private var deepLOverageUnitAmountText: String
    @State private var deepLOverageCurrency: CurrencyCode
    @State private var deepLApiKey: String = ""
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
        _nameIsSuggested = State(initialValue: false)
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
        _laravelCloudOrganizationID = State(initialValue: card?.laravelCloudConfiguration?.organizationID ?? "")
        _openAICodexOrganizationID = State(initialValue: card?.openAICodexConfiguration?.organizationID ?? "")
        _openAICodexProjectID = State(initialValue: card?.openAICodexConfiguration?.projectID ?? "")
        _openAICodexAPIKeyID = State(initialValue: card?.openAICodexConfiguration?.apiKeyID ?? "")
        _openAICodexLineItemFilter = State(initialValue: card?.openAICodexConfiguration?.lineItemFilter ?? "codex")
        _deepLAPIPlanType = State(initialValue: card?.deepLAPIConfiguration?.apiPlanType ?? .free)
        _deepLMonthlyBaseAmountText = State(initialValue: card?.deepLAPIConfiguration?.monthlyBaseAmount.map(BillingCardFormat.decimal) ?? "")
        _deepLMonthlyBaseCurrency = State(initialValue: card?.deepLAPIConfiguration?.monthlyBaseCurrency ?? .jpy)
        _deepLIncludedCharactersText = State(initialValue: card?.deepLAPIConfiguration?.includedCharacters.map(String.init) ?? "")
        _deepLOverageUnitCharactersText = State(initialValue: card?.deepLAPIConfiguration?.overageUnitCharacters.map(String.init) ?? "")
        _deepLOverageUnitAmountText = State(initialValue: card?.deepLAPIConfiguration?.overageUnitAmount.map(BillingCardFormat.decimal) ?? "")
        _deepLOverageCurrency = State(initialValue: card?.deepLAPIConfiguration?.overageCurrency ?? .jpy)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text(card == nil ? "Add Billing Card" : "Edit Billing Card")
                .font(.title2)
                .fontWeight(.semibold)

            Form {
                TextField("Name", text: $name)
                    .foregroundStyle(nameIsSuggested ? .secondary : .primary)
                    .focused($focusedField, equals: .name)
                    .onChange(of: focusedField) { _, focusedField in
                        if focusedField == .name, nameIsSuggested {
                            name = ""
                            nameIsSuggested = false
                        }
                    }

                Picker("Service", selection: $service) {
                    Text("none").tag(Optional<BillingService>.none)
                    Divider()
                    ForEach(BillingServiceGroup.allCases) { group in
                        Section(group.displayName) {
                            ForEach(group.services) { service in
                                Text(service.displayName).tag(Optional(service))
                            }
                        }
                    }
                }
                .onChange(of: service) { previousService, selectedService in
                    updateSourceTypeForServiceChange(from: previousService, to: selectedService)
                }

                if Self.allowsSourceTypeSelection(service) {
                    Picker("Source Type", selection: $sourceType) {
                        Text("none").tag(Optional<BillingSourceType>.none)
                        Divider()
                        ForEach(Self.supportedSourceTypes(for: service)) { sourceType in
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

                        if let selectedPlanNote {
                            Text(selectedPlanNote)
                                .font(.callout)
                                .foregroundStyle(.orange)
                        }
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
        } else if sourceType == .apiUsage && service == .laravelCloud {
            Section("Laravel Cloud Usage") {
                TextField("Organization ID", text: $laravelCloudOrganizationID)
                Text("Organization ID is optional and only used when the API response supports organization scoping.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        } else if sourceType == .apiUsage && service == .openAiCodex {
            Section("OpenAI Codex Cost Filter") {
                TextField("Organization ID", text: $openAICodexOrganizationID)
                TextField("Project ID", text: $openAICodexProjectID)
                TextField("API Key ID", text: $openAICodexAPIKeyID)
                TextField("Line Item Filter", text: $openAICodexLineItemFilter)
                Text("Codex costs are only shown when a line item, project ID, or API key ID filter identifies matching costs.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        } else if sourceType == .apiUsage && service == .deepLApi {
            Section("DeepL API Pricing Estimate") {
                Picker("API Plan Type", selection: $deepLAPIPlanType) {
                    ForEach(DeepLAPIPlanType.allCases) { planType in
                        Text(planType.displayName).tag(planType)
                    }
                }
                TextField("Monthly Base Amount", text: $deepLMonthlyBaseAmountText)
                Picker("Monthly Base Currency", selection: $deepLMonthlyBaseCurrency) {
                    ForEach(CurrencyCode.allCases) { currency in
                        Text(currency.rawValue).tag(currency)
                    }
                }
                TextField("Included Characters", text: $deepLIncludedCharactersText)
                TextField("Overage Unit Characters", text: $deepLOverageUnitCharactersText)
                TextField("Overage Unit Amount", text: $deepLOverageUnitAmountText)
                Picker("Overage Currency", selection: $deepLOverageCurrency) {
                    ForEach(CurrencyCode.allCases) { currency in
                        Text(currency.rawValue).tag(currency)
                    }
                }
                Text("If pricing details are incomplete, DeepL API usage is shown without adding the card to Total.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
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
        } else if sourceType == .apiUsage && service == .laravelCloud {
            Section("Laravel Cloud Credentials") {
                SecureField("API Token", text: $laravelCloudApiToken)
                Text("Used to fetch Laravel Cloud usage. Stored securely in macOS Keychain.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        } else if sourceType == .apiUsage && service == .openAiCodex {
            Section("OpenAI Codex Credentials") {
                SecureField("Admin API Key", text: $openAICodexAdminAPIKey)
                Text("Used to fetch OpenAI organization costs. Stored securely in macOS Keychain.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        } else if sourceType == .apiUsage && service == .deepLApi {
            Section("DeepL API Credentials") {
                SecureField("API Key", text: $deepLApiKey)
                Text("Used to fetch DeepL API usage. Stored securely in macOS Keychain.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var validationMessages: [String] {
        var messages: [String] = []

        if effectiveName.isEmpty {
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
            } else if service == .deepLApi {
                if !trimmedDeepLMonthlyBaseAmountText.isEmpty && parsedDeepLMonthlyBaseAmount == nil {
                    messages.append("DeepL Monthly Base Amount must be a valid number.")
                }
                if !trimmedDeepLIncludedCharactersText.isEmpty && parsedDeepLIncludedCharacters == nil {
                    messages.append("DeepL Included Characters must be a valid number.")
                }
                if !trimmedDeepLOverageUnitCharactersText.isEmpty && parsedDeepLOverageUnitCharacters == nil {
                    messages.append("DeepL Overage Unit Characters must be a valid number.")
                }
                if !trimmedDeepLOverageUnitAmountText.isEmpty && parsedDeepLOverageUnitAmount == nil {
                    messages.append("DeepL Overage Unit Amount must be a valid number.")
                }
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

    private var effectiveName: String {
        if !trimmedName.isEmpty && !nameIsSuggested {
            return trimmedName
        }

        return service?.displayName ?? trimmedName
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

    private var trimmedLaravelCloudOrganizationID: String {
        laravelCloudOrganizationID.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var trimmedOpenAICodexOrganizationID: String {
        openAICodexOrganizationID.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var trimmedOpenAICodexProjectID: String {
        openAICodexProjectID.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var trimmedOpenAICodexAPIKeyID: String {
        openAICodexAPIKeyID.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var trimmedOpenAICodexLineItemFilter: String {
        openAICodexLineItemFilter.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var trimmedDeepLMonthlyBaseAmountText: String {
        deepLMonthlyBaseAmountText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var trimmedDeepLIncludedCharactersText: String {
        deepLIncludedCharactersText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var trimmedDeepLOverageUnitCharactersText: String {
        deepLOverageUnitCharactersText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var trimmedDeepLOverageUnitAmountText: String {
        deepLOverageUnitAmountText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var parsedAmount: Decimal? {
        guard !trimmedAmountText.isEmpty else {
            return nil
        }

        return Decimal(string: normalizedAmountText)
    }

    private var parsedBillingStartDay: Int? {
        guard !trimmedBillingStartDayText.isEmpty else {
            return nil
        }

        return Int(trimmedBillingStartDayText)
    }

    private var parsedDeepLMonthlyBaseAmount: Decimal? {
        parsedDecimal(from: trimmedDeepLMonthlyBaseAmountText)
    }

    private var parsedDeepLIncludedCharacters: Int? {
        parsedPositiveInt(from: trimmedDeepLIncludedCharactersText)
    }

    private var parsedDeepLOverageUnitCharacters: Int? {
        parsedPositiveInt(from: trimmedDeepLOverageUnitCharactersText)
    }

    private var parsedDeepLOverageUnitAmount: Decimal? {
        parsedDecimal(from: trimmedDeepLOverageUnitAmountText)
    }

    private func parsedDecimal(from text: String) -> Decimal? {
        guard !text.isEmpty else {
            return nil
        }

        guard let decimal = Decimal(string: text.replacingOccurrences(of: ",", with: "")) else {
            return nil
        }

        return NSDecimalNumber(decimal: decimal).compare(NSDecimalNumber.zero) == .orderedAscending ? nil : decimal
    }

    private func parsedPositiveInt(from text: String) -> Int? {
        guard !text.isEmpty, let value = Int(text.replacingOccurrences(of: ",", with: "")), value > 0 else {
            return nil
        }

        return value
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
        let laravelCloudConfiguration = service == .laravelCloud && sourceType == .apiUsage ? LaravelCloudBillingConfiguration(
            organizationID: trimmedLaravelCloudOrganizationID.nilIfEmpty
        ) : nil
        let openAICodexConfiguration = service == .openAiCodex && sourceType == .apiUsage ? OpenAICodexBillingConfiguration(
            organizationID: trimmedOpenAICodexOrganizationID.nilIfEmpty,
            projectID: trimmedOpenAICodexProjectID.nilIfEmpty,
            apiKeyID: trimmedOpenAICodexAPIKeyID.nilIfEmpty,
            lineItemFilter: trimmedOpenAICodexLineItemFilter.nilIfEmpty
        ) : nil
        let deepLAPIConfiguration = service == .deepLApi && sourceType == .apiUsage ? DeepLAPIBillingConfiguration(
            apiPlanType: deepLAPIPlanType,
            monthlyBaseAmount: parsedDeepLMonthlyBaseAmount,
            monthlyBaseCurrency: deepLMonthlyBaseCurrency,
            includedCharacters: parsedDeepLIncludedCharacters,
            overageUnitCharacters: parsedDeepLOverageUnitCharacters,
            overageUnitAmount: parsedDeepLOverageUnitAmount,
            overageCurrency: deepLOverageCurrency
        ) : nil

        let billingCard = BillingCard(
            id: card?.id ?? UUID(),
            name: effectiveName,
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
            laravelCloudConfiguration: laravelCloudConfiguration,
            openAICodexConfiguration: openAICodexConfiguration,
            deepLAPIConfiguration: deepLAPIConfiguration,
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
            laravelCloudApiToken = credentials.laravelCloudApiToken ?? ""
            openAICodexAdminAPIKey = credentials.apiKey ?? ""
            deepLApiKey = credentials.deepLApiKey ?? ""
            credentialError = nil
        } catch {
            credentialError = error.localizedDescription
        }
    }

    private func updateSourceTypeForServiceChange(from previousService: BillingService?, to selectedService: BillingService?) {
        selectedPlanPresetID = nil
        updateSuggestedName(for: selectedService)

        if Self.requiresAPIUsage(selectedService) {
            sourceType = .apiUsage
            resetPlanFields()
            return
        }

        if Self.defaultsToSubscriptionPlan(selectedService) {
            if let sourceType, Self.supportedSourceTypes(for: selectedService).contains(sourceType), sourceType != .apiUsage {
                resetPlanFields()
                return
            } else {
                sourceType = .subscriptionPlan
            }
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

    private var selectedPlanNote: String? {
        guard
            sourceType == .subscriptionPlan,
            let selectedPlanPresetID,
            let preset = SubscriptionPlanPresetCatalog.presets(for: service).first(where: { $0.id == selectedPlanPresetID })
        else {
            return nil
        }

        return preset.note
    }

    private func updateSuggestedName(for selectedService: BillingService?) {
        guard focusedField != .name else {
            return
        }

        guard let selectedService else {
            if nameIsSuggested {
                name = ""
                nameIsSuggested = false
            }
            return
        }

        if trimmedName.isEmpty || nameIsSuggested {
            name = selectedService.displayName
            nameIsSuggested = true
        }
    }

    private func resetPlanFields() {
        planName = ""
        amountText = ""
        billingCycle = .monthly
    }

    private static func initialSourceType(for card: BillingCard?) -> BillingSourceType? {
        if let card, supportedSourceTypes(for: card.service).contains(card.sourceType) {
            return card.sourceType
        }

        if requiresAPIUsage(card?.service) {
            return .apiUsage
        }

        if defaultsToSubscriptionPlan(card?.service) {
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
        supportedSourceTypes(for: selectedService).count > 1
    }

    private static func supportedSourceTypes(for selectedService: BillingService?) -> [BillingSourceType] {
        if requiresAPIUsage(selectedService) {
            switch selectedService {
            case .laravelCloud:
                return [.apiUsage, .manualAmount]
            case .openAiCodex, .deepLApi:
                return [.apiUsage, .subscriptionPlan, .manualAmount]
            default:
                return [.apiUsage]
            }
        }

        if defaultsToSubscriptionPlan(selectedService) {
            return [.subscriptionPlan, .manualAmount]
        }

        return BillingSourceType.allCases
    }

    private static func requiresAPIUsage(_ selectedService: BillingService?) -> Bool {
        switch selectedService {
        case .aws, .azure, .gcp, .cloudflare, .openAiApi, .laravelCloud, .openAiCodex, .deepLApi:
            true
        case .githubCopilot, .openAiChatGpt, .claude, .claudeCode, .deepl, .adobeCreativeCloud, .dropbox, .youtube, .netflix, .disneyPlus, .appleTvPlus, .appleMusic, .appleArcade, .iTunesMatch, .hulu, .amazon, .niconicoPremium, .abema, .dAnimeStore, .dmmTv, .uNext, .dazn, .spotifyPremium, .nintendoSwitchOnline, .playStationPlus, .xboxGamePass, .kindleUnlimited, .audible, .appleOne, .appleFitnessPlus, .iCloudPlus, .googleOne, .microsoft365, .onePassword, .pixiv, .amazonShopping, .yodobashi, .yahooShopping, .mercari, .manual, nil:
            false
        }
    }

    private static func defaultsToSubscriptionPlan(_ selectedService: BillingService?) -> Bool {
        switch selectedService {
        case .openAiChatGpt, .githubCopilot, .deepl, .adobeCreativeCloud, .dropbox, .youtube, .netflix, .disneyPlus, .appleTvPlus, .appleMusic, .appleArcade, .iTunesMatch, .hulu, .amazon, .niconicoPremium, .abema, .dAnimeStore, .dmmTv, .uNext, .dazn, .spotifyPremium, .nintendoSwitchOnline, .playStationPlus, .xboxGamePass, .kindleUnlimited, .audible, .appleOne, .appleFitnessPlus, .iCloudPlus, .googleOne, .microsoft365, .onePassword, .pixiv:
            true
        case .aws, .gcp, .azure, .cloudflare, .laravelCloud, .openAiCodex, .openAiApi, .claude, .claudeCode, .deepLApi, .amazonShopping, .yodobashi, .yahooShopping, .mercari, .manual, nil:
            false
        }
    }

    private var normalizedAmountText: String {
        trimmedAmountText.replacingOccurrences(of: ",", with: "")
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
                    cloudflareApiToken: nil,
                    laravelCloudApiToken: nil,
                    deepLApiKey: nil
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
                    cloudflareApiToken: nil,
                    laravelCloudApiToken: nil,
                    deepLApiKey: nil
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
                    cloudflareApiToken: nil,
                    laravelCloudApiToken: nil,
                    deepLApiKey: nil
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
                    cloudflareApiToken: nil,
                    laravelCloudApiToken: nil,
                    deepLApiKey: nil
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
                    cloudflareApiToken: cloudflareApiToken.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty,
                    laravelCloudApiToken: nil,
                    deepLApiKey: nil
                ),
                for: card.id
            )
        } else if sourceType == .apiUsage && service == .laravelCloud {
            try credentialStore.saveCredentials(
                BillingCredentials(
                    apiKey: nil,
                    organizationID: nil,
                    awsAccessKeyID: nil,
                    awsSecretAccessKey: nil,
                    awsRegion: nil,
                    gcpServiceAccountJSON: nil,
                    azureClientSecret: nil,
                    cloudflareApiToken: nil,
                    laravelCloudApiToken: laravelCloudApiToken.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty,
                    deepLApiKey: nil
                ),
                for: card.id
            )
        } else if sourceType == .apiUsage && service == .openAiCodex {
            try credentialStore.saveCredentials(
                BillingCredentials(
                    apiKey: openAICodexAdminAPIKey.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty,
                    organizationID: trimmedOpenAICodexOrganizationID.nilIfEmpty,
                    awsAccessKeyID: nil,
                    awsSecretAccessKey: nil,
                    awsRegion: nil,
                    gcpServiceAccountJSON: nil,
                    azureClientSecret: nil,
                    cloudflareApiToken: nil,
                    laravelCloudApiToken: nil,
                    deepLApiKey: nil
                ),
                for: card.id
            )
        } else if sourceType == .apiUsage && service == .deepLApi {
            try credentialStore.saveCredentials(
                BillingCredentials(
                    apiKey: nil,
                    organizationID: nil,
                    awsAccessKeyID: nil,
                    awsSecretAccessKey: nil,
                    awsRegion: nil,
                    gcpServiceAccountJSON: nil,
                    azureClientSecret: nil,
                    cloudflareApiToken: nil,
                    laravelCloudApiToken: nil,
                    deepLApiKey: deepLApiKey.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
                ),
                for: card.id
            )
        } else {
            try credentialStore.deleteCredentials(for: card.id)
        }
    }
}

private extension BillingCardFormView {
    enum Field {
        case name
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
