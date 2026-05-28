import SwiftUI

/// Maps a process command to a recognizable SF Symbol + accent color, so each
/// port reads at a glance (node vs postgres vs docker …).
enum ProcessIcon {
    struct Style { let symbol: String; let color: Color }

    private struct Rule { let keys: [String]; let symbol: String; let color: Color }

    // First matching rule wins; order specific → generic.
    private static let rules: [Rule] = [
        .init(keys: ["postgres", "postmaster", "pg_"], symbol: "cylinder.fill",            color: c(0.36, 0.62, 0.92)),
        .init(keys: ["mysql", "mariadb"],              symbol: "cylinder.fill",            color: c(0.20, 0.62, 0.66)),
        .init(keys: ["redis"],                         symbol: "cylinder.split.1x2.fill",  color: c(0.85, 0.30, 0.24)),
        .init(keys: ["mongo"],                         symbol: "leaf.fill",                color: c(0.34, 0.72, 0.40)),
        .init(keys: ["docker", "containerd", "podman"],symbol: "shippingbox.fill",         color: c(0.16, 0.62, 0.90)),
        .init(keys: ["nginx", "httpd", "apache", "caddy", "traefik"], symbol: "globe",     color: c(0.30, 0.74, 0.66)),
        .init(keys: ["node", "npm", "yarn", "pnpm", "next", "vite", "deno", "bun", "esbuild", "webpack"],
              symbol: "hexagon.fill",   color: c(0.51, 0.78, 0.35)),
        .init(keys: ["python", "gunicorn", "uvicorn", "flask", "django", "celery", "uwsgi"],
              symbol: "chevron.left.forwardslash.chevron.right", color: c(0.30, 0.56, 0.90)),
        .init(keys: ["ruby", "rails", "puma", "rackup", "sidekiq"], symbol: "diamond.fill", color: c(0.86, 0.28, 0.27)),
        .init(keys: ["java", "kotlin", "gradle", "tomcat", "spring"], symbol: "cup.and.saucer.fill", color: c(0.90, 0.55, 0.20)),
        .init(keys: ["go", "golang"],                  symbol: "g.circle.fill",            color: c(0.32, 0.78, 0.85)),
        .init(keys: ["php", "php-fpm", "artisan"],     symbol: "p.circle.fill",            color: c(0.47, 0.45, 0.78)),
        .init(keys: ["rust", "cargo"],                 symbol: "gearshape.fill",           color: c(0.83, 0.46, 0.28)),
        .init(keys: ["dotnet", "mono"],                symbol: "number.square.fill",       color: c(0.42, 0.35, 0.80)),
        .init(keys: ["code", "electron", "cursor"],    symbol: "curlybraces",              color: c(0.33, 0.55, 0.95)),
        .init(keys: ["ssh", "sshd"],                   symbol: "lock.fill",                color: c(0.62, 0.66, 0.72)),
        .init(keys: ["rapportd", "controlce", "sharingd", "airplay", "remoted"],
              symbol: "dot.radiowaves.left.and.right", color: c(0.55, 0.58, 0.64)),
    ]

    static func style(for command: String) -> Style {
        let c = command.lowercased()
        for rule in rules where rule.keys.contains(where: { c.contains($0) }) {
            return Style(symbol: rule.symbol, color: rule.color)
        }
        return Style(symbol: "terminal.fill", color: Color(red: 0.62, green: 0.66, blue: 0.72))
    }

    private static func c(_ r: Double, _ g: Double, _ b: Double) -> Color {
        Color(red: r, green: g, blue: b)
    }
}

/// The leading badge on each in-use port card: the process icon in a tinted
/// tile with a soft static glow.
struct ProcessBadge: View {
    let command: String
    var body: some View {
        let s = ProcessIcon.style(for: command)
        Image(systemName: s.symbol)
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(s.color)
            .frame(width: 30, height: 30)
            .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(s.color.opacity(0.15)))
            .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).strokeBorder(s.color.opacity(0.30), lineWidth: 1))
            .shadow(color: s.color.opacity(0.40), radius: 5) // static glow
    }
}
