import SwiftUI

@main
struct PortBarApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        // Menu-bar-only app: no window scene. All UI is the status-item popover
        // managed by AppDelegate. Settings gives a harmless empty preferences.
        Settings { EmptyView() }
    }
}
