import SwiftUI

struct PanelView: View {
    @ObservedObject var store: PortStore
    @AppStorage("ConfirmBeforeKill") private var confirmBeforeKill = false
    @State private var loginEnabled = LoginItem.isEnabled
    @State private var refreshSpin = false
    @State private var search = ""
    @State private var showOthers = false
    @State private var newPort = ""

    var body: some View {
        VStack(spacing: 0) {
            header
            searchBar
            statsStrip
            if store.scanFailed { scanFailedBanner }
            Divider().overlay(Theme.stroke)

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    pinnedSection
                    inUseSection
                    othersSection
                    availableSection
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 14)
            }
            .frame(maxHeight: 460)

            Divider().overlay(Theme.stroke)
            footer
        }
        .frame(width: 400)
        .background(backdrop)
        .preferredColorScheme(.dark)
        .onAppear { store.refresh() }
        .alert("Couldn't free port", isPresented: Binding(
            get: { store.killError != nil },
            set: { if !$0 { store.killError = nil } }
        )) {
            Button("OK", role: .cancel) { store.killError = nil }
        } message: { Text(store.killError ?? "") }
    }

    // MARK: Header

    private var header: some View {
        HStack(spacing: 11) {
            ZStack {
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(LinearGradient(colors: [Theme.inUse, Theme.danger.opacity(0.9)],
                                         startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 30, height: 30)
                Image(systemName: "powerplug.fill")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.black.opacity(0.78))
            }
            VStack(alignment: .leading, spacing: 0) {
                Text("PortBar").font(Theme.rounded(17, .bold)).foregroundStyle(Theme.textPrimary)
                Text("PORT MONITOR").font(Theme.mono(8.5, .semibold)).tracking(2.4)
                    .foregroundStyle(Theme.textTertiary)
            }
            Spacer()
            panicButton
            headerIcon("arrow.clockwise", help: "Refresh now") {
                refreshSpin.toggle(); store.refresh()
            }
            .rotationEffect(.degrees(refreshSpin ? 360 : 0))
            .animation(.easeInOut(duration: 0.5), value: refreshSpin)
        }
        .padding(.horizontal, 16).padding(.top, 15).padding(.bottom, 11)
    }

    private var panicButton: some View {
        Button {
            confirmKillAll()
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "bolt.fill").font(.system(size: 9, weight: .bold))
                Text("Kill all").font(Theme.mono(10, .semibold))
            }
            .foregroundStyle(store.occupiedWatched.isEmpty ? Theme.textTertiary : Theme.danger)
            .padding(.horizontal, 9).padding(.vertical, 5)
            .background(Capsule().fill(Theme.danger.opacity(store.occupiedWatched.isEmpty ? 0.04 : 0.12)))
            .overlay(Capsule().strokeBorder(Theme.danger.opacity(store.occupiedWatched.isEmpty ? 0.12 : 0.3), lineWidth: 1))
        }
        .buttonStyle(.plain)
        .disabled(store.occupiedWatched.isEmpty)
        .help("Free every dev port currently in use")
    }

    private func headerIcon(_ symbol: String, help: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(Theme.textSecondary)
                .frame(width: 28, height: 28)
                .background(Circle().fill(Theme.card))
                .overlay(Circle().strokeBorder(Theme.stroke, lineWidth: 1))
        }
        .buttonStyle(.plain).help(help)
    }

    private var scanFailedBanner: some View {
        HStack(spacing: 7) {
            Image(systemName: "exclamationmark.triangle.fill").font(.system(size: 11))
            Text("Scanner unavailable — lsof failed. Showing last known state.")
                .font(Theme.mono(10))
            Spacer()
        }
        .foregroundStyle(Theme.danger)
        .padding(.horizontal, 16).padding(.vertical, 8)
        .background(Theme.danger.opacity(0.10))
    }

    // MARK: Search

    private var searchBar: some View {
        HStack(spacing: 7) {
            Image(systemName: "magnifyingglass").font(.system(size: 11)).foregroundStyle(Theme.textTertiary)
            TextField("filter by port or process…", text: $search)
                .textFieldStyle(.plain)
                .font(Theme.mono(11))
                .foregroundStyle(Theme.textPrimary)
            if !search.isEmpty {
                Button { search = "" } label: {
                    Image(systemName: "xmark.circle.fill").font(.system(size: 11)).foregroundStyle(Theme.textTertiary)
                }.buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 10).padding(.vertical, 7)
        .background(RoundedRectangle(cornerRadius: 9, style: .continuous).fill(Theme.card))
        .overlay(RoundedRectangle(cornerRadius: 9, style: .continuous).strokeBorder(Theme.stroke, lineWidth: 1))
        .padding(.horizontal, 16).padding(.bottom, 10)
    }

    // MARK: Stats

    private var statsStrip: some View {
        HStack(spacing: 16) {
            stat(store.occupiedWatched.count, "in use", Theme.inUse)
            stat(store.freeWatched.count, "free", Theme.free)
            Spacer()
            HStack(spacing: 5) {
                Circle().fill(store.isScanning ? Theme.free : Theme.textTertiary).frame(width: 5, height: 5)
                Text(store.isScanning ? "scanning" : "updated \(store.lastUpdated)")
                    .font(Theme.mono(9.5)).foregroundStyle(Theme.textTertiary)
            }
        }
        .padding(.horizontal, 16).padding(.bottom, 12)
    }

    private func stat(_ count: Int, _ label: String, _ color: Color) -> some View {
        HStack(spacing: 6) {
            Circle().fill(color).frame(width: 7, height: 7)
            Text(verbatim: "\(count)").font(Theme.mono(13, .bold)).foregroundStyle(Theme.textPrimary)
            Text(label).font(Theme.mono(10)).foregroundStyle(Theme.textSecondary)
        }
    }

    // MARK: Sections

    private func matches(_ port: Int) -> Bool {
        guard !search.isEmpty else { return true }
        let q = search.lowercased()
        if String(port).contains(q) { return true }
        if let procs = store.byPort[port],
           procs.contains(where: { $0.command.lowercased().contains(q) || $0.commandLine.lowercased().contains(q) }) {
            return true
        }
        return false
    }

    private var pinnedPorts: [Int] { store.pinned.sorted().filter(matches) }

    @ViewBuilder
    private var pinnedSection: some View {
        if !pinnedPorts.isEmpty {
            sectionLabel("PINNED")
            ForEach(pinnedPorts, id: \.self) { port in
                if store.byPort[port] != nil { card(port) } else { freePinnedRow(port) }
            }
        }
    }

    @ViewBuilder
    private var inUseSection: some View {
        let dev = store.occupiedWatched.filter { !store.isPinned($0) }.filter(matches)
        if dev.isEmpty && pinnedPorts.allSatisfy({ store.byPort[$0] == nil }) && store.otherOccupied.filter(matches).isEmpty {
            if search.isEmpty { emptyState }
        }
        if !dev.isEmpty {
            sectionLabel("IN USE")
            ForEach(dev, id: \.self) { card($0) }
        }
    }

    @ViewBuilder
    private var othersSection: some View {
        let others = store.otherOccupied.filter { !store.isPinned($0) }.filter(matches)
        if !others.isEmpty {
            Button { withAnimation(.easeOut(duration: 0.15)) { showOthers.toggle() } } label: {
                HStack(spacing: 6) {
                    Image(systemName: showOthers ? "chevron.down" : "chevron.right")
                        .font(.system(size: 8, weight: .bold))
                    Text(verbatim: "OTHER LISTENERS  ·  \(others.count)")
                        .font(Theme.mono(9.5, .semibold)).tracking(1.4)
                    Spacer()
                }
                .foregroundStyle(Theme.textTertiary).contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            if showOthers {
                ForEach(others, id: \.self) { card($0) }
            }
        }
    }

    @ViewBuilder
    private var availableSection: some View {
        let free = store.freeWatched.filter { !store.isPinned($0) }.filter(matches)
        sectionLabel("AVAILABLE DEV PORTS")
        if free.isEmpty && !search.isEmpty {
            Text("no free ports match \"\(search)\"").font(Theme.mono(10)).foregroundStyle(Theme.textTertiary)
        } else {
            FlowLayout(spacing: 6) {
                ForEach(free, id: \.self) { p in portPill(p) }
            }
        }
        addPortField
    }

    private func portPill(_ p: Int) -> some View {
        FreePill(port: p, isCustom: store.isCustom(p))
            .contextMenu {
                Button("Copy \(p)") { Clipboard.copy("\(p)") }
                Button(store.isPinned(p) ? "Unpin" : "Pin") { store.togglePin(p) }
                if store.isCustom(p) {
                    Divider()
                    Button("Remove custom port", role: .destructive) { store.removeCustomPort(p) }
                }
            }
    }

    private var addPortField: some View {
        HStack(spacing: 6) {
            Image(systemName: "plus.circle").font(.system(size: 10)).foregroundStyle(Theme.textTertiary)
            TextField("watch a custom port…", text: $newPort)
                .textFieldStyle(.plain).font(Theme.mono(10.5)).foregroundStyle(Theme.textPrimary)
                .onSubmit(addPort)
            if !newPort.isEmpty {
                Button("add", action: addPort).buttonStyle(.plain)
                    .font(Theme.mono(10, .semibold)).foregroundStyle(Theme.free)
            }
        }
        .padding(.horizontal, 9).padding(.vertical, 6)
        .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(Theme.card))
        .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).strokeBorder(Theme.stroke, lineWidth: 1))
        .padding(.top, 4)
    }

    private func freePinnedRow(_ port: Int) -> some View {
        HStack(spacing: 11) {
            GlowDot(color: Theme.free)
            Text(verbatim: "\(port)").font(Theme.mono(15, .semibold)).foregroundStyle(Theme.textPrimary)
            Image(systemName: "pin.fill").font(.system(size: 8)).foregroundStyle(Theme.inUse)
            Text("free").font(Theme.mono(11)).foregroundStyle(Theme.free)
            Spacer()
            Button { store.togglePin(port) } label: {
                Image(systemName: "pin.slash").font(.system(size: 11)).foregroundStyle(Theme.textTertiary)
            }.buttonStyle(.plain).help("Unpin")
        }
        .padding(.horizontal, 12).padding(.vertical, 10)
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Theme.card))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(Theme.inUse.opacity(0.45), lineWidth: 1))
    }

    private func card(_ port: Int) -> some View {
        PortCardView(
            port: port,
            procs: store.byPort[port] ?? [],
            pinned: store.isPinned(port),
            onFree: { freePort(port) },
            onTogglePin: { store.togglePin(port) }
        )
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "checkmark.seal.fill").font(.system(size: 40))
                .foregroundStyle(Theme.free).shadow(color: Theme.free.opacity(0.5), radius: 8)
            Text("All clear").font(Theme.rounded(15, .semibold)).foregroundStyle(Theme.textPrimary)
            Text("No dev ports are in use right now.").font(Theme.mono(11)).foregroundStyle(Theme.textSecondary)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 26)
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text).font(Theme.mono(9.5, .semibold)).tracking(1.6)
            .foregroundStyle(Theme.textTertiary).padding(.top, 2)
    }

    // MARK: Footer

    private var footer: some View {
        HStack(spacing: 12) {
            toggle("Confirm kills", isOn: $confirmBeforeKill)
            toggle("Launch at login", isOn: Binding(
                get: { loginEnabled },
                set: { if LoginItem.set($0) { loginEnabled = $0 } }
            ))
            Spacer(minLength: 6)
            Text(verbatim: "⌘⌥P")
                .font(Theme.mono(9, .medium))
                .foregroundStyle(Theme.textTertiary)
                .lineLimit(1).fixedSize()
                .padding(.horizontal, 6).padding(.vertical, 2)
                .background(Capsule().fill(Color.white.opacity(0.05)))
                .overlay(Capsule().strokeBorder(Theme.stroke, lineWidth: 1))
                .help("Global shortcut to open PortBar")
            Button { NSApp.terminate(nil) } label: {
                Text("Quit").font(Theme.mono(11, .medium)).foregroundStyle(Theme.textSecondary)
            }.buttonStyle(.plain).fixedSize().help("Quit PortBar")
        }
        .padding(.horizontal, 14).padding(.vertical, 12)
    }

    private func toggle(_ label: String, isOn: Binding<Bool>) -> some View {
        Toggle(isOn: isOn) {
            Text(label).font(Theme.mono(10.5)).foregroundStyle(Theme.textSecondary)
        }
        .toggleStyle(.switch).controlSize(.mini).tint(Theme.inUse).fixedSize()
    }

    // MARK: Backdrop

    private var backdrop: some View {
        ZStack {
            LinearGradient(colors: [Theme.bgTop, Theme.bgBottom], startPoint: .top, endPoint: .bottom)
            RadialGradient(colors: [Theme.glow.opacity(0.16), .clear], center: .top, startRadius: 0, endRadius: 240)
        }.ignoresSafeArea()
    }

    // MARK: Actions

    private func addPort() {
        if let p = Int(newPort.trimmingCharacters(in: .whitespaces)) { store.addCustomPort(p) }
        newPort = ""
    }

    private func freePort(_ port: Int) {
        guard let procs = store.byPort[port], let first = procs.first else { return }
        if confirmBeforeKill {
            guard confirm(title: "Free port \(port)?",
                          msg: "This quits \(first.command) (pid \(procs.map { String($0.pid) }.joined(separator: ", "))).",
                          ok: "Free Port") else { return }
        }
        store.free(port: port, procs: procs)
    }

    private func confirmKillAll() {
        let ports = store.occupiedWatched
        guard !ports.isEmpty else { return }
        guard confirm(title: "Free \(ports.count) dev port\(ports.count == 1 ? "" : "s")?",
                      msg: "This quits every process on: \(ports.map(String.init).joined(separator: ", ")).",
                      ok: "Free All") else { return }
        store.killAllDevPorts()
    }

    private func confirm(title: String, msg: String, ok: String) -> Bool {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = msg
        alert.alertStyle = .warning
        alert.addButton(withTitle: ok)
        alert.addButton(withTitle: "Cancel")
        NSApp.activate(ignoringOtherApps: true)
        return alert.runModal() == .alertFirstButtonReturn
    }
}

/// A free-port pill; click copies the number with a brief flash.
private struct FreePill: View {
    let port: Int
    let isCustom: Bool
    @State private var flashed = false
    var body: some View {
        Button {
            Clipboard.copy("\(port)")
            flashed = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) { flashed = false }
        } label: {
            HStack(spacing: 4) {
                if isCustom {
                    Image(systemName: "star.fill").font(.system(size: 7))
                }
                Text(verbatim: flashed ? "copied" : "\(port)").font(Theme.mono(11, .medium))
            }
            .foregroundStyle(Theme.free)
            .padding(.horizontal, 9).padding(.vertical, 4)
            .background(Capsule().fill(Theme.free.opacity(flashed ? 0.22 : 0.10)))
            .overlay(Capsule().strokeBorder(Theme.free.opacity(0.25), lineWidth: 1))
        }
        .buttonStyle(.plain)
        .help("Click to copy · right-click for options")
    }
}
