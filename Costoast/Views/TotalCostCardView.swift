//
//  TotalCostCardView.swift
//  Costoast
//
//  Created by 池田洋平 on 2026/06/08.
//

import SwiftUI

struct TotalCostCardView: View {
    let summary: TotalCostSummary

    var body: some View {
        HStack(alignment: .center, spacing: 18) {
            symbolView

            VStack(alignment: .leading, spacing: 10) {
                Text("Total for \(Self.monthNameFormatter.string(from: Date()))")
                    .font(.headline)

                HStack(alignment: .firstTextBaseline, spacing: 14) {
                    Text(BillingCardFormat.jpy(summary.totalJPY))
                        .font(.system(size: 20, weight: .semibold))

                    if summary.activeCardCount == 0 {
                        Text("No billing cards yet.")
                            .foregroundStyle(.secondary)
                    } else if summary.excludedCardCount == 0 {
                        Text("(Based on \(summary.activeCardCount) \(cardLabel(summary.activeCardCount)))")
                            .foregroundStyle(.secondary)
                    } else {
                        Text("(Based on \(summary.includedCardCount) of \(summary.activeCardCount) \(cardLabel(summary.activeCardCount)))")
                            .foregroundStyle(.secondary)
                        Text("(\(summary.excludedCardCount) \(cardLabel(summary.excludedCardCount)) excluded from total)")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .font(.body)
            .frame(width: 310, alignment: .leading)

            groupTotalsView
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(summaryBackground, in: RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(.quaternary, lineWidth: 1)
        }
    }

    private var symbolView: some View {
        Image(systemName: "sum")
            .font(.system(size: 30, weight: .semibold))
            .foregroundStyle(.secondary)
            .frame(width: 46, height: 46)
            .frame(width: 78)
            .frame(maxHeight: .infinity)
            .padding(.vertical, 8)
            .background(Color.primary.opacity(0.035), in: RoundedRectangle(cornerRadius: 8))
            .accessibilityHidden(true)
    }

    private var summaryBackground: Color {
        Color(red: 0.18, green: 0.16, blue: 0.14)
    }

    private var groupTotalsView: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                groupTotalBadge(for: .cloudDev)
                groupTotalBadge(for: .entertainment)
            }
            HStack(spacing: 8) {
                groupTotalBadge(for: .lifestyle)
                groupTotalBadge(for: .shopping)
            }
        }
        .frame(maxWidth: .infinity, alignment: .trailing)
    }

    private func groupTotalBadge(for group: BillingServiceGroup) -> some View {
        HStack(spacing: 8) {
            Text(group.displayName)
                .lineLimit(1)
            Spacer(minLength: 8)
            Text(BillingCardFormat.jpy(summary.groupTotalsJPY[group] ?? .zero))
                .fontWeight(.semibold)
                .lineLimit(1)
        }
        .font(.caption)
        .foregroundStyle(group.badgeColor)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .frame(width: 168)
        .overlay {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .stroke(group.badgeColor.opacity(0.75), lineWidth: 1)
        }
    }

    private func cardLabel(_ count: Int) -> String {
        count == 1 ? "card" : "cards"
    }

    private static let monthNameFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "MMMM"
        return formatter
    }()
}

#Preview {
    TotalCostCardView(
        summary: TotalCostSummary(
            totalJPY: 18420,
            groupTotalsJPY: [
                .cloudDev: 123456,
                .entertainment: 23456,
                .lifestyle: 3456,
                .shopping: 456
            ],
            activeCardCount: 4,
            includedCardCount: 3,
            excludedCardCount: 1,
            rateFetchedAt: Date(),
            sourceName: "Frankfurter",
            hasConversionErrors: false
        )
    )
    .padding()
    .frame(width: 800)
}

private extension BillingServiceGroup {
    var badgeColor: Color {
        switch self {
        case .cloudDev:
            .blue
        case .entertainment:
            .pink
        case .lifestyle:
            .green
        case .shopping:
            .orange
        case .manual:
            .gray
        }
    }
}
