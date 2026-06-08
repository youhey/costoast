//
//  OpenAICodexBillingProvider.swift
//  Costoast
//
//  Created by Codex on 2026/06/08.
//

import Foundation

struct OpenAICodexBillingProvider: BillingProvider {
    let service: BillingService = .openAiCodex

    func fetchBilling(for card: BillingCard, credentials: BillingCredentials?) async throws -> BillingProviderResult {
        guard let apiKey = credentials?.apiKey?.trimmingCharacters(in: .whitespacesAndNewlines), !apiKey.isEmpty else {
            throw BillingProviderError.notConfigured("OpenAI Admin API key is not configured.")
        }

        let period = BillingPeriodCalculator.currentMonth()
        guard let periodStart = period.start else {
            throw BillingProviderError.parseFailure("Billing period could not be calculated.")
        }

        var queryItems = [
            URLQueryItem(name: "start_time", value: String(Int(periodStart.timeIntervalSince1970))),
            URLQueryItem(name: "end_time", value: String(Int((period.nextBillingDate ?? Date()).timeIntervalSince1970))),
            URLQueryItem(name: "bucket_width", value: "1d"),
            URLQueryItem(name: "limit", value: "31"),
            URLQueryItem(name: "group_by", value: "line_item"),
            URLQueryItem(name: "group_by", value: "project_id")
        ]

        if let projectID = card.openAICodexConfiguration?.projectID?.trimmedNilIfEmpty {
            queryItems.append(URLQueryItem(name: "project_ids", value: projectID))
        }

        var components = URLComponents(string: "https://api.openai.com/v1/organization/costs")
        components?.queryItems = queryItems
        guard let url = components?.url else {
            throw BillingProviderError.network("OpenAI Codex costs URL could not be built.")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        if let organizationID = card.openAICodexConfiguration?.organizationID?.trimmedNilIfEmpty ?? credentials?.organizationID?.trimmedNilIfEmpty {
            request.setValue(organizationID, forHTTPHeaderField: "OpenAI-Organization")
        }

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw BillingProviderError.network("OpenAI Codex returned an invalid response.")
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            let message = OpenAICodexErrorResponse.message(from: data) ?? "OpenAI Codex request failed with status \(httpResponse.statusCode)."
            if httpResponse.statusCode == 401 || httpResponse.statusCode == 403 {
                throw BillingProviderError.authentication(message)
            }
            throw BillingProviderError.network(message)
        }

        let costs = try JSONDecoder().decode(OpenAICodexCostsResponse.self, from: data)
        let filter = CodexCostFilter(
            lineItemFilter: card.openAICodexConfiguration?.lineItemFilter?.trimmedNilIfEmpty ?? "codex",
            projectID: card.openAICodexConfiguration?.projectID?.trimmedNilIfEmpty,
            apiKeyID: card.openAICodexConfiguration?.apiKeyID?.trimmedNilIfEmpty
        )
        let money = try costs.totalMoney(matching: filter)

        return BillingProviderResult(
            periodStart: periodStart,
            periodEnd: period.end,
            nextBillingDate: period.nextBillingDate,
            originalAmount: money,
            amountKind: money == nil ? .unavailable : .usageToDate,
            fetchedAt: Date(),
            dataFreshness: .daily,
            message: money == nil ? "No Codex cost found for the configured filters." : filter.message
        )
    }
}

private struct CodexCostFilter {
    var lineItemFilter: String?
    var projectID: String?
    var apiKeyID: String?

    var message: String? {
        if let lineItemFilter {
            return "Filter: line item contains \"\(lineItemFilter)\""
        }
        return nil
    }

    func matches(_ result: OpenAICodexCostResult) -> Bool {
        if let projectID, result.projectID != projectID {
            return false
        }
        if let apiKeyID, result.apiKeyID != apiKeyID {
            return false
        }
        if let lineItemFilter {
            guard let lineItem = result.lineItem?.lowercased() else {
                return false
            }
            return lineItem.contains(lineItemFilter.lowercased())
        }

        return projectID != nil || apiKeyID != nil
    }
}

private struct OpenAICodexCostsResponse: Decodable {
    var data: [OpenAICodexCostBucket]

    func totalMoney(matching filter: CodexCostFilter) throws -> Money? {
        var total = Decimal.zero
        var currency: CurrencyCode?
        var hasMatch = false

        for bucket in data {
            for result in bucket.results where filter.matches(result) {
                guard let amount = result.amount, let value = amount.value else {
                    continue
                }
                let resultCurrency = amount.currency.flatMap(CurrencyCode.init(externalValue:)) ?? .usd
                if currency == nil {
                    currency = resultCurrency
                }
                guard currency == resultCurrency else {
                    throw BillingProviderError.parseFailure("OpenAI Codex returned multiple currencies.")
                }
                hasMatch = true
                total += value
            }
        }

        guard hasMatch, let currency else {
            return nil
        }

        return Money(value: total, currency: currency)
    }
}

private struct OpenAICodexCostBucket: Decodable {
    var results: [OpenAICodexCostResult]
}

private struct OpenAICodexCostResult: Decodable {
    var amount: OpenAICodexCostAmount?
    var lineItem: String?
    var projectID: String?
    var apiKeyID: String?

    enum CodingKeys: String, CodingKey {
        case amount
        case lineItem = "line_item"
        case projectID = "project_id"
        case apiKeyID = "api_key_id"
    }
}

private struct OpenAICodexCostAmount: Decodable {
    var value: Decimal?
    var currency: String?

    enum CodingKeys: String, CodingKey {
        case value
        case currency
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        currency = try container.decodeIfPresent(String.self, forKey: .currency)
        if let decimal = try? container.decodeIfPresent(Decimal.self, forKey: .value) {
            value = decimal
        } else if let string = try? container.decodeIfPresent(String.self, forKey: .value) {
            value = Decimal(string: string, locale: Locale(identifier: "en_US_POSIX"))
        } else {
            value = nil
        }
    }
}

private struct OpenAICodexErrorResponse: Decodable {
    struct ErrorBody: Decodable {
        var message: String?
    }

    var error: ErrorBody?

    static func message(from data: Data) -> String? {
        try? JSONDecoder().decode(Self.self, from: data).error?.message
    }
}
