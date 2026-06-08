//
//  ActionButtons.swift
//  Costoast
//
//  Created by 池田洋平 on 2026/06/08.
//

import SwiftUI

struct IconActionButton: View {
    let systemName: String
    let accessibilityLabel: String
    var role: ButtonRole?
    var isDisabled = false
    var showsProgress = false
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(role: role, action: action) {
            Group {
                if showsProgress {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Image(systemName: systemName)
                }
            }
            .frame(width: 18, height: 18)
        }
        .buttonStyle(IconActionButtonStyle(role: role, isHovered: isHovered))
        .disabled(isDisabled)
        .accessibilityLabel(accessibilityLabel)
        .help(accessibilityLabel)
        .onHover { isHovered = $0 }
    }
}

struct CardActionButtons: View {
    let isRefreshing: Bool
    let onRefresh: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 4) {
            IconActionButton(
                systemName: "arrow.clockwise",
                accessibilityLabel: "Refresh Card",
                isDisabled: isRefreshing,
                showsProgress: isRefreshing,
                action: onRefresh
            )

            IconActionButton(
                systemName: "pencil",
                accessibilityLabel: "Edit Card",
                action: onEdit
            )

            IconActionButton(
                systemName: "trash",
                accessibilityLabel: "Delete Card",
                role: .destructive,
                action: onDelete
            )
        }
    }
}

private struct IconActionButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    var role: ButtonRole?
    var isHovered: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 14, weight: .medium))
            .frame(width: 30, height: 30)
            .foregroundStyle(foregroundColor)
            .background {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(backgroundColor(isPressed: configuration.isPressed))
            }
            .opacity(isEnabled ? 1 : 0.42)
            .scaleEffect(configuration.isPressed ? 0.94 : 1)
            .animation(.easeOut(duration: 0.08), value: configuration.isPressed)
            .animation(.easeOut(duration: 0.12), value: isHovered)
    }

    private var foregroundColor: Color {
        guard isEnabled else {
            return .secondary
        }

        if role == .destructive {
            return isHovered ? .red : .secondary
        }

        return isHovered ? .primary : .secondary
    }

    private func backgroundColor(isPressed: Bool) -> Color {
        if role == .destructive {
            if isPressed {
                return Color.red.opacity(0.16)
            }

            return isHovered ? Color.red.opacity(0.10) : Color.clear
        }

        if isPressed {
            return Color.primary.opacity(0.12)
        }

        return isHovered ? Color.primary.opacity(0.06) : Color.clear
    }
}
