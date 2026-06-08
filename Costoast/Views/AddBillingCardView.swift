//
//  AddBillingCardView.swift
//  Costoast
//
//  Created by 池田洋平 on 2026/06/08.
//

import SwiftUI

struct AddBillingCardView: View {
    var subtitle: String?
    var action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            VStack(alignment: .center, spacing: 10) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: subtitle == nil ? 22 : 30, weight: .semibold))
                    .foregroundStyle(.secondary)

                Text("Add Card")
                    .font(.headline)

                if let subtitle {
                    Text(subtitle)
                        .font(.body)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(24)
            .background(backgroundColor, in: RoundedRectangle(cornerRadius: 8))
            .overlay {
                RoundedRectangle(cornerRadius: 8)
                    .stroke(.quaternary.opacity(isHovered ? 1 : 0.65), lineWidth: 1)
            }
        }
        .buttonStyle(AddBillingCardButtonStyle(isHovered: isHovered))
        .accessibilityLabel("Add Card")
        .help("Add Card")
        .onHover { isHovered = $0 }
    }

    private var backgroundColor: Color {
        isHovered ? Color.primary.opacity(0.05) : Color.primary.opacity(0.025)
    }
}

private struct AddBillingCardButtonStyle: ButtonStyle {
    var isHovered: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.99 : 1)
            .animation(.easeOut(duration: 0.08), value: configuration.isPressed)
            .animation(.easeOut(duration: 0.12), value: isHovered)
    }
}

#Preview {
    AddBillingCardView(subtitle: "Add your first billing card.") {}
        .padding()
        .frame(width: 800)
}
