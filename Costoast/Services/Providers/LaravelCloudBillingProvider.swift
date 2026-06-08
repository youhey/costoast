//
//  LaravelCloudBillingProvider.swift
//  Costoast
//
//  Created by Codex on 2026/06/08.
//

import Foundation
import os

struct LaravelCloudBillingProvider: BillingProvider {
    private static let logger = Logger(subsystem: "youhey.Costoast", category: "LaravelCloudBillingProvider")
    private static let debugBodyCharacterLimit = 4_000

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
        Self.logger.debug("Laravel Cloud usage response received. status=\(httpResponse.statusCode, privacy: .public) bodyBytes=\(data.count, privacy: .public)")

        guard (200..<300).contains(httpResponse.statusCode) else {
            let message = FlexibleJSON.message(from: data) ?? "Laravel Cloud request failed with status \(httpResponse.statusCode)."
            Self.logger.debug("Laravel Cloud usage request failed. status=\(httpResponse.statusCode, privacy: .public) body=\(Self.debugBodySnippet(from: data), privacy: .public)")
            if httpResponse.statusCode == 401 || httpResponse.statusCode == 403 {
                throw BillingProviderError.authentication("Failed to fetch Laravel Cloud usage. Check API token and organization permissions. \(message)")
            }
            throw BillingProviderError.network(message)
        }

        do {
            let usage = try JSONDecoder().decode(LaravelCloudUsageResponse.self, from: data)
            if let result = usage.billingResult() {
                Self.logger.debug("Laravel Cloud usage decoded. status=\(httpResponse.statusCode, privacy: .public) currentSpendCents=\(String(describing: usage.data?.summary?.currentSpendCents), privacy: .public) currency=\(String(describing: usage.meta?.currency), privacy: .public) periodStart=\(String(describing: result.periodStart), privacy: .public) periodEnd=\(String(describing: result.periodEnd), privacy: .public)")
                return result
            }
        } catch {
            Self.logger.debug("Laravel Cloud usage typed decode failed. status=\(httpResponse.statusCode, privacy: .public) error=\(String(describing: error), privacy: .public)")
        }

        guard let object = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            Self.logger.debug("Laravel Cloud usage JSON parse failed. status=\(httpResponse.statusCode, privacy: .public) body=\(Self.debugBodySnippet(from: data), privacy: .public)")
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

        Self.logger.debug("Laravel Cloud usage parsed fields. status=\(httpResponse.statusCode, privacy: .public) topLevelKeys=\(Self.topLevelKeys(in: object), privacy: .public) amount=\(String(describing: amount), privacy: .public) currency=\(String(describing: currency), privacy: .public) periodStart=\(String(describing: periodStart), privacy: .public) periodEnd=\(String(describing: periodEnd), privacy: .public)")

        guard let amount, let currency else {
            Self.logger.debug("Laravel Cloud usage amount or currency unavailable. status=\(httpResponse.statusCode, privacy: .public) body=\(Self.debugBodySnippet(from: data), privacy: .public)")
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

    private static func topLevelKeys(in object: [String: Any]) -> String {
        object.keys.sorted().joined(separator: ",")
    }

    private static func debugBodySnippet(from data: Data) -> String {
        let body: String
        if let object = try? JSONSerialization.jsonObject(with: data),
           let prettyData = try? JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted, .sortedKeys]),
           let prettyString = String(data: prettyData, encoding: .utf8) {
            body = prettyString
        } else {
            body = String(data: data, encoding: .utf8) ?? "<non-utf8 body>"
        }

        guard body.count > debugBodyCharacterLimit else {
            return body
        }

        return "\(body.prefix(debugBodyCharacterLimit))...<truncated>"
    }
}

private struct LaravelCloudUsageResponse: Decodable {
    var data: Payload?
    var meta: Meta?

    func billingResult() -> BillingProviderResult? {
        guard
            let currentSpendCents = data?.summary?.currentSpendCents,
            let currency = meta?.currency.flatMap(CurrencyCode.init(externalValue:))
        else {
            return nil
        }

        let period = currentPeriod()
        return BillingProviderResult(
            periodStart: period?.start,
            periodEnd: period?.end,
            nextBillingDate: period?.nextBillingDate,
            originalAmount: Money(value: Self.decimal(cents: currentSpendCents), currency: currency),
            amountKind: .usageToDate,
            fetchedAt: Date(),
            dataFreshness: .hourly,
            message: nil
        )
    }

    private func currentPeriod() -> (start: Date, end: Date, nextBillingDate: Date?)? {
        guard let period = meta?.availablePeriods?.first(where: { $0.current }) ?? meta?.availablePeriods?.first else {
            return nil
        }
        return period.dateRange(referenceDate: meta?.lastUpdatedAt.flatMap(Date.flexibleAPIDate) ?? Date())
    }

    private static func decimal(cents: Int) -> Decimal {
        NSDecimalNumber(value: cents).dividing(by: NSDecimalNumber(value: 100)).decimalValue
    }

    struct Payload: Decodable {
        var summary: Summary?
    }

    struct Summary: Decodable {
        var currentSpendCents: Int?

        enum CodingKeys: String, CodingKey {
            case currentSpendCents = "current_spend_cents"
        }
    }

    struct Meta: Decodable {
        var availablePeriods: [AvailablePeriod]?
        var currency: String?
        var lastUpdatedAt: String?

        enum CodingKeys: String, CodingKey {
            case availablePeriods = "available_periods"
            case currency
            case lastUpdatedAt = "last_updated_at"
        }
    }

    struct AvailablePeriod: Decodable {
        var current: Bool
        var from: String
        var to: String

        func dateRange(referenceDate: Date, calendar: Calendar = .gregorianUTC) -> (start: Date, end: Date, nextBillingDate: Date?)? {
            guard let fromComponents = Self.monthDayComponents(from), let toComponents = Self.monthDayComponents(to) else {
                return nil
            }

            let referenceYear = calendar.component(.year, from: referenceDate)
            let referenceMonth = calendar.component(.month, from: referenceDate)
            let crossesYear = toComponents.month < fromComponents.month
            let startYear: Int
            let endYear: Int

            if crossesYear, referenceMonth <= toComponents.month {
                startYear = referenceYear - 1
                endYear = referenceYear
            } else {
                startYear = referenceYear
                endYear = crossesYear ? referenceYear + 1 : referenceYear
            }

            guard
                let start = calendar.date(from: DateComponents(year: startYear, month: fromComponents.month, day: fromComponents.day)),
                let end = calendar.date(from: DateComponents(year: endYear, month: toComponents.month, day: toComponents.day))
            else {
                return nil
            }

            return (start, end, calendar.date(byAdding: .day, value: 1, to: end))
        }

        private static func monthDayComponents(_ string: String) -> (month: Int, day: Int)? {
            let formatter = DateFormatter()
            formatter.calendar = .gregorianUTC
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.timeZone = TimeZone(secondsFromGMT: 0)
            formatter.dateFormat = "MMM d yyyy"

            guard let date = formatter.date(from: "\(string) 2000") else {
                return nil
            }

            let components = Calendar.gregorianUTC.dateComponents([.month, .day], from: date)
            guard let month = components.month, let day = components.day else {
                return nil
            }
            return (month, day)
        }
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

private extension Calendar {
    static var gregorianUTC: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "en_US_POSIX")
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .current
        return calendar
    }
}
