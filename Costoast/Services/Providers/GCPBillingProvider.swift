//
//  GCPBillingProvider.swift
//  Costoast
//
//  Created by 池田洋平 on 2026/06/08.
//

import Foundation
import Security

struct GCPBillingProvider: BillingProvider {
    let service: BillingService = .gcp

    func fetchBilling(for card: BillingCard, credentials: BillingCredentials?) async throws -> BillingProviderResult {
        guard let configuration = card.gcpConfiguration else {
            throw BillingProviderError.notConfigured("GCP billing export settings are not configured.")
        }
        guard let serviceAccountJSON = credentials?.gcpServiceAccountJSON?.trimmingCharacters(in: .whitespacesAndNewlines), !serviceAccountJSON.isEmpty else {
            throw BillingProviderError.notConfigured("GCP service account JSON is not configured.")
        }

        let tableID = try GCPTableIdentifier(
            projectID: configuration.projectID,
            datasetID: configuration.datasetID,
            tableName: configuration.tableName
        )
        let period = BillingPeriodCalculator.currentMonth()
        guard let periodStart = period.start, let nextBillingDate = period.nextBillingDate, let periodEnd = period.end else {
            throw BillingProviderError.parseFailure("Billing period could not be calculated.")
        }

        let serviceAccount = try GCPServiceAccount(json: serviceAccountJSON)
        let accessToken = try await fetchAccessToken(serviceAccount: serviceAccount)
        let response = try await queryBillingExport(
            accessToken: accessToken,
            projectID: tableID.projectID,
            tableReference: tableID.qualifiedReference,
            billingAccountID: configuration.billingAccountID?.trimmedNilIfEmpty,
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
            dataFreshness: .delayed,
            message: nil
        )
    }

    private func fetchAccessToken(serviceAccount: GCPServiceAccount) async throws -> String {
        let now = Int(Date().timeIntervalSince1970)
        let header = try JSONSerialization.data(withJSONObject: [
            "alg": "RS256",
            "typ": "JWT"
        ])
        let payload = try JSONSerialization.data(withJSONObject: [
            "iss": serviceAccount.clientEmail,
            "scope": "https://www.googleapis.com/auth/bigquery",
            "aud": serviceAccount.tokenURI,
            "iat": now,
            "exp": now + 3600
        ])
        let signingInput = "\(header.base64URLEncodedString()).\(payload.base64URLEncodedString())"
        let signature = try serviceAccount.sign(Data(signingInput.utf8))
        let assertion = "\(signingInput).\(signature.base64URLEncodedString())"
        let body = FormURLEncoded.encode([
            "grant_type": "urn:ietf:params:oauth:grant-type:jwt-bearer",
            "assertion": assertion
        ])

        guard let url = URL(string: serviceAccount.tokenURI) else {
            throw BillingProviderError.network("GCP token URL could not be built.")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = body
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw BillingProviderError.network("GCP token endpoint returned an invalid response.")
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            let message = GCPErrorResponse.message(from: data) ?? "GCP token request failed with status \(httpResponse.statusCode)."
            if httpResponse.statusCode == 401 || httpResponse.statusCode == 403 {
                throw BillingProviderError.authentication(message)
            }
            throw BillingProviderError.network(message)
        }

        guard let token = try? JSONDecoder().decode(GCPTokenResponse.self, from: data).accessToken, !token.isEmpty else {
            throw BillingProviderError.parseFailure("GCP token response could not be parsed.")
        }

        return token
    }

    private func queryBillingExport(
        accessToken: String,
        projectID: String,
        tableReference: String,
        billingAccountID: String?,
        periodStart: Date,
        periodEnd: Date
    ) async throws -> GCPBigQueryResponse {
        let billingAccountFilter: String
        var queryParameters = [
            GCPQueryParameter.timestamp(name: "period_start", value: periodStart),
            GCPQueryParameter.timestamp(name: "period_end", value: periodEnd)
        ]
        if let billingAccountID {
            billingAccountFilter = "\n  AND billing_account_id = @billing_account_id"
            queryParameters.append(.string(name: "billing_account_id", value: billingAccountID))
        } else {
            billingAccountFilter = ""
        }

        let query = """
        SELECT
          currency,
          SUM(cost) AS total_cost,
          SUM(IFNULL((SELECT SUM(c.amount) FROM UNNEST(credits) c), 0)) AS total_credits
        FROM `\(tableReference)`
        WHERE usage_start_time >= @period_start
          AND usage_start_time < @period_end\(billingAccountFilter)
        GROUP BY currency
        """

        let body = GCPQueryRequest(
            query: query,
            useLegacySql: false,
            parameterMode: "NAMED",
            queryParameters: queryParameters,
            timeoutMs: 30000
        )

        guard let url = URL(string: "https://bigquery.googleapis.com/bigquery/v2/projects/\(projectID)/queries") else {
            throw BillingProviderError.network("GCP BigQuery URL could not be built.")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = try JSONEncoder().encode(body)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw BillingProviderError.network("GCP BigQuery returned an invalid response.")
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            let message = GCPErrorResponse.message(from: data) ?? "GCP BigQuery request failed with status \(httpResponse.statusCode)."
            if httpResponse.statusCode == 401 || httpResponse.statusCode == 403 {
                throw BillingProviderError.authentication(message)
            }
            throw BillingProviderError.network(message)
        }

        do {
            let response = try JSONDecoder().decode(GCPBigQueryResponse.self, from: data)
            if response.jobComplete == false {
                throw BillingProviderError.network("GCP BigQuery query did not complete before timeout.")
            }
            return response
        } catch let providerError as BillingProviderError {
            throw providerError
        } catch {
            throw BillingProviderError.parseFailure("Failed to fetch GCP billing data. Check BigQuery billing export settings.")
        }
    }
}

private struct GCPServiceAccount: Decodable {
    var clientEmail: String
    var privateKey: String
    var tokenURI: String

    enum CodingKeys: String, CodingKey {
        case clientEmail = "client_email"
        case privateKey = "private_key"
        case tokenURI = "token_uri"
    }

    init(json: String) throws {
        guard let data = json.data(using: .utf8) else {
            throw BillingProviderError.parseFailure("GCP service account JSON could not be parsed.")
        }

        do {
            self = try JSONDecoder().decode(Self.self, from: data)
        } catch {
            throw BillingProviderError.parseFailure("GCP service account JSON could not be parsed.")
        }
    }

    func sign(_ data: Data) throws -> Data {
        let der = try privateKey.pkcs8DERData()
        let attributes: [String: Any] = [
            kSecAttrKeyType as String: kSecAttrKeyTypeRSA,
            kSecAttrKeyClass as String: kSecAttrKeyClassPrivate
        ]

        var keyError: Unmanaged<CFError>?
        guard let key = SecKeyCreateWithData(der as CFData, attributes as CFDictionary, &keyError) else {
            throw BillingProviderError.parseFailure("GCP service account private key could not be loaded.")
        }

        var signError: Unmanaged<CFError>?
        guard let signature = SecKeyCreateSignature(key, .rsaSignatureMessagePKCS1v15SHA256, data as CFData, &signError) else {
            throw BillingProviderError.parseFailure("GCP service account private key could not sign the request.")
        }

        return signature as Data
    }
}

private struct GCPTableIdentifier {
    var projectID: String
    var datasetID: String
    var tableName: String

    var qualifiedReference: String {
        "\(projectID).\(datasetID).\(tableName)"
    }

    init(projectID: String, datasetID: String, tableName: String) throws {
        let projectID = projectID.trimmingCharacters(in: .whitespacesAndNewlines)
        let datasetID = datasetID.trimmingCharacters(in: .whitespacesAndNewlines)
        let tableName = tableName.trimmingCharacters(in: .whitespacesAndNewlines)

        guard Self.isValidProjectID(projectID),
              Self.isValidIdentifier(datasetID),
              Self.isValidIdentifier(tableName) else {
            throw BillingProviderError.notConfigured("GCP BigQuery project, dataset, or table name is invalid.")
        }

        self.projectID = projectID
        self.datasetID = datasetID
        self.tableName = tableName
    }

    private static func isValidProjectID(_ value: String) -> Bool {
        value.range(of: #"^[A-Za-z0-9_-]+$"#, options: .regularExpression) != nil
    }

    private static func isValidIdentifier(_ value: String) -> Bool {
        value.range(of: #"^[A-Za-z0-9_$-]+$"#, options: .regularExpression) != nil
    }
}

private struct GCPQueryRequest: Encodable {
    var query: String
    var useLegacySql: Bool
    var parameterMode: String
    var queryParameters: [GCPQueryParameter]
    var timeoutMs: Int
}

private struct GCPQueryParameter: Encodable {
    var name: String
    var parameterType: GCPQueryParameterType
    var parameterValue: GCPQueryParameterValue

    static func timestamp(name: String, value: Date) -> Self {
        Self(
            name: name,
            parameterType: GCPQueryParameterType(type: "TIMESTAMP"),
            parameterValue: GCPQueryParameterValue(value: ISO8601DateFormatter.gcpQuery.string(from: value))
        )
    }

    static func string(name: String, value: String) -> Self {
        Self(
            name: name,
            parameterType: GCPQueryParameterType(type: "STRING"),
            parameterValue: GCPQueryParameterValue(value: value)
        )
    }
}

private struct GCPQueryParameterType: Encodable {
    var type: String
}

private struct GCPQueryParameterValue: Encodable {
    var value: String
}

private struct GCPTokenResponse: Decodable {
    var accessToken: String

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
    }
}

private struct GCPBigQueryResponse: Decodable {
    var schema: GCPTableSchema?
    var rows: [GCPRow]?
    var jobComplete: Bool?

    func totalMoney() throws -> Money {
        guard let fieldNames = schema?.fields.map({ $0.name.lowercased() }), let rows, !rows.isEmpty else {
            throw BillingProviderError.amountUnavailable
        }

        guard let currencyIndex = fieldNames.firstIndex(of: "currency"),
              let totalCostIndex = fieldNames.firstIndex(of: "total_cost"),
              let totalCreditsIndex = fieldNames.firstIndex(of: "total_credits") else {
            throw BillingProviderError.parseFailure("GCP BigQuery response did not include cost columns.")
        }

        var total = Decimal.zero
        var currency: CurrencyCode?
        for row in rows {
            guard let rowCurrency = row.value(at: currencyIndex).flatMap(CurrencyCode.init(externalValue:)),
                  let totalCost = row.decimal(at: totalCostIndex),
                  let totalCredits = row.decimal(at: totalCreditsIndex) else {
                continue
            }

            if currency == nil {
                currency = rowCurrency
            }
            guard currency == rowCurrency else {
                throw BillingProviderError.parseFailure("GCP returned multiple currencies.")
            }
            total = total + totalCost + totalCredits
        }

        guard let currency else {
            throw BillingProviderError.amountUnavailable
        }

        return Money(value: total, currency: currency)
    }
}

private struct GCPTableSchema: Decodable {
    var fields: [GCPTableField]
}

private struct GCPTableField: Decodable {
    var name: String
}

private struct GCPRow: Decodable {
    var f: [GCPCell]

    func value(at index: Int) -> String? {
        guard f.indices.contains(index) else {
            return nil
        }
        return f[index].v
    }

    func decimal(at index: Int) -> Decimal? {
        value(at: index).flatMap { Decimal(string: $0, locale: Locale(identifier: "en_US_POSIX")) }
    }
}

private struct GCPCell: Decodable {
    var v: String?
}

private struct GCPErrorResponse: Decodable {
    struct ErrorBody: Decodable {
        var message: String?
    }

    var error: ErrorBody?

    static func message(from data: Data) -> String? {
        try? JSONDecoder().decode(Self.self, from: data).error?.message
    }
}

private extension String {
    func pkcs8DERData() throws -> Data {
        let base64 = replacingOccurrences(of: "-----BEGIN PRIVATE KEY-----", with: "")
            .replacingOccurrences(of: "-----END PRIVATE KEY-----", with: "")
            .replacingOccurrences(of: "\n", with: "")
            .replacingOccurrences(of: "\r", with: "")
            .replacingOccurrences(of: " ", with: "")

        guard let data = Data(base64Encoded: base64) else {
            throw BillingProviderError.parseFailure("GCP service account private key could not be decoded.")
        }

        return data
    }
}

private extension ISO8601DateFormatter {
    static let gcpQuery: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter
    }()
}
