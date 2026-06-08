//
//  AWSBillingProvider.swift
//  Costoast
//
//  Created by 池田洋平 on 2026/06/08.
//

import Foundation

struct AWSBillingProvider: BillingProvider {
    private let costExplorerRegion = "us-east-1"

    let service: BillingService = .aws

    func fetchBilling(for card: BillingCard, credentials: BillingCredentials?) async throws -> BillingProviderResult {
        guard
            let accessKeyID = credentials?.awsAccessKeyID?.trimmingCharacters(in: .whitespacesAndNewlines), !accessKeyID.isEmpty,
            let secretAccessKey = credentials?.awsSecretAccessKey?.trimmingCharacters(in: .whitespacesAndNewlines), !secretAccessKey.isEmpty
        else {
            throw BillingProviderError.notConfigured("AWS credentials are not configured.")
        }

        let period = BillingPeriodCalculator.currentMonth()
        guard let periodStart = period.start, let nextBillingDate = period.nextBillingDate, let periodEnd = period.end else {
            throw BillingProviderError.parseFailure("Billing period could not be calculated.")
        }

        let dateFormatter = DateFormatter()
        dateFormatter.calendar = Calendar(identifier: .gregorian)
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        dateFormatter.timeZone = TimeZone(secondsFromGMT: 0)
        dateFormatter.dateFormat = "yyyy-MM-dd"

        let requestBody: [String: Any] = [
            "TimePeriod": [
                "Start": dateFormatter.string(from: periodStart),
                "End": dateFormatter.string(from: nextBillingDate)
            ],
            "Granularity": "MONTHLY",
            "Metrics": ["UnblendedCost"]
        ]

        let bodyData = try JSONSerialization.data(withJSONObject: requestBody)
        var request = URLRequest(url: URL(string: "https://ce.\(costExplorerRegion).amazonaws.com/")!)
        request.httpMethod = "POST"
        request.httpBody = bodyData
        request.setValue("application/x-amz-json-1.1", forHTTPHeaderField: "Content-Type")
        request.setValue("AWSInsightsIndexService.GetCostAndUsage", forHTTPHeaderField: "X-Amz-Target")

        try AWSRequestSigner.sign(
            request: &request,
            body: bodyData,
            accessKeyID: accessKeyID,
            secretAccessKey: secretAccessKey,
            region: costExplorerRegion,
            service: "ce"
        )

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw BillingProviderError.network("AWS returned an invalid response.")
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            let message = AWSErrorResponse.message(from: data) ?? "AWS request failed with status \(httpResponse.statusCode)."
            if httpResponse.statusCode == 401 || httpResponse.statusCode == 403 {
                throw BillingProviderError.authentication(message)
            }
            throw BillingProviderError.network(message)
        }

        do {
            let costResponse = try JSONDecoder().decode(AWSCostAndUsageResponse.self, from: data)
            let money = try costResponse.totalMoney()

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
            throw BillingProviderError.parseFailure("AWS cost response could not be parsed.")
        }
    }
}

private struct AWSCostAndUsageResponse: Decodable {
    var resultsByTime: [AWSResultByTime]

    enum CodingKeys: String, CodingKey {
        case resultsByTime = "ResultsByTime"
    }

    func totalMoney() throws -> Money {
        guard
            let metric = resultsByTime.compactMap({ $0.total["UnblendedCost"] }).first,
            let amount = Decimal(string: metric.amount),
            let currency = CurrencyCode(externalValue: metric.unit)
        else {
            throw BillingProviderError.amountUnavailable
        }

        return Money(value: amount, currency: currency)
    }
}

private struct AWSResultByTime: Decodable {
    var total: [String: AWSMetricValue]

    enum CodingKeys: String, CodingKey {
        case total = "Total"
    }
}

private struct AWSMetricValue: Decodable {
    var amount: String
    var unit: String

    enum CodingKeys: String, CodingKey {
        case amount = "Amount"
        case unit = "Unit"
    }
}

private struct AWSErrorResponse: Decodable {
    var message: String?

    enum CodingKeys: String, CodingKey {
        case message = "message"
        case upperMessage = "Message"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        message = try container.decodeIfPresent(String.self, forKey: .message)
            ?? container.decodeIfPresent(String.self, forKey: .upperMessage)
    }

    static func message(from data: Data) -> String? {
        try? JSONDecoder().decode(Self.self, from: data).message
    }
}
