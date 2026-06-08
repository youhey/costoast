//
//  LaravelCloudBillingProvider.swift
//  Costoast
//
//  Created by Codex on 2026/06/08.
//

import Foundation

struct LaravelCloudBillingProvider: BillingProvider {
    let service: BillingService = .laravelCloud

    func fetchBilling(for card: BillingCard, credentials: BillingCredentials?) async throws -> BillingProviderResult {
        guard let apiToken = credentials?.laravelCloudApiToken?.trimmingCharacters(in: .whitespacesAndNewlines), !apiToken.isEmpty else {
            throw BillingProviderError.notConfigured("Laravel Cloud API token is not configured.")
        }

        guard let url = URL(string: "https://cloud.laravel.com/api/usage") else {
            throw BillingProviderError.network("Laravel Cloud usage URL could not be built.")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(apiToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw BillingProviderError.network("Laravel Cloud returned an invalid response.")
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            let message = FlexibleJSON.message(from: data) ?? "Laravel Cloud request failed with status \(httpResponse.statusCode)."
            if httpResponse.statusCode == 401 || httpResponse.statusCode == 403 {
                throw BillingProviderError.authentication("Failed to fetch Laravel Cloud usage. Check API token and organization permissions. \(message)")
            }
            throw BillingProviderError.network(message)
        }

        guard let object = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw BillingProviderError.parseFailure("Laravel Cloud usage response could not be parsed.")
        }

        let amount = FlexibleJSON.findDecimal(in: object, keys: [
            "current_spend",
            "currentSpend",
            "current_usage",
            "currentUsage",
            "total_spend",
            "totalSpend",
            "spend",
            "amount",
            "cost",
            "total"
        ])
        let currency = FlexibleJSON.findString(in: object, keys: ["currency", "currency_code", "currencyCode"])
            .flatMap(CurrencyCode.init(externalValue:))
        let periodStart = FlexibleJSON.findString(in: object, keys: ["period_start", "periodStart", "billing_period_start", "billingPeriodStart", "start"])
            .flatMap(Date.flexibleAPIDate)
        let periodEnd = FlexibleJSON.findString(in: object, keys: ["period_end", "periodEnd", "billing_period_end", "billingPeriodEnd", "end"])
            .flatMap(Date.flexibleAPIDate)

        guard let amount, let currency else {
            return BillingProviderResult(
                periodStart: periodStart,
                periodEnd: periodEnd,
                nextBillingDate: periodEnd,
                originalAmount: nil,
                amountKind: .unavailable,
                fetchedAt: Date(),
                dataFreshness: .hourly,
                message: "Laravel Cloud usage amount or currency is unavailable."
            )
        }

        return BillingProviderResult(
            periodStart: periodStart,
            periodEnd: periodEnd,
            nextBillingDate: periodEnd,
            originalAmount: Money(value: amount, currency: currency),
            amountKind: .usageToDate,
            fetchedAt: Date(),
            dataFreshness: .hourly,
            message: nil
        )
    }
}

enum FlexibleJSON {
    static func findDecimal(in value: Any, keys: Set<String>) -> Decimal? {
        if let dictionary = value as? [String: Any] {
            for (key, value) in dictionary where keys.contains(key) {
                if let decimal = decimal(from: value) {
                    return decimal
                }
            }
            for value in dictionary.values {
                if let decimal = findDecimal(in: value, keys: keys) {
                    return decimal
                }
            }
        } else if let array = value as? [Any] {
            for value in array {
                if let decimal = findDecimal(in: value, keys: keys) {
                    return decimal
                }
            }
        }

        return nil
    }

    static func findString(in value: Any, keys: Set<String>) -> String? {
        if let dictionary = value as? [String: Any] {
            for (key, value) in dictionary where keys.contains(key) {
                if let string = value as? String, !string.isEmpty {
                    return string
                }
            }
            for value in dictionary.values {
                if let string = findString(in: value, keys: keys) {
                    return string
                }
            }
        } else if let array = value as? [Any] {
            for value in array {
                if let string = findString(in: value, keys: keys) {
                    return string
                }
            }
        }

        return nil
    }

    static func message(from data: Data) -> String? {
        guard let object = try? JSONSerialization.jsonObject(with: data) else {
            return nil
        }

        return findString(in: object, keys: ["message", "error", "detail"])
    }

    private static func decimal(from value: Any) -> Decimal? {
        if let decimal = value as? Decimal {
            return decimal
        }
        if let number = value as? NSNumber {
            return number.decimalValue
        }
        if let string = value as? String {
            return Decimal(string: string, locale: Locale(identifier: "en_US_POSIX"))
        }
        if let dictionary = value as? [String: Any] {
            return findDecimal(in: dictionary, keys: ["value", "amount"])
        }

        return nil
    }
}

extension Date {
    nonisolated static func flexibleAPIDate(_ string: String) -> Date? {
        let fractionalFormatter = ISO8601DateFormatter()
        fractionalFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        if let date = fractionalFormatter.date(from: string) ?? formatter.date(from: string) {
            return date
        }

        let dateOnlyFormatter = DateFormatter()
        dateOnlyFormatter.calendar = Calendar(identifier: .gregorian)
        dateOnlyFormatter.locale = Locale(identifier: "en_US_POSIX")
        dateOnlyFormatter.timeZone = TimeZone(secondsFromGMT: 0)
        dateOnlyFormatter.dateFormat = "yyyy-MM-dd"
        return dateOnlyFormatter.date(from: string)
    }
}
