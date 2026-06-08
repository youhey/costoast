//
//  DashboardView.swift
//  Costoast
//
//  Created by 池田洋平 on 2026/06/08.
//

import SwiftUI
import UniformTypeIdentifiers

struct DashboardView: View {
    private let credentialStore: CredentialStore
    private let providerRegistry: BillingProviderRegistry
    private let exchangeRateProvider: ExchangeRateProvider
    private let conversionService: CurrencyConversionService
    private let totalCostCalculator: TotalCostCalculator

    @StateObject private var store: BillingCardStore
    @State private var formPresentation: BillingCardFormPresentation?
    @State private var cardPendingDeletion: BillingCard?
    @State private var draggedCard: BillingCard?
    @State private var refreshingCardIDs: Set<UUID> = []
    @State private var isRefreshingAll = false
    @State private var isRefreshAllHovered = false
    @State private var isAddHovered = false

    init() {
        let credentialStore = CredentialStore()
        self.credentialStore = credentialStore
        self.providerRegistry = BillingProviderRegistry()
        self.exchangeRateProvider = FrankfurterExchangeRateProvider()
        self.conversionService = CurrencyConversionService()
        self.totalCostCalculator = TotalCostCalculator()
        _store = StateObject(wrappedValue: BillingCardStore(credentialStore: credentialStore))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 28) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Costoast")
                        .font(.system(size: 34, weight: .semibold, design: .rounded))

                    Text("Your costs, served fresh.")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                HStack(spacing: 8) {
                    Button(action: refreshAll) {
                        Label(isRefreshingAll ? "Refreshing" : "Refresh All", systemImage: "arrow.clockwise")
                    }
                    .buttonStyle(DashboardActionButtonStyle(isHovered: isRefreshAllHovered))
                    .disabled(isRefreshingAll || store.cards.isEmpty)
                    .accessibilityLabel("Refresh All")
                    .help("Refresh All")
                    .onHover { isRefreshAllHovered = $0 }

                    Button(action: presentAddForm) {
                        Label("Add", systemImage: "plus")
                    }
                    .buttonStyle(DashboardActionButtonStyle(isHovered: isAddHovered))
                    .accessibilityLabel("Add Card")
                    .help("Add Card")
                    .onHover { isAddHovered = $0 }
                }
                .padding(.top, 4)
            }

            if let storageError = store.storageError {
                Text(storageError)
                    .font(.callout)
                    .foregroundStyle(.red)
            }

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    TotalCostCardView(
                        summary: totalCostCalculator.summarize(cards: store.cards)
                    )

                    if store.cards.isEmpty {
                        EmptyDashboardView {
                            presentAddForm()
                        }
                    } else {
                        ForEach(store.cards) { card in
                            BillingCardRowView(
                                card: card,
                                isRefreshing: refreshingCardIDs.contains(card.id),
                                onRefresh: {
                                    refresh(card)
                                },
                                onEdit: {
                                    presentEditForm(for: card)
                                },
                                onDelete: {
                                    cardPendingDeletion = card
                                }
                            )
                            .onDrag {
                                draggedCard = card
                                return NSItemProvider(object: card.id.uuidString as NSString)
                            }
                            .onDrop(
                                of: [UTType.text],
                                delegate: BillingCardDropDelegate(
                                    targetCard: card,
                                    draggedCard: $draggedCard,
                                    store: store
                                )
                            )
                        }

                        AddBillingCardView(subtitle: nil) {
                            presentAddForm()
                        }
                    }
                }
                .padding(.bottom, 2)
            }
        }
        .padding(32)
        .frame(minWidth: 640, idealWidth: 800, maxWidth: .infinity, minHeight: 360, alignment: .topLeading)
        .task {
            await refreshConversions(for: store.cards)
        }
        .sheet(item: $formPresentation) { presentation in
            BillingCardFormView(card: presentation.card, displayOrder: store.cards.count, credentialStore: credentialStore) { card in
                if presentation.card == nil {
                    store.add(card)
                } else {
                    store.update(card)
                }
                refreshConversion(for: card.id)
            }
        }
        .alert(
            "Delete this billing card?",
            isPresented: Binding(
                get: { cardPendingDeletion != nil },
                set: { isPresented in
                    if !isPresented {
                        cardPendingDeletion = nil
                    }
                }
            ),
            presenting: cardPendingDeletion
        ) { card in
            Button("Delete", role: .destructive) {
                store.delete(card)
                cardPendingDeletion = nil
            }
            Button("Cancel", role: .cancel) {
                cardPendingDeletion = nil
            }
        } message: { _ in
            Text("This action cannot be undone.")
        }
    }

    private func presentAddForm() {
        formPresentation = BillingCardFormPresentation(card: nil)
    }

    private func presentEditForm(for card: BillingCard) {
        formPresentation = BillingCardFormPresentation(card: card)
    }

    private func refresh(_ card: BillingCard) {
        refreshingCardIDs.insert(card.id)

        Task {
            await refreshBilling(for: card)
            let cards = await MainActor.run {
                store.cards.filter { $0.id == card.id }
            }
            await refreshConversions(for: cards)
            await MainActor.run {
                _ = refreshingCardIDs.remove(card.id)
            }
        }
    }

    private func refreshConversion(for cardID: UUID) {
        Task {
            let cards = await MainActor.run {
                store.cards.filter { $0.id == cardID }
            }
            await refreshConversions(for: cards)
        }
    }

    private func refreshAll() {
        let cards = store.cards
        guard !cards.isEmpty else {
            return
        }

        isRefreshingAll = true
        refreshingCardIDs = Set(cards.map(\.id))

        Task {
            for card in cards {
                await refreshBilling(for: card)
            }

            let updatedCards = await MainActor.run {
                store.cards
            }
            await refreshConversions(for: updatedCards)

            await MainActor.run {
                refreshingCardIDs.removeAll()
                isRefreshingAll = false
            }
        }
    }

    private func refreshBilling(for card: BillingCard) async {
        do {
            let credentials = try credentialStore.loadCredentials(for: card.id)
            let provider = providerRegistry.provider(for: card)
            let result = try await provider.fetchBilling(for: card, credentials: credentials)
            await MainActor.run {
                store.updateBillingResult(result, for: card.id)
            }
        } catch {
            await MainActor.run {
                store.updateBillingError(error.localizedDescription, for: card.id)
            }
        }
    }

    private func refreshConversions(for cards: [BillingCard]) async {
        guard !cards.isEmpty else {
            return
        }

        let convertibleCards = cards.filter { $0.totalEligibleOriginalAmount != nil }
        let nonConvertibleCardIDs = cards
            .filter { $0.totalEligibleOriginalAmount == nil }
            .map(\.id)

        for cardID in nonConvertibleCardIDs {
            await MainActor.run {
                store.updateConversion(nil, errorMessage: nil, for: cardID)
            }
        }

        guard !convertibleCards.isEmpty else {
            return
        }

        do {
            let snapshot = try await exchangeRateProvider.fetchRates(base: .jpy)
            for card in convertibleCards {
                guard let originalAmount = card.totalEligibleOriginalAmount else {
                    continue
                }

                do {
                    let convertedAmount = try conversionService.convertToJPY(amount: originalAmount, using: snapshot)
                    await MainActor.run {
                        store.updateConversion(convertedAmount, errorMessage: nil, for: card.id)
                    }
                } catch {
                    await MainActor.run {
                        store.updateConversion(nil, errorMessage: error.localizedDescription, for: card.id)
                    }
                }
            }
        } catch {
            await MainActor.run {
                store.updateConversionErrors("FX rate unavailable", for: convertibleCards.map(\.id))
            }
        }
    }
}

#Preview {
    DashboardView()
}

private struct BillingCardFormPresentation: Identifiable {
    let id = UUID()
    let card: BillingCard?
}
