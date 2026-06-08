//
//  DashboardView.swift
//  Costoast
//
//  Created by 池田洋平 on 2026/06/08.
//

import SwiftUI

struct DashboardView: View {
    private let credentialStore: CredentialStore
    private let providerRegistry: BillingProviderRegistry
    private let exchangeRateProvider: ExchangeRateProvider
    private let conversionService: CurrencyConversionService
    private let totalCostCalculator: TotalCostCalculator
    private let userDefaults: UserDefaults

    @StateObject private var store: BillingCardStore
    @State private var formPresentation: BillingCardFormPresentation?
    @State private var cardPendingDeletion: BillingCard?
    @State private var preferences: DashboardPreferences
    @State private var refreshingCardIDs: Set<UUID> = []
    @State private var isRefreshingAll = false
    @State private var isRefreshAllHovered = false
    @State private var isSaveOrderHovered = false
    @State private var isAddHovered = false
    @State private var hoveredReorderCardID: UUID?

    init(userDefaults: UserDefaults = CostoastUserDefaults.current) {
        let credentialStore = CredentialStore()
        self.credentialStore = credentialStore
        self.providerRegistry = BillingProviderRegistry()
        self.exchangeRateProvider = FrankfurterExchangeRateProvider()
        self.conversionService = CurrencyConversionService()
        self.totalCostCalculator = TotalCostCalculator()
        self.userDefaults = userDefaults
        _store = StateObject(wrappedValue: BillingCardStore(userDefaults: userDefaults, credentialStore: credentialStore))
        _preferences = State(initialValue: DashboardPreferencesStore.load(userDefaults: userDefaults))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if let storageError = store.storageError {
                Text(storageError)
                    .font(.callout)
                    .foregroundStyle(.red)
            }

            TotalCostCardView(
                summary: totalCostCalculator.summarize(cards: store.cards)
            )

            DottedSeparator()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if store.cards.isEmpty {
                        EmptyDashboardView {
                            presentAddForm()
                        }
                    } else if preferences.viewMode == .compact {
                        compactCardList
                    } else {
                        billingCardList
                    }
                }
                .padding(.bottom, 2)
            }
        }
        .padding(.horizontal, 32)
        .padding(.top, 24)
        .padding(.bottom, 32)
        .frame(minWidth: 640, idealWidth: 800, maxWidth: .infinity, minHeight: 360, alignment: .topLeading)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                HStack(spacing: 8) {
                    Picker("Sort", selection: sortModeBinding) {
                        ForEach(CardSortMode.allCases) { sortMode in
                            Text(sortMode.displayName)
                                .tag(sortMode)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(width: 136)
                    .help(sortModeHelpText)
                    .disabled(store.cards.isEmpty)

                    Picker("View", selection: viewModeBinding) {
                        ForEach(DashboardViewMode.allCases) { viewMode in
                            Text(viewMode.displayName)
                                .tag(viewMode)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 152)
                    .help("Switch dashboard view.")
                    .disabled(store.cards.isEmpty)

                    if preferences.sortMode != .custom {
                        Button(action: saveAsCustomOrder) {
                            Label("Save as Custom Order", systemImage: "arrow.down.doc")
                        }
                        .buttonStyle(DashboardActionButtonStyle(isHovered: isSaveOrderHovered))
                        .disabled(store.cards.isEmpty)
                        .accessibilityLabel("Save as Custom Order")
                        .help("Save the current sorted order and switch to Custom Order.")
                        .onHover { isSaveOrderHovered = $0 }
                    }

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
                .fixedSize()
            }
        }
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

    private var sortModeBinding: Binding<CardSortMode> {
        Binding(
            get: { preferences.sortMode },
            set: { setSortMode($0) }
        )
    }

    private var viewModeBinding: Binding<DashboardViewMode> {
        Binding(
            get: { preferences.viewMode },
            set: { setViewMode($0) }
        )
    }

    @ViewBuilder
    private var billingCardList: some View {
        ForEach(sortedCards) { card in
            billingCardRow(for: card)
        }

        AddBillingCardView(subtitle: nil) {
            presentAddForm()
        }
    }

    @ViewBuilder
    private var compactCardList: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(sortedCards) { card in
                CompactBillingCardRowView(card: card)
            }
        }
    }

    private var sortedCards: [BillingCard] {
        sortedCards(from: store.cards, mode: preferences.sortMode)
    }

    private var sortModeHelpText: String {
        if preferences.sortMode == .custom {
            return "Custom Order. Drag cards to rearrange them."
        }

        return "Sorted by \(preferences.sortMode.displayName). Switch to Custom Order to rearrange cards."
    }

    @ViewBuilder
    private func billingCardRow(for card: BillingCard) -> some View {
        let row = BillingCardRowView(
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

        if preferences.sortMode == .custom {
            row
                .contentShape(Rectangle())
                .onHover { isHovered in
                    hoveredReorderCardID = isHovered ? card.id : nil
                }
                .background {
                    BillingCardReorderDropTarget(cardID: card.id) { sourceCardID in
                        moveCard(sourceCardID, to: card)
                    }
                }
                .overlay(alignment: .leading) {
                    dragHandle(for: card)
                }
        } else {
            row
        }
    }

    @ViewBuilder
    private func dragHandle(for card: BillingCard) -> some View {
        if shouldShowDragHandle(for: card) {
            BillingCardReorderDragHandle(cardID: card.id, serviceName: card.service.displayName)
                .frame(width: 26, height: 38)
                .padding(.leading, 10)
                .transition(.opacity)
        }
    }

    private func shouldShowDragHandle(for card: BillingCard) -> Bool {
        hoveredReorderCardID == card.id || ProcessInfo.processInfo.environment["COSTOAST_UI_TEST_SEED_REORDER"] == "1"
    }

    private func moveCard(_ sourceCardID: UUID, to targetCard: BillingCard) {
        guard
            sourceCardID != targetCard.id,
            let sourceIndex = store.cards.firstIndex(where: { $0.id == sourceCardID }),
            let destinationIndex = store.cards.firstIndex(where: { $0.id == targetCard.id })
        else {
            return
        }

        withAnimation {
            store.move(
                from: IndexSet(integer: sourceIndex),
                to: destinationIndex > sourceIndex ? destinationIndex + 1 : destinationIndex
            )
        }
    }

    private func presentAddForm() {
        formPresentation = BillingCardFormPresentation(card: nil)
    }

    private func presentEditForm(for card: BillingCard) {
        formPresentation = BillingCardFormPresentation(card: card)
    }

    private func setSortMode(_ sortMode: CardSortMode) {
        preferences.sortMode = sortMode
        DashboardPreferencesStore.save(preferences, userDefaults: userDefaults)
    }

    private func setViewMode(_ viewMode: DashboardViewMode) {
        preferences.viewMode = viewMode
        DashboardPreferencesStore.save(preferences, userDefaults: userDefaults)
    }

    private func saveAsCustomOrder() {
        let currentOrder = sortedCards
        withAnimation {
            store.saveCustomOrder(currentOrder)
            setSortMode(.custom)
        }
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

private struct DottedSeparator: View {
    var body: some View {
        Rectangle()
            .fill(.clear)
            .frame(height: 1)
            .overlay {
                GeometryReader { geometry in
                    Path { path in
                        path.move(to: CGPoint(x: 0, y: 0))
                        path.addLine(to: CGPoint(x: geometry.size.width, y: 0))
                    }
                    .stroke(
                        Color.pink.opacity(0.65),
                        style: StrokeStyle(
                            lineWidth: 1.5,
                            lineCap: .round,
                            dash: [1, 8]
                        )
                    )
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
    }
}

private struct BillingCardFormPresentation: Identifiable {
    let id = UUID()
    let card: BillingCard?
}

private extension DashboardView {
    func sortedCards(from cards: [BillingCard], mode: CardSortMode) -> [BillingCard] {
        switch mode {
        case .custom:
            cards.sorted(by: customOrder)
        case .nameAsc:
            cards.sorted(by: nameOrder)
        case .serviceGroup:
            cards.sorted(by: serviceGroupOrder)
        case .amountDesc:
            cards.sorted { lhs, rhs in
                amountOrder(lhs, rhs, ascending: false)
            }
        case .amountAsc:
            cards.sorted { lhs, rhs in
                amountOrder(lhs, rhs, ascending: true)
            }
        }
    }

    func customOrder(_ lhs: BillingCard, _ rhs: BillingCard) -> Bool {
        if lhs.displayOrder == rhs.displayOrder {
            return lhs.createdAt < rhs.createdAt
        }

        return lhs.displayOrder < rhs.displayOrder
    }

    func nameOrder(_ lhs: BillingCard, _ rhs: BillingCard) -> Bool {
        let comparison = lhs.name.localizedCaseInsensitiveCompare(rhs.name)
        if comparison == .orderedSame {
            return customOrder(lhs, rhs)
        }

        return comparison == .orderedAscending
    }

    func serviceGroupOrder(_ lhs: BillingCard, _ rhs: BillingCard) -> Bool {
        let lhsGroup = lhs.service.serviceGroupSortIndex
        let rhsGroup = rhs.service.serviceGroupSortIndex
        if lhsGroup == rhsGroup {
            return nameOrder(lhs, rhs)
        }

        return lhsGroup < rhsGroup
    }

    func amountOrder(_ lhs: BillingCard, _ rhs: BillingCard, ascending: Bool) -> Bool {
        let lhsAmount = lhs.currentConvertedAmount?.jpyAmount
        let rhsAmount = rhs.currentConvertedAmount?.jpyAmount

        switch (lhsAmount, rhsAmount) {
        case let (lhsAmount?, rhsAmount?):
            if lhsAmount == rhsAmount {
                return serviceGroupOrder(lhs, rhs)
            }
            return ascending ? lhsAmount < rhsAmount : lhsAmount > rhsAmount
        case (_?, nil):
            return true
        case (nil, _?):
            return false
        case (nil, nil):
            return serviceGroupOrder(lhs, rhs)
        }
    }
}

private extension BillingService {
    var serviceGroupSortIndex: Int {
        BillingServiceGroup.allCases.firstIndex { group in
            group.services.contains(self)
        } ?? BillingServiceGroup.allCases.count
    }
}
