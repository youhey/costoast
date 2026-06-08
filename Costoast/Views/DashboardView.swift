//
//  DashboardView.swift
//  Costoast
//
//  Created by 池田洋平 on 2026/06/08.
//

import SwiftUI
import UniformTypeIdentifiers

struct DashboardView: View {
    @StateObject private var store = BillingCardStore()
    @State private var formPresentation: BillingCardFormPresentation?
    @State private var cardPendingDeletion: BillingCard?
    @State private var draggedCard: BillingCard?

    var body: some View {
        VStack(alignment: .leading, spacing: 28) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Costoast")
                    .font(.system(size: 34, weight: .semibold, design: .rounded))

                Text("Your costs, served fresh.")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }

            if let storageError = store.storageError {
                Text(storageError)
                    .font(.callout)
                    .foregroundStyle(.red)
            }

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if store.cards.isEmpty {
                        EmptyDashboardView {
                            presentAddForm()
                        }
                    } else {
                        ForEach(store.cards) { card in
                            BillingCardRowView(
                                card: card,
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
        .sheet(item: $formPresentation) { presentation in
            BillingCardFormView(card: presentation.card, displayOrder: store.cards.count) { card in
                if presentation.card == nil {
                    store.add(card)
                } else {
                    store.update(card)
                }
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
}

#Preview {
    DashboardView()
}

private struct BillingCardFormPresentation: Identifiable {
    let id = UUID()
    let card: BillingCard?
}
