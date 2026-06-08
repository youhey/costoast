//
//  BillingProvider.swift
//  Costoast
//
//  Created by 池田洋平 on 2026/06/08.
//

import Foundation

protocol BillingProvider {
    var service: BillingService { get }

    func fetchBilling(
        for card: BillingCard,
        credentials: BillingCredentials?
    ) async throws -> BillingProviderResult
}

enum BillingProviderError: Error, LocalizedError {
    case notConfigured(String)
    case unsupportedProvider
    case network(String)
    case authentication(String)
    case parseFailure(String)
    case amountUnavailable

    var errorDescription: String? {
        switch self {
        case .notConfigured(let message):
            message
        case .unsupportedProvider:
            "Provider is not supported yet."
        case .network(let message):
            message
        case .authentication(let message):
            message
        case .parseFailure(let message):
            message
        case .amountUnavailable:
            "Billing amount is unavailable."
        }
    }
}

struct BillingPeriod {
    var start: Date?
    var end: Date?
    var nextBillingDate: Date?
}

enum BillingPeriodCalculator {
    static func currentMonthlyPeriod(startDay: Int?, calendar: Calendar = .current, now: Date = Date()) -> BillingPeriod {
        let day = min(max(startDay ?? 1, 1), 31)
        let components = calendar.dateComponents([.year, .month, .day], from: now)
        let currentMonthStart = date(year: components.year, month: components.month, day: day, calendar: calendar)
        let periodStart: Date

        if let currentMonthStart, currentMonthStart <= now {
            periodStart = currentMonthStart
        } else {
            periodStart = calendar.date(byAdding: .month, value: -1, to: currentMonthStart ?? now) ?? now
        }

        let nextBillingDate = calendar.date(byAdding: .month, value: 1, to: periodStart)
        let periodEnd = nextBillingDate.flatMap { calendar.date(byAdding: .day, value: -1, to: $0) }
        return BillingPeriod(start: periodStart, end: periodEnd, nextBillingDate: nextBillingDate)
    }

    static func currentYearlyPeriod(startDay: Int?, calendar: Calendar = .current, now: Date = Date()) -> BillingPeriod {
        var period = currentMonthlyPeriod(startDay: startDay, calendar: calendar, now: now)
        if let start = period.start {
            let nextBillingDate = calendar.date(byAdding: .year, value: 1, to: start)
            period.nextBillingDate = nextBillingDate
            period.end = nextBillingDate.flatMap { calendar.date(byAdding: .day, value: -1, to: $0) }
        }
        return period
    }

    static func currentMonth(calendar: Calendar = .current, now: Date = Date()) -> BillingPeriod {
        let components = calendar.dateComponents([.year, .month], from: now)
        let start = date(year: components.year, month: components.month, day: 1, calendar: calendar)
        let nextMonth = start.flatMap { calendar.date(byAdding: .month, value: 1, to: $0) }
        let end = nextMonth.flatMap { calendar.date(byAdding: .day, value: -1, to: $0) }
        return BillingPeriod(start: start, end: end, nextBillingDate: nextMonth)
    }

    private static func date(year: Int?, month: Int?, day: Int, calendar: Calendar) -> Date? {
        guard let year, let month else {
            return nil
        }

        let range = calendar.range(of: .day, in: .month, for: calendar.date(from: DateComponents(year: year, month: month, day: 1)) ?? Date())
        let validDay = min(day, range?.count ?? day)
        return calendar.date(from: DateComponents(year: year, month: month, day: validDay))
    }
}
