//
//  ExchangeRateProvider.swift
//  Costoast
//
//  Created by 池田洋平 on 2026/06/08.
//

import Foundation

protocol ExchangeRateProvider {
    func fetchRates(base: CurrencyCode) async throws -> ExchangeRateSnapshot
}

enum ExchangeRateProviderError: Error, LocalizedError {
    case unsupportedBaseCurrency
    case invalidURL
    case invalidResponse
    case network(String)
    case parseFailure
    case missingRate(CurrencyCode)

    var errorDescription: String? {
        switch self {
        case .unsupportedBaseCurrency:
            "Only JPY exchange snapshots are supported."
        case .invalidURL:
            "FX rate URL could not be built."
        case .invalidResponse:
            "FX rate API returned an invalid response."
        case .network(let message):
            message
        case .parseFailure:
            "FX rate response could not be parsed."
        case .missingRate(let currency):
            "FX rate for \(currency.rawValue) is unavailable."
        }
    }
}

struct FrankfurterExchangeRateProvider: ExchangeRateProvider {
    private let sourceName = "Frankfurter"

    func fetchRates(base: CurrencyCode) async throws -> ExchangeRateSnapshot {
        guard base == .jpy else {
            throw ExchangeRateProviderError.unsupportedBaseCurrency
        }

        var components = URLComponents(string: "https://api.frankfurter.dev/v1/latest")
        components?.queryItems = [
            URLQueryItem(name: "base", value: "EUR"),
            URLQueryItem(name: "symbols", value: "JPY,USD")
        ]

        guard let url = components?.url else {
            throw ExchangeRateProviderError.invalidURL
        }

        let (data, response) = try await URLSession.shared.data(from: url)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw ExchangeRateProviderError.invalidResponse
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            let message = String(data: data, encoding: .utf8) ?? "FX rate API returned HTTP \(httpResponse.statusCode)."
            throw ExchangeRateProviderError.network(message)
        }

        do {
            let decoded = try JSONDecoder().decode(FrankfurterLatestResponse.self, from: data)
            guard
                let jpyPerEUR = decoded.rate(for: .jpy),
                let usdPerEUR = decoded.rate(for: .usd),
                usdPerEUR != Decimal.zero
            else {
                throw ExchangeRateProviderError.missingRate(.jpy)
            }

            return ExchangeRateSnapshot(
                baseCurrency: .jpy,
                rates: [
                    .jpy: Decimal(1),
                    .eur: jpyPerEUR,
                    .usd: jpyPerEUR / usdPerEUR
                ],
                fetchedAt: Date(),
                sourceName: sourceName
            )
        } catch let providerError as ExchangeRateProviderError {
            throw providerError
        } catch {
            throw ExchangeRateProviderError.parseFailure
        }
    }
}

private struct FrankfurterLatestResponse: Decodable {
    var rates: [String: Decimal]

    func rate(for currency: CurrencyCode) -> Decimal? {
        rates[currency.rawValue]
    }
}
