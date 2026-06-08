//
//  AzureBillingProvider.swift
//  Costoast
//
//  Created by 池田洋平 on 2026/06/08.
//

import Foundation

struct AzureBillingProvider: BillingProvider {
    let service: BillingService = .azure

    func fetchBilling(for card: BillingCard, credentials: BillingCredentials?) async throws -> BillingProviderResult {
        guard let configuration = card.azureConfiguration else {
            throw BillingProviderError.notConfigured("Azure billing settings are not configured.")
        }
        guard let clientSecret = credentials?.azureClientSecret?.trimmingCharacters(in: .whitespacesAndNewlines), !clientSecret.isEmpty else {
            throw BillingProviderError.notConfigured("Azure client secret is not configured.")
        }

        let tenantID = configuration.tenantID.trimmingCharacters(in: .whitespacesAndNewlines)
        let clientID = configuration.clientID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !tenantID.isEmpty else {
            throw BillingProviderError.notConfigured("Azure Tenant ID is not configured.")
        }
        guard !clientID.isEmpty else {
            throw BillingProviderError.notConfigured("Azure Client ID is not configured.")
        }

        let scope = try AzureScope(configuration: configuration).value
        let period = BillingPeriodCalculator.currentMonth()
        guard let periodStart = period.start, let nextBillingDate = period.nextBillingDate, let periodEnd = period.end else {
            throw BillingProviderError.parseFailure("Billing period could not be calculated.")
        }

        let accessToken = try await fetchAccessToken(
            tenantID: tenantID,
            clientID: clientID,
            clientSecret: clientSecret
        )
        let response = try await queryCost(
            accessToken: accessToken,
            scope: scope,
            periodStart: periodStart,
            periodEnd: nextBillingDate
        )
        let money = try response.totalMoney()

        return BillingProviderResult(
            periodStart: periodStart,
            periodEnd: periodEnd,
            nextBillingDate: nextBillingDate,
            originalAmount: money,
            amountKind: .usageToDate,
            fetchedAt: Date(),
            dataFreshness: .daily,
            message: nil
        )
    }

    private func fetchAccessToken(tenantID: String, clientID: String, clientSecret: String) async throws -> String {
        let encodedTenantID = tenantID.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? tenantID
        guard let url = URL(string: "https://login.microsoftonline.com/\(encodedTenantID)/oauth2/v2.0/token") else {
            throw BillingProviderError.network("Azure token URL could not be built.")
        }

        let body = FormURLEncoded.encode([
            "client_id": clientID,
            "client_secret": clientSecret,
            "grant_type": "client_credentials",
            "scope": "https://management.azure.com/.default"
        ])

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = body
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw BillingProviderError.network("Azure token endpoint returned an invalid response.")
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            let message = AzureErrorResponse.message(from: data) ?? "Azure token request failed with status \(httpResponse.statusCode)."
            if httpResponse.statusCode == 401 || httpResponse.statusCode == 403 {
                throw BillingProviderError.authentication(message)
            }
            throw BillingProviderError.network(message)
        }

        guard let token = try? JSONDecoder().decode(AzureTokenResponse.self, from: data).accessToken, !token.isEmpty else {
            throw BillingProviderError.parseFailure("Azure token response could not be parsed.")
        }

        return token
    }

    private func queryCost(accessToken: String, scope: String, periodStart: Date, periodEnd: Date) async throws -> AzureCostQueryResponse {
        guard let url = URL(string: "https://management.azure.com\(scope)/providers/Microsoft.CostManagement/query?api-version=2025-03-01") else {
            throw BillingProviderError.network("Azure Cost Management URL could not be built.")
        }

        let body = AzureCostQueryRequest(
            type: "ActualCost",
            timeframe: "Custom",
            timePeriod: AzureTimePeriod(
                from: ISO8601DateFormatter.azureQuery.string(from: periodStart),
                to: ISO8601DateFormatter.azureQuery.string(from: periodEnd)
            ),
            dataset: AzureDataset(
                granularity: "None",
                aggregation: [
                    "totalCost": AzureAggregation(name: "Cost", function: "Sum")
                ],
                grouping: [
                    AzureGrouping(type: "Dimension", name: "Currency")
                ]
            )
        )

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = try JSONEncoder().encode(body)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw BillingProviderError.network("Azure Cost Management returned an invalid response.")
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            let message = AzureErrorResponse.message(from: data) ?? "Azure Cost Management request failed with status \(httpResponse.statusCode)."
            if httpResponse.statusCode == 401 || httpResponse.statusCode == 403 {
                throw BillingProviderError.authentication(message)
            }
            throw BillingProviderError.network(message)
        }

        do {
            return try JSONDecoder().decode(AzureCostQueryResponse.self, from: data)
        } catch {
            throw BillingProviderError.parseFailure("Failed to fetch Azure cost data. Check tenant, client, secret, and scope.")
        }
    }
}

private struct AzureScope {
    var value: String

    init(configuration: AzureBillingConfiguration) throws {
        let explicitScope = configuration.scope?.trimmedNilIfEmpty
        let subscriptionID = configuration.subscriptionID?.trimmedNilIfEmpty

        if let explicitScope {
            guard explicitScope.hasPrefix("/") else {
                throw BillingProviderError.notConfigured("Azure Scope must start with '/'.")
            }
            value = explicitScope
        } else if let subscriptionID {
            value = "/subscriptions/\(subscriptionID)"
        } else {
            throw BillingProviderError.notConfigured("Azure Subscription ID or Scope is not configured.")
        }
    }
}

private struct AzureTokenResponse: Decodable {
    var accessToken: String

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
    }
}

private struct AzureCostQueryRequest: Encodable {
    var type: String
    var timeframe: String
    var timePeriod: AzureTimePeriod
    var dataset: AzureDataset
}

private struct AzureTimePeriod: Encodable {
    var from: String
    var to: String
}

private struct AzureDataset: Encodable {
    var granularity: String
    var aggregation: [String: AzureAggregation]
    var grouping: [AzureGrouping]
}

private struct AzureAggregation: Encodable {
    var name: String
    var function: String
}

private struct AzureGrouping: Encodable {
    var type: String
    var name: String
}

private struct AzureCostQueryResponse: Decodable {
    struct Properties: Decodable {
        var columns: [Column]
        var rows: [[AzureJSONValue]]
    }

    struct Column: Decodable {
        var name: String
    }

    var properties: Properties

    func totalMoney() throws -> Money {
        let columnNames = properties.columns.map { $0.name.lowercased() }
        guard let costIndex = columnNames.firstIndex(where: { $0.contains("cost") }) else {
            throw BillingProviderError.amountUnavailable
        }
        guard let currencyIndex = columnNames.firstIndex(where: { $0 == "currency" || $0.contains("currency") }) else {
            throw BillingProviderError.amountUnavailable
        }

        var total = Decimal.zero
        var currency: CurrencyCode?

        for row in properties.rows {
            guard row.indices.contains(costIndex), row.indices.contains(currencyIndex),
                  let cost = row[costIndex].decimal,
                  let rowCurrency = row[currencyIndex].string.flatMap(CurrencyCode.init(externalValue:)) else {
                continue
            }

            if currency == nil {
                currency = rowCurrency
            }
            guard currency == rowCurrency else {
                throw BillingProviderError.parseFailure("Azure returned multiple currencies.")
            }

            total += cost
        }

        guard let currency else {
            throw BillingProviderError.amountUnavailable
        }

        return Money(value: total, currency: currency)
    }
}

private enum AzureJSONValue: Decodable {
    case string(String)
    case number(Decimal)
    case null

    var string: String? {
        switch self {
        case .string(let value):
            value
        case .number(let value):
            NSDecimalNumber(decimal: value).stringValue
        case .null:
            nil
        }
    }

    var decimal: Decimal? {
        switch self {
        case .string(let value):
            Decimal(string: value, locale: Locale(identifier: "en_US_POSIX"))
        case .number(let value):
            value
        case .null:
            nil
        }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self = .null
        } else if let decimal = try? container.decode(Decimal.self) {
            self = .number(decimal)
        } else {
            self = .string(try container.decode(String.self))
        }
    }
}

private struct AzureErrorResponse: Decodable {
    struct ErrorBody: Decodable {
        var code: String?
        var message: String?
    }

    var error: ErrorBody?
    var errorDescription: String?

    enum CodingKeys: String, CodingKey {
        case error
        case errorDescription = "error_description"
    }

    static func message(from data: Data) -> String? {
        guard let response = try? JSONDecoder().decode(Self.self, from: data) else {
            return nil
        }

        return response.error?.message ?? response.errorDescription ?? response.error?.code
    }
}

private extension ISO8601DateFormatter {
    static let azureQuery: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter
    }()
}
