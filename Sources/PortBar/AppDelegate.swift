import AppKit
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSPopoverDelegate {
    private let store = PortStore()
    private var statusItem: NSStatusItem!
    private let popover = NSPopover()
    private var hotKey: HotKey?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory) // menu bar agent, no Dock icon

        popover.behavior = .transient
        popover.animates = true
        popover.delegate = self
        // Content is created on open and torn down on close, so nothing
        // renders (and no animations run) while the panel is hidden.

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            let img = NSImage(systemSymbolName: "powerplug.fill", accessibilityDescription: "PortBar")
            img?.isTemplate = true
            button.image = img
            button.imagePosition = .imageLeading
            button.font = .monospacedDigitSystemFont(ofSize: 12, weight: .semibold)
            button.action = #selector(togglePopover)
            button.target = self
        }

        store.onChange = { [weak self] in self?.updateButton() }
        store.start()
        updateButton()

        // Global hotkey: ⌘⇧P toggles the panel from anywhere.
        hotKey = HotKey { [weak self] in self?.togglePopover() }
    }

    private func updateButton() {
        let n = store.inUseWatchedCount
        statusItem.button?.title = n > 0 ? " \(n)" : ""
    }

    @objc private func togglePopover() {
        guard let button = statusItem.button else { return }
        if popover.isShown {
            popover.performClose(nil)
        } else {
            // Build the SwiftUI panel fresh on open.
            popover.contentViewController = NSHostingController(rootView: PanelView(store: store))
            store.setActive(true)
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            NSApp.activate(ignoringOtherApps: true)
            // Let the popover's window take key focus so the search field & text
            // entry work immediately.
            popover.contentViewController?.view.window?.makeKey()
        }
    }

    // NSPopoverDelegate: release the view tree when closed so it stops
    // rendering, and drop back to the slow background scan cadence.
    func popoverDidClose(_ notification: Notification) {
        popover.contentViewController = nil
        store.setActive(false)
    }
}
