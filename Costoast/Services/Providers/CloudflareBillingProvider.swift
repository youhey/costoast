//
//  CloudflareBillingProvider.swift
//  Costoast
//
//  Created by 池田洋平 on 2026/06/08.
//

import Foundation

struct CloudflareBillingProvider: BillingProvider {
    let service: BillingService = .cloudflare

    func fetchBilling(for card: BillingCard, credentials: BillingCredentials?) async throws -> BillingProviderResult {
        guard let configuration = card.cloudflareConfiguration else {
            throw BillingProviderError.notConfigured("Cloudflare billing settings are not configured.")
        }
        let accountID = configuration.accountID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !accountID.isEmpty else {
            throw BillingProviderError.notConfigured("Cloudflare Account ID is not configured.")
        }
        guard let apiToken = credentials?.cloudflareApiToken?.trimmingCharacters(in: .whitespacesAndNewlines), !apiToken.isEmpty else {
            throw BillingProviderError.notConfigured("Cloudflare API token is not configured.")
        }

        guard let url = URL(string: "https://api.cloudflare.com/client/v4/accounts/\(accountID)/subscriptions") else {
            throw BillingProviderError.network("Cloudflare subscriptions URL could not be built.")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(apiToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw BillingProviderError.network("Cloudflare returned an invalid response.")
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            let message = CloudflareAPIResponse.message(from: data) ?? "Cloudflare request failed with status \(httpResponse.statusCode)."
            if httpResponse.statusCode == 401 || httpResponse.statusCode == 403 {
                throw BillingProviderError.authentication("Failed to fetch Cloudflare billing data. Check API token permissions. \(message)")
            }
            throw BillingProviderError.network(message)
        }

        do {
            let response = try JSONDecoder().decode(CloudflareSubscriptionsResponse.self, from: data)
            guard response.success != false else {
                throw BillingProviderError.network(response.errorMessage ?? "Cloudflare billing data is unavailable for this account.")
            }

            return try response.billingResult()
        } catch let providerError as BillingProviderError {
            throw providerError
        } catch {
            throw BillingProviderError.parseFailure("Cloudflare billing data is unavailable for this account.")
        }
    }
}

private struct CloudflareSubscriptionsResponse: Decodable {
    var success: Bool?
    var result: [CloudflareSubscription]?
    var errors: [CloudflareAPIError]?

    var errorMessage: String? {
        errors?.compactMap(\.message).joined(separator: " ")
    }

    func billingResult() throws -> BillingProviderResult {
        let subscriptions = result ?? []
        var total = Decimal.zero
        var currency: CurrencyCode?
        var periodStart: Date?
        var periodEnd: Date?

        for subscription in subscriptions {
            guard subscription.isBillable, let price = subscription.price else {
                continue
            }

            let rowCurrency = subscription.currency ?? .usd
            if currency == nil {
                currency = rowCurrency
            }
            guard currency == rowCurrency else {
                throw BillingProviderError.parseFailure("Cloudflare returned multiple currencies.")
            }

            total += price
            periodStart = minDate(periodStart, subscription.currentPeriodStart)
            periodEnd = maxDate(periodEnd, subscription.currentPeriodEnd)
        }

        guard let currency else {
            return BillingProviderResult(
                periodStart: nil,
                periodEnd: nil,
                nextBillingDate: nil,
                originalAmount: nil,
                amountKind: .unavailable,
                fetchedAt: Date(),
                dataFreshness: .unknown,
                message: "Cloudflare billing data is unavailable for this account."
            )
        }

        return BillingProviderResult(
            periodStart: periodStart,
            periodEnd: periodEnd,
            nextBillingDate: periodEnd,
            originalAmount: Money(value: total, currency: currency),
            amountKind: .subscription,
            fetchedAt: Date(),
            dataFreshness: .unknown,
            message: nil
        )
    }

    private func minDate(_ lhs: Date?, _ rhs: Date?) -> Date? {
        guard let lhs else {
            return rhs
        }
        guard let rhs else {
            return lhs
        }
        return min(lhs, rhs)
    }

    private func maxDate(_ lhs: Date?, _ rhs: Date?) -> Date? {
        guard let lhs else {
            return rhs
        }
        guard let rhs else {
            return lhs
        }
        return max(lhs, rhs)
    }

    static func message(from data: Data) -> String? {
        try? JSONDecoder().decode(Self.self, from: data).errorMessage
    }
}

private struct CloudflareSubscription: Decodable {
    var id: String?
    var state: String?
    var price: Decimal?
    var currencyValue: String?
    var currentPeriodStartValue: String?
    var currentPeriodEndValue: String?
    var ratePlan: CloudflareRatePlan?

    enum CodingKeys: String, CodingKey {
        case id
        case state
        case price
        case currencyValue = "currency"
        case currentPeriodStartValue = "current_period_start"
        case currentPeriodEndValue = "current_period_end"
        case ratePlan = "rate_plan"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(String.self, forKey: .id)
        state = try container.decodeIfPresent(String.self, forKey: .state)
        currencyValue = try container.decodeIfPresent(String.self, forKey: .currencyValue)
        currentPeriodStartValue = try container.decodeIfPresent(String.self, forKey: .currentPeriodStartValue)
        currentPeriodEndValue = try container.decodeIfPresent(String.self, forKey: .currentPeriodEndValue)
        ratePlan = try container.decodeIfPresent(CloudflareRatePlan.self, forKey: .ratePlan)

        if let decimal = try? container.decodeIfPresent(Decimal.self, forKey: .price) {
            price = decimal
        } else if let string = try container.decodeIfPresent(String.self, forKey: .price) {
            price = Decimal(string: string, locale: Locale(identifier: "en_US_POSIX"))
        } else {
            price = nil
        }
    }

    var isBillable: Bool {
        guard let state = state?.lowercased() else {
            return true
        }

        return !["cancelled", "canceled", "expired", "deleted"].contains(state)
    }

    var currency: CurrencyCode? {
        if let currencyValue, let currency = CurrencyCode(externalValue: currencyValue) {
            return currency
        }
        if let ratePlanCurrency = ratePlan?.currency, let currency = CurrencyCode(externalValue: ratePlanCurrency) {
            return currency
        }
        return nil
    }

    var currentPeriodStart: Date? {
        currentPeriodStartValue.flatMap(Date.cloudflareDate)
    }

    var currentPeriodEnd: Date? {
        currentPeriodEndValue.flatMap(Date.cloudflareDate)
    }
}

private struct CloudflareRatePlan: Decodable {
    var currency: String?
}

private struct CloudflareAPIError: Decodable {
    var code: Int?
    var message: String?
}

private typealias CloudflareAPIResponse = CloudflareSubscriptionsResponse

private extension Date {
    nonisolated static func cloudflareDate(_ string: String) -> Date? {
        let fractionalFormatter = ISO8601DateFormatter()
        fractionalFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return fractionalFormatter.date(from: string) ?? formatter.date(from: string)
    }
}
