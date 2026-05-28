import SwiftUI
import ServiceManagement

@MainActor
final class PortStore: ObservableObject {
    @Published private(set) var byPort: [Int: [PortProcess]] = [:]
    @Published private(set) var isScanning = false
    @Published private(set) var scanFailed = false
    @Published private(set) var lastUpdated = "—"
    @Published var killError: String?

    /// Called on the main actor after every scan, so the status-bar count
    /// can update without Combine plumbing.
    var onChange: (() -> Void)?

    /// User-added ports to always watch, on top of the common dev list.
    @Published private(set) var customPorts: [Int] = []
    /// Pinned ports float to the top.
    @Published private(set) var pinned: Set<Int> = []

    private var timer: Timer?
    private var started = false
    /// Fast cadence while the panel is open; slow while it's closed (the badge
    /// only needs an occasional refresh).
    private var active = false
    private var interval: TimeInterval { active ? 3 : 30 }

    private let customKey = "CustomPorts"
    private let pinnedKey = "PinnedPorts"

    init() {
        let d = UserDefaults.standard
        customPorts = (d.array(forKey: customKey) as? [Int]) ?? []
        pinned = Set((d.array(forKey: pinnedKey) as? [Int]) ?? [])
    }

    // Derived ---------------------------------------------------------------

    /// All ports we explicitly track (common + custom), deduped & sorted.
    var watchedPorts: [Int] {
        Array(Set(PortScanner.commonDevPorts + customPorts)).sorted()
    }
    var occupiedWatched: [Int] { watchedPorts.filter { byPort[$0] != nil } }
    var freeWatched: [Int] { watchedPorts.filter { byPort[$0] == nil } }
    var otherOccupied: [Int] {
        byPort.keys.filter { !watchedPorts.contains($0) }.sorted()
    }
    /// Count shown in the menu bar.
    var inUseWatchedCount: Int { occupiedWatched.count }

    func isPinned(_ port: Int) -> Bool { pinned.contains(port) }

    // Lifecycle -------------------------------------------------------------

    func start() {
        guard !started else { return }
        started = true
        refresh()
        scheduleTimer()
    }

    /// Switches scan cadence. Call with `true` when the panel opens, `false`
    /// when it closes.
    func setActive(_ on: Bool) {
        guard on != active else { return }
        active = on
        if on { refresh() }
        scheduleTimer()
    }

    private func scheduleTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
    }

    func refresh() {
        isScanning = true
        Task.detached(priority: .userInitiated) {
            let scan = PortScanner.scan()
            await MainActor.run {
                if let scan {
                    self.byPort = scan
                    self.scanFailed = false
                    self.lastUpdated = Self.clock.string(from: Date())
                } else {
                    self.scanFailed = true
                }
                self.isScanning = false
                self.onChange?()
            }
        }
    }

    // Actions ---------------------------------------------------------------

    /// Frees a port by killing every process on it, reporting failures.
    func free(port: Int, procs: [PortProcess]) {
        let group = DispatchGroup()
        var allOK = true
        for p in procs {
            group.enter()
            PortScanner.freePort(pid: p.pid) { ok in
                if !ok { allOK = false }
                group.leave()
            }
        }
        group.notify(queue: .main) {
            if !allOK {
                self.killError = "Couldn't fully free port \(port) — the process may be owned by another user."
            }
            self.refresh()
        }
    }

    /// Kills everything on every occupied *watched* dev port. Returns how many
    /// ports it attempted.
    @discardableResult
    func killAllDevPorts() -> Int {
        let targets = occupiedWatched
        let group = DispatchGroup()
        var failed = 0
        for port in targets {
            for p in byPort[port] ?? [] {
                group.enter()
                PortScanner.freePort(pid: p.pid) { ok in
                    if !ok { failed += 1 }
                    group.leave()
                }
            }
        }
        group.notify(queue: .main) {
            if failed > 0 {
                self.killError = "\(failed) process(es) couldn't be killed — they may be owned by another user."
            }
            self.refresh()
        }
        return targets.count
    }

    // Preferences -----------------------------------------------------------

    func togglePin(_ port: Int) {
        if pinned.contains(port) { pinned.remove(port) } else { pinned.insert(port) }
        UserDefaults.standard.set(Array(pinned), forKey: pinnedKey)
    }

    func addCustomPort(_ port: Int) {
        guard port > 0, port <= 65535,
              !customPorts.contains(port),
              !PortScanner.commonDevPorts.contains(port) else { return }
        customPorts.append(port)
        customPorts.sort()
        UserDefaults.standard.set(customPorts, forKey: customKey)
        refresh()
    }

    func removeCustomPort(_ port: Int) {
        customPorts.removeAll { $0 == port }
        UserDefaults.standard.set(customPorts, forKey: customKey)
    }

    func isCustom(_ port: Int) -> Bool { customPorts.contains(port) }

    private static let clock: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "HH:mm:ss"; return f
    }()
}

/// Launch-at-login backed by SMAppService (macOS 13+).
enum LoginItem {
    static var isEnabled: Bool { SMAppService.mainApp.status == .enabled }
    @discardableResult
    static func set(_ enabled: Bool) -> Bool {
        do {
            if enabled { try SMAppService.mainApp.register() }
            else { try SMAppService.mainApp.unregister() }
            return true
        } catch { return false }
    }
}

/// Small clipboard + reveal helpers used across the UI.
enum Clipboard {
    static func copy(_ s: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(s, forType: .string)
    }
}

enum Reveal {
    static func inFinder(_ path: String) {
        NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: path)
    }
    static func inTerminal(_ path: String) {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        p.arguments = ["-a", "Terminal", path]
        try? p.run()
    }
    static func browser(port: Int) {
        if let url = URL(string: "http://localhost:\(port)") { NSWorkspace.shared.open(url) }
    }
}
