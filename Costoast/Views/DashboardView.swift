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
    @State private var lastRefreshAllAt: Date?

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

            if preferences.viewMode == .cards && !pinnedCards.isEmpty {
                pinnedCardList

                if !sortedUnpinnedCards.isEmpty {
                    DottedSeparator(color: .gray.opacity(0.55))
                }
            }

            sortControls

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
            ToolbarItem(placement: .principal) {
                viewModePicker
            }
            ToolbarItem(placement: .primaryAction) {
                refreshControls
            }
        }
        .task {
            await refreshConversions(for: store.cards)
        }
        .task(id: preferences.autoRefreshInterval) {
            await runAutoRefreshLoop(for: preferences.autoRefreshInterval)
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

    private var autoRefreshIntervalBinding: Binding<AutoRefreshInterval> {
        Binding(
            get: { preferences.autoRefreshInterval },
            set: { setAutoRefreshInterval($0) }
        )
    }

    private var refreshControls: some View {
        HStack(spacing: 8) {
            refreshAllButton
            autoRefreshPicker
        }
        .fixedSize()
    }

    @ViewBuilder
    private var sortControls: some View {
        if preferences.viewMode == .cards && !store.cards.isEmpty {
            HStack(spacing: 8) {
                addCardButton

                Spacer(minLength: 0)

                Text("Sort")
                    .font(.callout)
                    .foregroundStyle(.secondary)

                sortPicker
                saveCustomOrderButton
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var sortPicker: some View {
        Picker("Sort", selection: sortModeBinding) {
            ForEach(CardSortMode.allCases) { sortMode in
                Text(sortMode.displayName)
                    .tag(sortMode)
            }
        }
        .labelsHidden()
        .pickerStyle(.menu)
        .frame(width: 136)
        .help(sortModeHelpText)
        .disabled(store.cards.isEmpty)
    }

    private var saveCustomOrderButton: some View {
        Button(action: saveAsCustomOrder) {
            Image(systemName: "square.and.arrow.down")
                .frame(width: 16, height: 16)
        }
        .buttonStyle(.borderless)
        .frame(width: 38)
        .disabled(!canSaveAsCustomOrder)
        .accessibilityLabel("Save as Custom Order")
        .help("Save as Custom Order")
    }

    private var viewModePicker: some View {
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
    }

    private var autoRefreshPicker: some View {
        HStack(spacing: 6) {
            Text("Auto")
                .font(.callout)
                .foregroundStyle(.secondary)

            Picker("Auto Refresh", selection: autoRefreshIntervalBinding) {
                ForEach(AutoRefreshInterval.allCases) { interval in
                    Text(interval.displayName)
                        .tag(interval)
                }
            }
            .pickerStyle(.menu)
            .frame(width: 66)
        }
        .frame(width: 112)
        .disabled(store.cards.isEmpty)
        .help("Auto Refresh")
    }

    private var refreshAllButton: some View {
        Button(action: refreshAll) {
            HStack(spacing: 6) {
                Image(systemName: "arrow.clockwise")
                    .rotationEffect(.degrees(isRefreshingAll ? 360 : 0))
                    .animation(
                        isRefreshingAll ? .linear(duration: 1).repeatForever(autoreverses: false) : .default,
                        value: isRefreshingAll
                    )

                Text("Refresh All")
            }
        }
        .buttonStyle(.borderless)
        .frame(width: 112)
        .disabled(isRefreshingAll || store.cards.isEmpty)
        .accessibilityLabel("Refresh All")
        .help("Refresh All")
    }

    private var addCardButton: some View {
        Button(action: presentAddForm) {
            Label("Add item card", systemImage: "plus")
        }
        .labelStyle(.titleAndIcon)
        .buttonStyle(.borderless)
        .frame(width: 124)
        .accessibilityLabel("Add Card")
        .help("Add Card")
    }

    @ViewBuilder
    private var billingCardList: some View {
        let cards = sortedUnpinnedCards
        let amountColumnWidths = BillingCardAmountColumnWidths.cards(for: orderedCards)

        ForEach(cards) { card in
            billingCardRow(for: card, amountColumnWidths: amountColumnWidths)
        }

        AddBillingCardView(subtitle: nil) {
            presentAddForm()
        }
    }

    @ViewBuilder
    private var pinnedCardList: some View {
        let amountColumnWidths = BillingCardAmountColumnWidths.cards(for: orderedCards)

        VStack(alignment: .leading, spacing: 16) {
            ForEach(pinnedCards) { card in
                billingCardRow(for: card, amountColumnWidths: amountColumnWidths)
            }
        }
    }

    @ViewBuilder
    private var compactCardList: some View {
        let cards = orderedCards
        let amountColumnWidths = BillingCardAmountColumnWidths.compact(for: cards)

        VStack(alignment: .leading, spacing: 0) {
            ForEach(cards) { card in
                CompactBillingCardRowView(card: card, amountColumnWidths: amountColumnWidths)
            }
        }
    }

    private var orderedCards: [BillingCard] {
        pinnedCards + sortedUnpinnedCards
    }

    private var pinnedCards: [BillingCard] {
        store.cards
            .filter { $0.isPinned }
            .sorted(by: pinnedOrder)
    }

    private var sortedUnpinnedCards: [BillingCard] {
        sortedCards(from: store.cards.filter { !$0.isPinned }, mode: preferences.sortMode)
    }

    private var canSaveAsCustomOrder: Bool {
        !sortedUnpinnedCards.isEmpty && preferences.sortMode != .custom
    }

    private var sortModeHelpText: String {
        if preferences.sortMode == .custom {
            return "Custom Order. Use arrow controls on each card to rearrange them."
        }

        return "Sorted by \(preferences.sortMode.displayName). Use card arrow controls to save a new Custom Order."
    }

    @ViewBuilder
    private func billingCardRow(for card: BillingCard, amountColumnWidths: BillingCardAmountColumnWidths) -> some View {
        BillingCardRowView(
            card: card,
            amountColumnWidths: amountColumnWidths,
            isRefreshing: refreshingCardIDs.contains(card.id),
            isPinned: card.isPinned,
            canMoveUp: canMoveUp(card),
            canMoveDown: canMoveDown(card),
            onTogglePinned: {
                togglePinned(card)
            },
            onMoveUp: {
                moveCard(card, by: -1)
            },
            onMoveDown: {
                moveCard(card, by: 1)
            },
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
    }

    private func canMoveUp(_ card: BillingCard) -> Bool {
        guard !card.isPinned,
              let index = sortedUnpinnedCards.firstIndex(where: { $0.id == card.id }) else {
            return false
        }

        return index > 0
    }

    private func canMoveDown(_ card: BillingCard) -> Bool {
        guard !card.isPinned,
              let index = sortedUnpinnedCards.firstIndex(where: { $0.id == card.id }) else {
            return false
        }

        return index < sortedUnpinnedCards.count - 1
    }

    private func moveCard(_ card: BillingCard, by offset: Int) {
        guard !card.isPinned else {
            return
        }

        var currentOrder = sortedUnpinnedCards
        guard
            let sourceIndex = currentOrder.firstIndex(where: { $0.id == card.id }),
            currentOrder.indices.contains(sourceIndex + offset)
        else {
            return
        }

        currentOrder.swapAt(sourceIndex, sourceIndex + offset)

        withAnimation {
            store.saveCustomOrder(currentOrder)
            setSortMode(.custom)
        }
    }

    private func togglePinned(_ card: BillingCard) {
        withAnimation {
            store.setPinned(!card.isPinned, for: card.id)
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

    private func setAutoRefreshInterval(_ interval: AutoRefreshInterval) {
        preferences.autoRefreshInterval = interval
        DashboardPreferencesStore.save(preferences, userDefaults: userDefaults)
    }

    private func saveAsCustomOrder() {
        let currentOrder = sortedUnpinnedCards
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

        Task {
            _ = await refreshAllCards(cards)
        }
    }

    private var autoRefreshableCards: [BillingCard] {
        store.cards.filter(\.canAutoRefresh)
    }

    private func refreshAllCards(_ cards: [BillingCard]) async -> Bool {
        guard !cards.isEmpty, !isRefreshingAll else {
            return false
        }

        let cardIDs = Set(cards.map(\.id))
        isRefreshingAll = true
        refreshingCardIDs.formUnion(cardIDs)

        for card in cards {
            await refreshBilling(for: card)
        }

        let updatedCards = store.cards.filter { cardIDs.contains($0.id) }
        await refreshConversions(for: updatedCards)

        refreshingCardIDs.subtract(cardIDs)
        isRefreshingAll = false
        lastRefreshAllAt = Date()
        return true
    }

    private func runAutoRefreshLoop(for interval: AutoRefreshInterval) async {
        guard let seconds = interval.seconds else {
            return
        }

        while !Task.isCancelled {
            let delay = autoRefreshDelay(for: seconds)
            if delay > 0 {
                do {
                    try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                } catch {
                    return
                }
            }

            guard !Task.isCancelled else {
                return
            }

            let cards = autoRefreshableCards
            if cards.isEmpty {
                do {
                    try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
                } catch {
                    return
                }
                continue
            }

            let didRefresh = await refreshAllCards(cards)
            if !didRefresh {
                do {
                    try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
                } catch {
                    return
                }
            }
        }
    }

    private func autoRefreshDelay(for seconds: TimeInterval) -> TimeInterval {
        guard let lastRefreshAllAt else {
            return 0
        }

        return max(0, seconds - Date().timeIntervalSince(lastRefreshAllAt))
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
    var color: Color = .pink.opacity(0.65)

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
                        color,
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

    func pinnedOrder(_ lhs: BillingCard, _ rhs: BillingCard) -> Bool {
        switch (lhs.pinnedAt, rhs.pinnedAt) {
        case let (lhsPinnedAt?, rhsPinnedAt?):
            if lhsPinnedAt == rhsPinnedAt {
                return customOrder(lhs, rhs)
            }
            return lhsPinnedAt < rhsPinnedAt
        case (_?, nil):
            return true
        case (nil, _?):
            return false
        case (nil, nil):
            return customOrder(lhs, rhs)
        }
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
        let lhsAmount = lhs.currentMonthlyEquivalentJPYAmount
        let rhsAmount = rhs.currentMonthlyEquivalentJPYAmount

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

private extension BillingCard {
    var canAutoRefresh: Bool {
        guard sourceType == .apiUsage else {
            return false
        }

        switch service {
        case .aws, .gcp, .azure, .cloudflare, .laravelCloud, .openAiApi, .openAiCodex, .deepLApi:
            return true
        case .githubCopilot, .openAiChatGpt, .claude, .claudeCode, .deepl, .adobeCreativeCloud, .dropbox, .youtube, .netflix, .disneyPlus, .appleTvPlus, .appleMusic, .appleArcade, .iTunesMatch, .hulu, .amazon, .niconicoPremium, .abema, .dAnimeStore, .dmmTv, .uNext, .dazn, .spotifyPremium, .nintendoSwitchOnline, .playStationPlus, .xboxGamePass, .kindleUnlimited, .audible, .appleOne, .appleFitnessPlus, .iCloudPlus, .googleOne, .microsoft365, .onePassword, .pixiv, .amazonShopping, .yodobashi, .yahooShopping, .mercari, .manual:
            return false
        }
    }
}
