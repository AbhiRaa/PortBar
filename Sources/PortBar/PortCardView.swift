import SwiftUI

/// One occupied port. Collapsed: the essentials + one-click free. Expanded:
/// the full info package (command line, owner, cwd, uptime, addresses) with
/// copy / reveal / terminal / browser actions.
struct PortCardView: View {
    let port: Int
    let procs: [PortProcess]
    let pinned: Bool
    let onFree: () -> Void
    let onTogglePin: () -> Void

    @State private var expanded = false
    @State private var hovering = false
    @State private var killHover = false

    private var primary: PortProcess? { procs.first }
    private var pids: [Int] { Array(Set(procs.map { $0.pid })).sorted() }
    private var pidList: String { pids.map(String.init).joined(separator: ", ") }
    private var loopbackOnly: Bool { procs.allSatisfy { $0.isLoopbackOnly } }
    private var allAddrs: String {
        Array(Set(procs.flatMap { $0.addresses })).sorted().joined(separator: ", ")
    }
    private var bindsDisplay: String {
        let a = allAddrs
        if a.isEmpty { return "—" }
        if a == "*" || a == "0.0.0.0" || a == "::" { return "\(a)  ·  all interfaces" }
        if loopbackOnly { return "\(a)  ·  localhost only" }
        return a
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            headerRow
            if expanded { detail }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(hovering ? Theme.cardHover : Theme.card)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(pinned ? Theme.inUse.opacity(0.45) : Theme.stroke, lineWidth: 1)
        )
        .onHover { hovering = $0 }
        .animation(.easeOut(duration: 0.14), value: hovering)
        .animation(.easeOut(duration: 0.18), value: expanded)
    }

    // MARK: Header

    private var headerRow: some View {
        HStack(spacing: 11) {
            ProcessBadge(command: primary?.command ?? "")

            Button { expanded.toggle() } label: {
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 7) {
                        Text(verbatim: "\(port)")
                            .font(Theme.mono(17, .semibold))
                            .foregroundStyle(Theme.textPrimary)
                        scopeBadge
                        if pinned {
                            Image(systemName: "pin.fill")
                                .font(.system(size: 8))
                                .foregroundStyle(Theme.inUse)
                        }
                    }
                    Text("\(primary?.command ?? "?")  ·  pid \(pidList)\(primary?.uptime.map { "  ·  up \($0)" } ?? "")")
                        .font(Theme.mono(11))
                        .foregroundStyle(Theme.textSecondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Image(systemName: expanded ? "chevron.up" : "chevron.down")
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(Theme.textTertiary)

            iconButton("safari", tint: Theme.link) { Reveal.browser(port: port) }
                .help("Open http://localhost:\(port)")

            Spacer().frame(width: 2)

            killButton
        }
    }

    private var killButton: some View {
        Button(action: onFree) {
            Image(systemName: "xmark")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(killHover ? .white : Theme.danger)
                .frame(width: 26, height: 26)
                .background(Circle().fill(killHover ? Theme.danger : Theme.danger.opacity(0.15)))
                .overlay(Circle().strokeBorder(Theme.danger.opacity(killHover ? 0 : 0.30), lineWidth: 1.2))
                .scaleEffect(killHover ? 1.08 : 1)
        }
        .buttonStyle(.plain)
        .onHover { killHover = $0 }
        .animation(.easeOut(duration: 0.12), value: killHover)
        .help("Free port \(port) — quit \(primary?.command ?? "process")")
    }

    private var scopeBadge: some View {
        Text(loopbackOnly ? "local" : (primary?.scopeLabel ?? "all"))
            .font(Theme.mono(9, .semibold))
            .foregroundStyle(loopbackOnly ? Theme.textTertiary : Theme.inUse)
            .padding(.horizontal, 5).padding(.vertical, 1)
            .background(Capsule().fill(Color.white.opacity(0.06)))
            .overlay(Capsule().strokeBorder(Theme.stroke, lineWidth: 1))
    }

    // MARK: Detail (expanded)

    private var detail: some View {
        VStack(alignment: .leading, spacing: 8) {
            Divider().overlay(Theme.stroke).padding(.vertical, 8)

            infoRow("command", primary?.commandLine ?? "—", copyable: true)
            infoRow("owner", primary?.user ?? "—")
            infoRow("binds", bindsDisplay)
            if let cwd = primary?.cwd { cwdRow(cwd) }

            FlowLayout(spacing: 6) {
                tag(pinned ? "unpin" : "pin", accent: true, action: onTogglePin)
                tag("copy port") { Clipboard.copy("\(port)") }
                tag("copy pid") { Clipboard.copy(pidList) }
                tag("copy url") { Clipboard.copy("http://localhost:\(port)") }
            }
            .padding(.top, 4)
        }
    }

    private func infoRow(_ label: String, _ value: String, copyable: Bool = false) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text(label)
                .font(Theme.mono(9.5, .medium))
                .foregroundStyle(Theme.textTertiary)
                .frame(width: 58, alignment: .leading)
            Text(value)
                .font(Theme.mono(10.5))
                .foregroundStyle(Theme.textSecondary)
                .textSelection(.enabled)
                .lineLimit(3)
                .frame(maxWidth: .infinity, alignment: .leading)
            if copyable {
                Button { Clipboard.copy(value) } label: {
                    Image(systemName: "doc.on.doc").font(.system(size: 9))
                        .foregroundStyle(Theme.textTertiary)
                }.buttonStyle(.plain).help("Copy")
            }
        }
    }

    private func cwdRow(_ cwd: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text("cwd")
                .font(Theme.mono(9.5, .medium))
                .foregroundStyle(Theme.textTertiary)
                .frame(width: 58, alignment: .leading)
            VStack(alignment: .leading, spacing: 5) {
                Text(cwd)
                    .font(Theme.mono(10.5))
                    .foregroundStyle(Theme.textSecondary)
                    .textSelection(.enabled)
                    .lineLimit(2).truncationMode(.middle)
                HStack(spacing: 8) {
                    tag("finder") { Reveal.inFinder(cwd) }
                    tag("terminal") { Reveal.inTerminal(cwd) }
                    tag("copy") { Clipboard.copy(cwd) }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: Small controls

    @ViewBuilder
    private func iconButton(_ symbol: String, tint: Color, action: @escaping () -> Void) -> some View {
        HoverIcon(symbol: symbol, tint: tint, action: action)
    }

    private func tag(_ title: String, accent: Bool = false, action: @escaping () -> Void) -> some View {
        TagButton(title: title, accent: accent, action: action)
    }
}

/// A small pill button used for inline actions in the expanded card.
private struct TagButton: View {
    let title: String
    var accent: Bool = false
    let action: () -> Void
    @State private var hover = false
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(Theme.mono(9.5, .medium))
                .foregroundStyle(hover ? .white : (accent ? Theme.inUse : Theme.textSecondary))
                .padding(.horizontal, 8).padding(.vertical, 3)
                .background(Capsule().fill(hover ? (accent ? Theme.inUse : Color.white.opacity(0.14))
                                                 : Color.white.opacity(0.06)))
                .overlay(Capsule().strokeBorder(Theme.stroke, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .onHover { hover = $0 }
    }
}

/// A round icon button with hover fill.
private struct HoverIcon: View {
    let symbol: String
    let tint: Color
    let action: () -> Void
    @State private var hover = false
    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(hover ? .white : tint)
                .frame(width: 26, height: 26)
                .background(Circle().fill(hover ? tint : tint.opacity(0.12)))
                .scaleEffect(hover ? 1.08 : 1)
        }
        .buttonStyle(.plain)
        .onHover { hover = $0 }
        .animation(.easeOut(duration: 0.12), value: hover)
    }
}
