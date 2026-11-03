import AppKit
import Combine
import Foundation
import OSLog

@MainActor
final class AppModel: ObservableObject {
    @Published private(set) var pullRequests: [PullRequest] = []
    @Published private(set) var repositories: [Repository] = []
    @Published private(set) var selectedRepository: String?
    @Published private(set) var isRefreshing = false
    @Published private(set) var isLoadingRepositories = false
    @Published private(set) var errorMessage: String?
    @Published private(set) var repositoryErrorMessage: String?
    @Published private(set) var lastUpdated: Date?

    private static let selectedRepositoryKey = "selectedRepository"

    private let service = GitHubService()
    private let defaults: UserDefaults
    private let logger = Logger(subsystem: "com.desmondkramer.pr-status", category: "refresh")
    private var pollingTask: Task<Void, Never>?
    private var activeRefreshID: UUID?
    private var refreshingRepository: String?

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        selectedRepository = defaults.string(forKey: Self.selectedRepositoryKey)
    }

    var menuBarSymbol: String {
        guard selectedRepository != nil else {
            return "arrow.triangle.branch"
        }
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
                if self?.selectedRepository == nil {
                    await self?.loadRepositories()
                } else {
                    await self?.refresh()
                }

                do {
                    try await Task.sleep(for: .seconds(120))
                } catch {
                    return
                }
            }
        }
    }

    func loadRepositories(force: Bool = false) async {
        guard !isLoadingRepositories else { return }
        if !force && !repositories.isEmpty { return }

        isLoadingRepositories = true
        defer { isLoadingRepositories = false }

        do {
            repositories = try await service.fetchRepositories()
            repositoryErrorMessage = nil
            logger.info("Loaded \(self.repositories.count, privacy: .public) repositories")
        } catch {
            repositoryErrorMessage = error.localizedDescription
            logger.error("Repository discovery failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    func selectRepository(_ repository: Repository) {
        guard selectedRepository != repository.fullName else { return }

        selectedRepository = repository.fullName
        defaults.set(repository.fullName, forKey: Self.selectedRepositoryKey)
        pullRequests = []
        errorMessage = nil
        lastUpdated = nil

        activeRefreshID = nil
        refreshingRepository = nil
        isRefreshing = false

        Task {
            await refresh()
        }
    }

    func refresh() async {
        guard let repository = selectedRepository else { return }
        if isRefreshing && refreshingRepository == repository { return }

        let refreshID = UUID()
        activeRefreshID = refreshID
        refreshingRepository = repository
        isRefreshing = true

        defer {
            if activeRefreshID == refreshID {
                isRefreshing = false
                refreshingRepository = nil
            }
        }

        do {
            let loadedPullRequests = try await service.fetchPullRequests(repository: repository)
            guard activeRefreshID == refreshID, selectedRepository == repository else { return }

            pullRequests = loadedPullRequests
            errorMessage = nil
            lastUpdated = Date()
            logger.info("Loaded \(self.pullRequests.count, privacy: .public) pull requests for \(repository, privacy: .public)")
        } catch {
            guard activeRefreshID == refreshID, selectedRepository == repository else { return }

            errorMessage = error.localizedDescription
            logger.error("Refresh failed for \(repository, privacy: .public): \(error.localizedDescription, privacy: .public)")
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
