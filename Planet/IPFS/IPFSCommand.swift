import Foundation

struct IPFSCommand {
    // executables are under <project_root>/Planet/IPFS/go-ipfs-executables
    // version: 0.12.2, last updated 2022-04-15
    // NOTE: executables must have executable permission in source code
    static let IPFSExecutableURL: URL = {
        switch ProcessInfo.processInfo.machineHardwareName {
        case "arm64":
            return Bundle.main.url(forResource: "ipfs-arm64", withExtension: nil)!
        case "x86_64":
            return Bundle.main.url(forResource: "ipfs-amd64", withExtension: nil)!
        default:
            fatalError("Planet is not supported on your operating system.")
        }
    }()

    static let IPFSRepositoryURL: URL = {
        // ~/Library/Containers/xyz.planetable.Planet/Data/Library/Application\ Support/ipfs/
        let url = URLUtils.applicationSupportPath.appendingPathComponent("ipfs", isDirectory: true)
        try! FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }()

    let arguments: [String]

    @discardableResult func run() throws -> (ret: Int, out: Data, err: Data) {
        let process = Process()
        process.executableURL = IPFSCommand.IPFSExecutableURL
        process.arguments = arguments

        var env = ProcessInfo.processInfo.environment
        env["IPFS_PATH"] = IPFSCommand.IPFSRepositoryURL.path
        process.environment = env

        let outputPipe = Pipe()
        var outputData = Data()
        outputPipe.fileHandleForReading.readabilityHandler = { handler in
            let data = handler.availableData
            guard data.count > 0 else {
                try? handler.close()
                return
            }
            outputData.append(data)
        }
        process.standardOutput = outputPipe

        let errorPipe = Pipe()
        var errorData = Data()
        errorPipe.fileHandleForReading.readabilityHandler = { handler in
            let data = handler.availableData
            guard data.count > 0 else {
                try? handler.close()
                return
            }
            errorData.append(data)
        }
        process.standardError = errorPipe

        try process.run()
        process.waitUntilExit()

        outputPipe.fileHandleForReading.readabilityHandler = nil
        errorPipe.fileHandleForReading.readabilityHandler = nil

        return (Int(process.terminationStatus), outputData, errorData)
    }

    func run(
        outHandler: ((_ data: Data) -> Void)? = nil,
        errHandler: ((_ data: Data) -> Void)? = nil,
        completionHandler: ((_ ret: Int) -> Void)? = nil
    ) throws {
        let process = Process()
        process.executableURL = IPFSCommand.IPFSExecutableURL
        process.arguments = arguments

        var env = ProcessInfo.processInfo.environment
        env["IPFS_PATH"] = IPFSCommand.IPFSRepositoryURL.path
        process.environment = env

        let outputPipe = Pipe()
        outputPipe.fileHandleForReading.readabilityHandler = { handler in
            let data = handler.availableData
            guard data.count > 0 else {
                try? handler.close()
                return
            }
            outHandler?(data)
        }
        process.standardOutput = outputPipe

        let errorPipe = Pipe()
        errorPipe.fileHandleForReading.readabilityHandler = { handler in
            let data = handler.availableData
            guard data.count > 0 else {
                try? handler.close()
                return
            }
            errHandler?(data)
        }
        process.standardError = errorPipe

        try process.run()

        process.terminationHandler = { process in
            outputPipe.fileHandleForReading.readabilityHandler = nil
            errorPipe.fileHandleForReading.readabilityHandler = nil
            completionHandler?(Int(process.terminationStatus))
        }
    }

    static func IPFSInit() -> IPFSCommand {
        IPFSCommand(arguments: ["init"])
    }

    static func updateAPIPort(port: UInt16) -> IPFSCommand {
        IPFSCommand(arguments: ["config", "Addresses.API", "/ip4/127.0.0.1/tcp/\(port)"])
    }

    static func updateGatewayPort(port: UInt16) -> IPFSCommand {
        IPFSCommand(arguments: ["config", "Addresses.Gateway", "/ip4/127.0.0.1/tcp/\(port)"])
    }

    static func updateSwarmPort(port: UInt16) -> IPFSCommand {
        IPFSCommand(arguments: [
            "config",
            "Addresses.Swarm",
            "[\"/ip4/0.0.0.0/tcp/\(port)\", \"/ip6/::/tcp/\(port)\", \"/ip4/0.0.0.0/udp/\(port)/quic\", \"/ip6/::/udp/\(port)/quic\"]",
            "--json"
        ])
    }

    static func setPeers(peersJSON: String) -> IPFSCommand {
        IPFSCommand(arguments: [
            "config",
            "Peering.Peers",
            peersJSON,
            "--json"
        ])
    }

    static func launchDaemon() -> IPFSCommand {
        IPFSCommand(arguments: ["daemon", "--enable-namesys-pubsub", "--enable-pubsub-experiment"])
    }

    static func shutdownDaemon() -> IPFSCommand {
        IPFSCommand(arguments: ["shutdown"])
    }

    static func addDirectory(directory: URL) -> IPFSCommand {
        IPFSCommand(arguments: ["add", "-r", directory.path, "--cid-version=1", "--quieter"])
    }

    static func getFileCID(file: URL) -> IPFSCommand {
        IPFSCommand(arguments: ["add", file.path, "--cid-version=1", "--only-hash"])
    }

    static func exportKey(name: String, target: URL) -> IPFSCommand {
        IPFSCommand(arguments: ["key", "export", name, "-o", target.path])
    }

    static func importKey(name: String, target: URL) -> IPFSCommand {
        IPFSCommand(arguments: ["key", "import", name, target.path])
    }

    // NOTE: IPFS CLI calls internal HTTP API to communicate
    //       The following commands can be executed by calling HTTP API for easier async await
    static func resolveIPNS(ipns: String) -> IPFSCommand {
        IPFSCommand(arguments: ["name", "resolve", ipns])
    }

    static func generateKey(name: String) -> IPFSCommand {
        IPFSCommand(arguments: ["key", "gen", name])
    }

    static func deleteKey(name: String) -> IPFSCommand {
        IPFSCommand(arguments: ["key", "rm", name])
    }
}

struct IPFSMigration {
    static let repoVersion = 12

    static let RepoMigrationExecutableURL: URL = {
        switch ProcessInfo.processInfo.machineHardwareName {
        case "arm64":
            return Bundle.main.url(forResource: "fs-repo-migrations-arm64", withExtension: nil)!
        case "x86_64":
            return Bundle.main.url(forResource: "fs-repo-migrations-amd64", withExtension: nil)!
        default:
            fatalError("Planet is not supported on your operating system.")
        }
    }()

    static func migrate() throws -> (ret: Int, out: Data, err: Data) {
        let process = Process()
        process.executableURL = RepoMigrationExecutableURL
        process.arguments = [
            "-y",                       // do not request interactive confirm ("migrate? [y/N]")
            "-to", String(repoVersion), // do not migrate to latest (in case IPFS packed is not the latest)
            "-revert-ok"                // migrate to an earlier version if user downgrades our app
        ]

        var env = ProcessInfo.processInfo.environment
        env["IPFS_PATH"] = IPFSCommand.IPFSRepositoryURL.path
        process.environment = env

        let outputPipe = Pipe()
        var outputData = Data()
        outputPipe.fileHandleForReading.readabilityHandler = { handler in
            let data = handler.availableData
            guard data.count > 0 else {
                try? handler.close()
                return
            }
            outputData.append(data)
        }
        process.standardOutput = outputPipe

        let errorPipe = Pipe()
        var errorData = Data()
        errorPipe.fileHandleForReading.readabilityHandler = { handler in
            let data = handler.availableData
            guard data.count > 0 else {
                try? handler.close()
                return
            }
            errorData.append(data)
        }
        process.standardError = errorPipe

        try process.run()
        process.waitUntilExit()

        outputPipe.fileHandleForReading.readabilityHandler = nil
        errorPipe.fileHandleForReading.readabilityHandler = nil

        return (Int(process.terminationStatus), outputData, errorData)
    }
}
