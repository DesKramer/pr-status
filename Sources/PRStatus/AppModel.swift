import AppKit
import Combine
import Foundation
import OSLog

@MainActor
final class AppModel: ObservableObject {
    @Published private(set) var pullRequests: [PullRequest] = []
    @Published private(set) var isRefreshing = false
    @Published private(set) var errorMessage: String?
    @Published private(set) var lastUpdated: Date?

    private let service = GitHubService()
    private let logger = Logger(subsystem: "com.desmondkramer.pr-status", category: "refresh")
    private var pollingTask: Task<Void, Never>?

    var menuBarSymbol: String {
        if pullRequests.contains(where: { $0.checkSummary.failed > 0 }) {
            return "exclamationmark.triangle.fill"
        }
        if isRefreshing || pullRequests.contains(where: { $0.checkSummary.pending > 0 }) {
            return "arrow.triangle.2.circlepath"
        }
        if !pullRequests.isEmpty {
            return "checkmark.circle.fill"
        }
        return "arrow.triangle.branch"
    }

    func startPolling() {
        guard pollingTask == nil else { return }

        pollingTask = Task { [weak self] in
            while !Task.isCancelled {
                await self?.refresh()
                do {
                    try await Task.sleep(for: .seconds(120))
                } catch {
                    return
                }
            }
        }
    }

    func refresh() async {
        guard !isRefreshing else { return }

        isRefreshing = true
        defer { isRefreshing = false }

        do {
            pullRequests = try await service.fetchPullRequests()
            errorMessage = nil
            lastUpdated = Date()
            logger.info("Loaded \(self.pullRequests.count, privacy: .public) pull requests")
        } catch {
            errorMessage = error.localizedDescription
            logger.error("Refresh failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    func openInChrome(_ url: URL) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        process.arguments = ["-b", "com.google.Chrome", url.absoluteString]

        do {
            try process.run()
        } catch {
            NSWorkspace.shared.open(url)
        }
    }
}
