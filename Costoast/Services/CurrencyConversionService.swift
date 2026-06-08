//
//  CurrencyConversionService.swift
//  Costoast
//
//  Created by 池田洋平 on 2026/06/08.
//

import Foundation

final class CurrencyConversionService {
    func convertToJPY(amount: Money, using snapshot: ExchangeRateSnapshot) throws -> ConvertedAmount {
        guard snapshot.baseCurrency == .jpy else {
            throw CurrencyConversionError.unsupportedSnapshotBase
        }

        guard let rate = snapshot.rates[amount.currency] else {
            throw CurrencyConversionError.rateUnavailable(amount.currency)
        }

        return ConvertedAmount(
            original: amount,
            jpyAmount: amount.value * rate,
            rate: rate,
            rateFetchedAt: snapshot.fetchedAt,
            sourceName: snapshot.sourceName,
            isEstimated: true
        )
    }
}

enum CurrencyConversionError: Error, LocalizedError {
    case unsupportedSnapshotBase
    case rateUnavailable(CurrencyCode)

    var errorDescription: String? {
        switch self {
        case .unsupportedSnapshotBase:
            "JPY conversion snapshot is invalid."
        case .rateUnavailable(let currency):
            "FX rate for \(currency.rawValue) is unavailable."
        }
    }
}
