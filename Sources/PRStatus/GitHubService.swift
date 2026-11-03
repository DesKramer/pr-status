import Foundation

struct GitHubService: Sendable {
    static let repository = "CosineAI/cosine-monorepo"

    func fetchPullRequests() async throws -> [PullRequest] {
        try await Task.detached(priority: .utility) {
            let data = try Self.runGitHubCLI()
            do {
                return try JSONDecoder().decode([PullRequest].self, from: data)
            } catch {
                throw GitHubServiceError.invalidResponse(error.localizedDescription)
            }
        }.value
    }

    private static func runGitHubCLI() throws -> Data {
        let process = Process()
        let pipe = Pipe()

        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = [
            "gh", "pr", "list",
            "--repo", repository,
            "--author", "@me",
            "--state", "open",
            "--limit", "100",
            "--json", "number,title,headRefName,url,isDraft,reviewDecision,statusCheckRollup,latestReviews,updatedAt"
        ]
        process.standardOutput = pipe
        process.standardError = pipe

        var environment = ProcessInfo.processInfo.environment
        let existingPath = environment["PATH"] ?? ""
        environment["PATH"] = [
            "/opt/homebrew/bin",
            "/usr/local/bin",
            "/usr/bin",
            "/bin",
            existingPath
        ].joined(separator: ":")
        process.environment = environment

        do {
            try process.run()
        } catch {
            throw GitHubServiceError.cliUnavailable
        }

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            let message = String(data: data, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines)
            throw GitHubServiceError.commandFailed(message?.isEmpty == false ? message! : "gh exited with status \(process.terminationStatus)")
        }

        return data
    }
}

enum GitHubServiceError: LocalizedError {
    case cliUnavailable
    case commandFailed(String)
    case invalidResponse(String)

    var errorDescription: String? {
        switch self {
        case .cliUnavailable:
            return "GitHub CLI was not found. Install gh and run gh auth login."
        case .commandFailed(let message):
            return message
        case .invalidResponse(let message):
            return "Could not read GitHub's response: \(message)"
        }
    }
}
