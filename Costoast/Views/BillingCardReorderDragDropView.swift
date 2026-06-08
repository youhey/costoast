//
//  BillingCardReorderDragDropView.swift
//  Costoast
//
//  Created by Codex on 2026/06/08.
//

import AppKit
import SwiftUI

private extension NSPasteboard.PasteboardType {
    static let costoastBillingCardID = NSPasteboard.PasteboardType("youhey.Costoast.billing-card-id")
}

struct BillingCardReorderDragHandle: NSViewRepresentable {
    let cardID: UUID
    let serviceName: String

    func makeNSView(context: Context) -> DragHandleView {
        DragHandleView(cardID: cardID, serviceName: serviceName)
    }

    func updateNSView(_ nsView: DragHandleView, context: Context) {
        nsView.cardID = cardID
        nsView.serviceName = serviceName
    }
}

struct BillingCardReorderDropTarget: NSViewRepresentable {
    let cardID: UUID
    let onDrop: (UUID) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onDrop: onDrop)
    }

    func makeNSView(context: Context) -> DropTargetView {
        DropTargetView(cardID: cardID, coordinator: context.coordinator)
    }

    func updateNSView(_ nsView: DropTargetView, context: Context) {
        nsView.cardID = cardID
        context.coordinator.onDrop = onDrop
    }

    final class Coordinator {
        var onDrop: (UUID) -> Void

        init(onDrop: @escaping (UUID) -> Void) {
            self.onDrop = onDrop
        }
    }
}

final class DragHandleView: NSView, NSDraggingSource {
    var cardID: UUID
    var serviceName: String {
        didSet {
            setAccessibilityLabel("Reorder \(serviceName)")
        }
    }

    private var dragStarted = false

    init(cardID: UUID, serviceName: String) {
        self.cardID = cardID
        self.serviceName = serviceName
        super.init(frame: .zero)
        wantsLayer = true
        setAccessibilityElement(true)
        setAccessibilityRole(.button)
        setAccessibilityLabel("Reorder \(serviceName)")
        setAccessibilityIdentifier("billing-card-drag-handle-\(cardID.uuidString)")
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var intrinsicContentSize: NSSize {
        NSSize(width: 26, height: 38)
    }

    override func updateLayer() {
        layer?.backgroundColor = NSColor.controlBackgroundColor.withAlphaComponent(0.75).cgColor
        layer?.cornerRadius = 6
        layer?.borderWidth = 1
        layer?.borderColor = NSColor.quaternaryLabelColor.cgColor
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        NSColor.secondaryLabelColor.setStroke()
        let path = NSBezierPath()
        path.lineWidth = 1.6
        path.lineCapStyle = .round

        let centerY = bounds.midY
        for offset in [-5.0, 0.0, 5.0] {
            path.move(to: NSPoint(x: bounds.midX - 5, y: centerY + offset))
            path.line(to: NSPoint(x: bounds.midX + 5, y: centerY + offset))
        }
        path.stroke()
    }

    override func mouseDown(with event: NSEvent) {
        dragStarted = false
    }

    override func mouseDragged(with event: NSEvent) {
        guard !dragStarted else {
            return
        }

        dragStarted = true
        let pasteboardItem = NSPasteboardItem()
        pasteboardItem.setString(cardID.uuidString, forType: .costoastBillingCardID)

        let draggingItem = NSDraggingItem(pasteboardWriter: pasteboardItem)
        draggingItem.setDraggingFrame(bounds, contents: dragImage)
        beginDraggingSession(with: [draggingItem], event: event, source: self)
    }

    func draggingSession(
        _ session: NSDraggingSession,
        sourceOperationMaskFor context: NSDraggingContext
    ) -> NSDragOperation {
        .move
    }

    func ignoreModifierKeys(for session: NSDraggingSession) -> Bool {
        true
    }

    private var dragImage: NSImage {
        let image = NSImage(size: bounds.size)
        image.lockFocus()
        draw(bounds)
        image.unlockFocus()
        return image
    }
}

final class DropTargetView: NSView {
    var cardID: UUID
    private let coordinator: BillingCardReorderDropTarget.Coordinator

    init(cardID: UUID, coordinator: BillingCardReorderDropTarget.Coordinator) {
        self.cardID = cardID
        self.coordinator = coordinator
        super.init(frame: .zero)
        registerForDraggedTypes([.costoastBillingCardID])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        nil
    }

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        sourceCardID(from: sender) == nil ? [] : .move
    }

    override func prepareForDragOperation(_ sender: NSDraggingInfo) -> Bool {
        sourceCardID(from: sender) != nil
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        guard let sourceCardID = sourceCardID(from: sender) else {
            return false
        }

        coordinator.onDrop(sourceCardID)
        return true
    }

    private func sourceCardID(from sender: NSDraggingInfo) -> UUID? {
        guard
            let string = sender.draggingPasteboard.string(forType: .costoastBillingCardID),
            let sourceCardID = UUID(uuidString: string),
            sourceCardID != cardID
        else {
            return nil
        }

        return sourceCardID
    }
}
