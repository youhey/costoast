//
//  BillingCardDropDelegate.swift
//  Costoast
//
//  Created by 池田洋平 on 2026/06/08.
//

import SwiftUI

struct BillingCardDropDelegate: DropDelegate {
    let targetCard: BillingCard
    @Binding var draggedCard: BillingCard?
    let store: BillingCardStore

    func dropEntered(info: DropInfo) {
        guard
            let draggedCard,
            draggedCard != targetCard,
            let sourceIndex = store.cards.firstIndex(where: { $0.id == draggedCard.id }),
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

    func performDrop(info: DropInfo) -> Bool {
        draggedCard = nil
        return true
    }
}
