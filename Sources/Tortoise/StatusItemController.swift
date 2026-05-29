import AppKit
import SwiftUI

@MainActor
final class StatusItemController: NSObject {
    private let model: TortoiseModel
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let popover = NSPopover()

    init(model: TortoiseModel) {
        self.model = model
        super.init()
        configureStatusItem()
        configurePopover()
        bindModel()
        refreshStatusItem()
    }

    private func configureStatusItem() {
        guard let button = statusItem.button else {
            return
        }

        button.target = self
        button.action = #selector(togglePopover(_:))
        button.sendAction(on: [.leftMouseUp])
        button.imageScaling = .scaleProportionallyUpOrDown
        button.toolTip = "Tortoise"
    }

    private func configurePopover() {
        popover.behavior = .transient
        popover.animates = false
        popover.contentSize = NSSize(width: 280, height: 430)
        popover.contentViewController = NSHostingController(rootView: MenuBarContent(model: model))
    }

    private func bindModel() {
        model.onStatusItemRefresh = { [weak self] in
            self?.refreshStatusItem()
        }
    }

    private func refreshStatusItem() {
        guard let button = statusItem.button else {
            return
        }

        button.image = model.currentFrame
        button.imagePosition = model.showsPercentageInMenuBar ? .imageLeading : .imageOnly
        button.toolTip = "Tortoise: \(model.percentString) CPU, \(model.runnerStateDescription)"

        if model.showsPercentageInMenuBar {
            let title = NSAttributedString(
                string: model.percentString,
                attributes: [
                    .font: NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .medium),
                    .foregroundColor: NSColor.labelColor,
                ]
            )
            button.attributedTitle = title
            statusItem.length = NSStatusItem.variableLength
        } else {
            button.attributedTitle = NSAttributedString(string: "")
            statusItem.length = NSStatusItem.squareLength
        }
    }

    @objc
    private func togglePopover(_ sender: AnyObject?) {
        guard let button = statusItem.button else {
            return
        }

        if popover.isShown {
            popover.performClose(sender)
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
        }
    }
}
