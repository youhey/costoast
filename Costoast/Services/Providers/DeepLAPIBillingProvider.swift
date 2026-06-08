//
//  DeepLAPIBillingProvider.swift
//  Costoast
//
//  Created by Codex on 2026/06/08.
//

import Foundation

struct DeepLAPIBillingProvider: BillingProvider {
    let service: BillingService = .deepLApi

    func fetchBilling(for card: BillingCard, credentials: BillingCredentials?) async throws -> BillingProviderResult {
        guard let apiKey = credentials?.deepLApiKey?.trimmingCharacters(in: .whitespacesAndNewlines), !apiKey.isEmpty else {
            throw BillingProviderError.notConfigured("DeepL API key is not configured.")
        }
        guard let configuration = card.deepLAPIConfiguration else {
            throw BillingProviderError.notConfigured("DeepL API pricing settings are not configured.")
        }

        let baseURL = configuration.apiPlanType == .free ? "https://api-free.deepl.com" : "https://api.deepl.com"
        guard let url = URL(string: "\(baseURL)/v2/usage") else {
            throw BillingProviderError.network("DeepL API usage URL could not be built.")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("DeepL-Auth-Key \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw BillingProviderError.network("DeepL API returned an invalid response.")
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            let message = FlexibleJSON.message(from: data) ?? "DeepL API request failed with status \(httpResponse.statusCode)."
            if httpResponse.statusCode == 401 || httpResponse.statusCode == 403 {
                throw BillingProviderError.authentication(message)
            }
            throw BillingProviderError.network(message)
        }

        let usage = try JSONDecoder().decode(DeepLAPIUsageResponse.self, from: data)
        let estimate = configuration.estimatedCost(usedCharacters: usage.usedCharacters)
        let usageMessage = usage.message

        return BillingProviderResult(
            periodStart: usage.startTime,
            periodEnd: usage.endTime,
            nextBillingDate: usage.endTime,
            originalAmount: estimate,
            amountKind: estimate == nil ? .unavailable : .estimated,
            fetchedAt: Date(),
            dataFreshness: .delayed,
            message: estimate == nil ? "\(usageMessage). Cost estimate unavailable." : usageMessage
        )
    }
}

private struct DeepLAPIUsageResponse: Decodable {
    var characterCount: Int?
    var characterLimit: Int?
    var apiKeyCharacterCount: Int?
    var apiKeyCharacterLimit: Int?
    var startTimeValue: String?
    var endTimeValue: String?
    var products: [DeepLAPIProductUsage]?

    enum CodingKeys: String, CodingKey {
        case characterCount = "character_count"
        case characterLimit = "character_limit"
        case apiKeyCharacterCount = "api_key_character_count"
        case apiKeyCharacterLimit = "api_key_character_limit"
        case startTimeValue = "start_time"
        case endTimeValue = "end_time"
        case products
    }

    var usedCharacters: Int {
        apiKeyCharacterCount ?? products?.compactMap(\.apiKeyCharacterCount).reduce(0, +) ?? characterCount ?? 0
    }

    var limitCharacters: Int? {
        let limit = apiKeyCharacterLimit ?? characterLimit
        return limit == 1_000_000_000_000 ? nil : limit
    }

    var startTime: Date? {
        startTimeValue.flatMap(Date.flexibleAPIDate)
    }

    var endTime: Date? {
        endTimeValue.flatMap(Date.flexibleAPIDate)
    }

    var message: String {
        if let limitCharacters {
            return "Characters: \(usedCharacters) / \(limitCharacters)"
        }
        return "Characters: \(usedCharacters)"
    }
}

private struct DeepLAPIProductUsage: Decodable {
    var apiKeyCharacterCount: Int?
    var characterCount: Int?

    enum CodingKeys: String, CodingKey {
        case apiKeyCharacterCount = "api_key_character_count"
        case characterCount = "character_count"
    }
}

private extension DeepLAPIBillingConfiguration {
    func estimatedCost(usedCharacters: Int) -> Money? {
        guard apiPlanType != .free, let monthlyBaseAmount else {
            return nil
        }

        var total = monthlyBaseAmount
        if
            let includedCharacters,
            let overageUnitCharacters,
            let overageUnitAmount,
            usedCharacters > includedCharacters,
            monthlyBaseCurrency == overageCurrency
        {
            let overageCharacters = usedCharacters - includedCharacters
            let units = (overageCharacters + overageUnitCharacters - 1) / overageUnitCharacters
            total += Decimal(units) * overageUnitAmount
        }

        return Money(value: total, currency: monthlyBaseCurrency)
    }
}
