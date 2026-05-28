import Foundation

/// One process listening on one TCP port, with a full info package.
struct PortProcess: Hashable {
    let port: Int
    let pid: Int
    let command: String        // short name, e.g. "node"
    let commandLine: String    // full args, e.g. "node /Users/.../server.js"
    let user: String
    let cwd: String?           // working directory, if resolvable
    let uptime: String?        // e.g. "2h 13m"
    let addresses: Set<String> // e.g. ["127.0.0.1", "*"]

    var isLoopbackOnly: Bool {
        addresses.allSatisfy { $0.contains("127.0.0.1") || $0.contains("::1") || $0 == "localhost" }
    }

    var scopeLabel: String {
        if isLoopbackOnly { return "local" }
        if addresses.contains("*") || addresses.contains("0.0.0.0") || addresses.contains("::") { return "all" }
        return "ext"
    }
}

enum PortScanner {

    /// Ports developers most often care about. Shown free or occupied so you
    /// can see availability at a glance.
    static let commonDevPorts: [Int] = [
        3000, 3001, 3002, 3003,
        4000, 4200,
        5000, 5173, 5174,
        5432, 6379,
        8000, 8080, 8081, 8888,
        9000, 9090,
        27017
    ]

    /// Runs the scan pipeline and returns port -> processes. nil means the
    /// scanner itself failed (so the UI can distinguish from "nothing listening").
    static func scan() -> [Int: [PortProcess]]? {
        guard let raw = run("/usr/sbin/lsof",
                            ["-iTCP", "-sTCP:LISTEN", "-P", "-n", "-FpcLn"]) else { return nil }

        struct Key: Hashable { let pid: Int; let port: Int }
        var commandFor: [Key: String] = [:]
        var userFor: [Key: String] = [:]
        var addrsFor: [Key: Set<String>] = [:]
        var pids = Set<Int>()

        var pid = 0, command = "", user = ""
        for line in raw.split(separator: "\n", omittingEmptySubsequences: true) {
            guard let tag = line.first else { continue }
            let value = String(line.dropFirst())
            switch tag {
            case "p": pid = Int(value) ?? 0; pids.insert(pid)
            case "c": command = value
            case "L": user = value
            case "n":
                guard let (addr, port) = parseNameField(value) else { continue }
                let key = Key(pid: pid, port: port)
                commandFor[key] = command
                userFor[key] = user
                addrsFor[key, default: []].insert(addr)
            default: break
            }
        }

        // Enrich each pid with full command line, uptime, and cwd (batched).
        let meta = processMeta(pids: pids)
        let cwds = workingDirs(pids: pids)

        var byPort: [Int: Set<PortProcess>] = [:]
        for (key, addrs) in addrsFor {
            let m = meta[key.pid]
            let proc = PortProcess(
                port: key.port,
                pid: key.pid,
                command: commandFor[key] ?? m?.command ?? "?",
                commandLine: m?.args ?? commandFor[key] ?? "?",
                user: userFor[key] ?? "?",
                cwd: cwds[key.pid],
                uptime: m?.uptime,
                addresses: addrs
            )
            byPort[key.port, default: []].insert(proc)
        }
        return byPort.mapValues { Array($0).sorted { $0.pid < $1.pid } }
    }

    // MARK: - Enrichment

    private struct Meta { let command: String; let args: String; let uptime: String? }

    /// `ps` for full args + elapsed time, batched over all pids.
    private static func processMeta(pids: Set<Int>) -> [Int: Meta] {
        guard !pids.isEmpty,
              let out = run("/bin/ps", ["-ww", "-o", "pid=,etime=,comm=,args=",
                                        "-p", pids.map(String.init).joined(separator: ",")])
        else { return [:] }

        var result: [Int: Meta] = [:]
        for line in out.split(separator: "\n") {
            let trimmed = line.drop { $0 == " " }
            let parts = trimmed.split(separator: " ", maxSplits: 3,
                                      omittingEmptySubsequences: true).map(String.init)
            guard parts.count >= 4, let p = Int(parts[0]) else { continue }
            let comm = (parts[2] as NSString).lastPathComponent
            result[p] = Meta(command: comm, args: parts[3], uptime: prettyElapsed(parts[1]))
        }
        return result
    }

    /// `lsof -d cwd` for each pid's working directory, batched.
    private static func workingDirs(pids: Set<Int>) -> [Int: String] {
        guard !pids.isEmpty,
              let out = run("/usr/sbin/lsof", ["-a", "-d", "cwd", "-Fpn",
                                               "-p", pids.map(String.init).joined(separator: ",")])
        else { return [:] }

        var result: [Int: String] = [:]
        var pid = 0
        for line in out.split(separator: "\n") {
            guard let tag = line.first else { continue }
            let value = String(line.dropFirst())
            if tag == "p" { pid = Int(value) ?? 0 }
            else if tag == "n", result[pid] == nil { result[pid] = value }
        }
        return result
    }

    private static func prettyElapsed(_ e: String) -> String? {
        guard !e.isEmpty else { return nil }
        var str = e, days = 0
        if let dash = str.firstIndex(of: "-") {
            days = Int(str[..<dash]) ?? 0
            str = String(str[str.index(after: dash)...])
        }
        let parts = str.split(separator: ":").map { Int($0) ?? 0 }
        var h = 0, m = 0, s = 0
        switch parts.count {
        case 3: (h, m, s) = (parts[0], parts[1], parts[2])
        case 2: (m, s) = (parts[0], parts[1])
        case 1: s = parts[0]
        default: break
        }
        if days > 0 { return "\(days)d \(h)h" }
        if h > 0 { return "\(h)h \(m)m" }
        if m > 0 { return "\(m)m" }
        return "\(s)s"
    }

    /// Parses an lsof name field like "127.0.0.1:3000", "*:8080",
    /// "[::1]:5173" into (address, port).
    private static func parseNameField(_ name: String) -> (String, Int)? {
        let clean = name.split(separator: " ").first.map(String.init) ?? name
        guard let colon = clean.lastIndex(of: ":") else { return nil }
        let addr = String(clean[clean.startIndex..<colon])
        guard let port = Int(clean[clean.index(after: colon)...]) else { return nil }
        return (addr.isEmpty ? "*" : addr, port)
    }

    // MARK: - Process running

    /// Runs a command with a 5s ceiling so a hung tool can't freeze the app.
    private static func run(_ path: String, _ args: [String]) -> String? {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: path)
        task.arguments = args
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = FileHandle.nullDevice
        do { try task.run() } catch { return nil }

        let group = DispatchGroup()
        group.enter()
        var output: String?
        DispatchQueue.global().async {
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            output = String(data: data, encoding: .utf8)
            group.leave()
        }
        if group.wait(timeout: .now() + 5) == .timedOut {
            task.terminate()
            return nil
        }
        task.waitUntilExit()
        return output
    }

    // MARK: - Killing

    @discardableResult
    static func kill(pid: Int, signal: Int32) -> Bool {
        Foundation.kill(pid_t(pid), signal) == 0
    }

    /// Graceful kill: SIGTERM, then SIGKILL if it survives. Reports whether
    /// the process is actually gone.
    static func freePort(pid: Int, completion: @escaping (Bool) -> Void) {
        let sentTerm = kill(pid: pid, signal: SIGTERM)
        DispatchQueue.global().asyncAfter(deadline: .now() + 0.6) {
            var stillAlive = Foundation.kill(pid_t(pid), 0) == 0
            if stillAlive {
                kill(pid: pid, signal: SIGKILL)
                stillAlive = Foundation.kill(pid_t(pid), 0) == 0
            }
            DispatchQueue.main.async { completion(sentTerm && !stillAlive) }
        }
    }
}
