//
//  OpenAIAPIUsageProvider.swift
//  Costoast
//
//  Created by 池田洋平 on 2026/06/08.
//

import Foundation

struct OpenAIAPIUsageProvider: BillingProvider {
    let service: BillingService = .openAiApi

    func fetchBilling(for card: BillingCard, credentials: BillingCredentials?) async throws -> BillingProviderResult {
        guard let apiKey = credentials?.apiKey?.trimmingCharacters(in: .whitespacesAndNewlines), !apiKey.isEmpty else {
            throw BillingProviderError.notConfigured("OpenAI API key is not configured.")
        }

        let period = BillingPeriodCalculator.currentMonth()
        guard let periodStart = period.start, let periodEnd = period.end else {
            throw BillingProviderError.parseFailure("Billing period could not be calculated.")
        }

        var components = URLComponents(string: "https://api.openai.com/v1/organization/costs")
        components?.queryItems = [
            URLQueryItem(name: "start_time", value: String(Int(periodStart.timeIntervalSince1970))),
            URLQueryItem(name: "end_time", value: String(Int((period.nextBillingDate ?? Date()).timeIntervalSince1970))),
            URLQueryItem(name: "bucket_width", value: "1d"),
            URLQueryItem(name: "limit", value: "31")
        ]

        guard let url = components?.url else {
            throw BillingProviderError.network("OpenAI costs URL could not be built.")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        if let organizationID = credentials?.organizationID?.trimmingCharacters(in: .whitespacesAndNewlines), !organizationID.isEmpty {
            request.setValue(organizationID, forHTTPHeaderField: "OpenAI-Organization")
        }

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw BillingProviderError.network("OpenAI returned an invalid response.")
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            let message = OpenAIErrorResponse.message(from: data) ?? "OpenAI request failed with status \(httpResponse.statusCode)."
            if httpResponse.statusCode == 401 || httpResponse.statusCode == 403 {
                throw BillingProviderError.authentication(message)
            }
            throw BillingProviderError.network(message)
        }

        do {
            let costs = try JSONDecoder().decode(OpenAICostsResponse.self, from: data)
            let money = try costs.totalMoney()

            return BillingProviderResult(
                periodStart: periodStart,
                periodEnd: periodEnd,
                nextBillingDate: period.nextBillingDate,
                originalAmount: money,
                amountKind: .usageToDate,
                fetchedAt: Date(),
                dataFreshness: .daily,
                message: nil
            )
        } catch let providerError as BillingProviderError {
            throw providerError
        } catch {
            throw BillingProviderError.parseFailure("OpenAI cost response could not be parsed.")
        }
    }
}

private struct OpenAICostsResponse: Decodable {
    var data: [OpenAICostBucket]

    func totalMoney() throws -> Money {
        var total = Decimal.zero
        var currency: CurrencyCode?

        for bucket in data {
            for result in bucket.results {
                guard let amount = result.amount, let value = amount.value else {
                    continue
                }

                let resultCurrency = amount.currency.flatMap(CurrencyCode.init(externalValue:)) ?? .usd
                if currency == nil {
                    currency = resultCurrency
                }

                guard currency == resultCurrency else {
                    throw BillingProviderError.parseFailure("OpenAI returned multiple currencies.")
                }

                total += Decimal(value)
            }
        }

        guard let currency else {
            throw BillingProviderError.amountUnavailable
        }

        return Money(value: total, currency: currency)
    }
}

private struct OpenAICostBucket: Decodable {
    var results: [OpenAICostResult]
}

private struct OpenAICostResult: Decodable {
    var amount: OpenAICostAmount?
}

private struct OpenAICostAmount: Decodable {
    var value: Double?
    var currency: String?
}

private struct OpenAIErrorResponse: Decodable {
    struct ErrorBody: Decodable {
        var message: String?
    }

    var error: ErrorBody?

    static func message(from data: Data) -> String? {
        try? JSONDecoder().decode(Self.self, from: data).error?.message
    }
}
