//
//  BillingCardStore.swift
//  Costoast
//
//  Created by 池田洋平 on 2026/06/08.
//

import Combine
import Foundation

final class BillingCardStore: ObservableObject {
    @Published private(set) var cards: [BillingCard] = []
    @Published private(set) var storageError: String?

    private let storageKey = "billingCards"
    private let userDefaults: UserDefaults
    private let decoder = JSONDecoder()
    private let encoder = JSONEncoder()

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        load()
    }

    func load() {
        guard let data = userDefaults.data(forKey: storageKey) else {
            cards = []
            storageError = nil
            return
        }

        do {
            let decodedCards = try decoder.decode([BillingCard].self, from: data)
            cards = normalized(decodedCards)
            storageError = nil
        } catch {
            cards = []
            storageError = "Saved billing cards could not be loaded."
        }
    }

    func add(_ card: BillingCard) {
        cards.append(card)
        cards = normalized(cards, updatesTimestamp: card.id)
        save()
    }

    func update(_ card: BillingCard) {
        guard let index = cards.firstIndex(where: { $0.id == card.id }) else {
            return
        }

        var updatedCard = card
        updatedCard.displayOrder = cards[index].displayOrder
        updatedCard.createdAt = cards[index].createdAt
        updatedCard.updatedAt = Date()
        cards[index] = updatedCard
        cards = normalized(cards)
        save()
    }

    func delete(_ card: BillingCard) {
        cards.removeAll { $0.id == card.id }
        cards = normalized(cards)
        save()
    }

    func move(from source: IndexSet, to destination: Int) {
        guard !source.isEmpty else {
            return
        }

        var reorderedCards = cards
        let movingIndexes = source.sorted()
        var movingCards: [BillingCard] = []
        var adjustedDestination = destination

        for index in movingIndexes.reversed() {
            movingCards.insert(reorderedCards.remove(at: index), at: 0)
            if index < adjustedDestination {
                adjustedDestination -= 1
            }
        }

        reorderedCards.insert(contentsOf: movingCards, at: adjustedDestination)
        cards = normalized(reorderedCards)
        save()
    }

    private func save() {
        do {
            let data = try encoder.encode(cards)
            userDefaults.set(data, forKey: storageKey)
            storageError = nil
        } catch {
            storageError = "Billing cards could not be saved."
        }
    }

    private func normalized(_ cards: [BillingCard], updatesTimestamp cardID: UUID? = nil) -> [BillingCard] {
        let sortedCards = cards.sorted {
            if $0.displayOrder == $1.displayOrder {
                return $0.createdAt < $1.createdAt
            }

            return $0.displayOrder < $1.displayOrder
        }

        return sortedCards.enumerated().map { index, card in
            var normalizedCard = card
            normalizedCard.displayOrder = index
            if normalizedCard.id == cardID {
                normalizedCard.updatedAt = Date()
            }
            return normalizedCard
        }
    }
}
