import AppKit
import SwiftUI

struct MenuBarView: View {
    @ObservedObject var model: AppModel
    @State private var isChoosingRepository = false
    @State private var repositoryQuery = ""

    private var showsRepositoryPicker: Bool {
        model.selectedRepository == nil || isChoosingRepository
    }

    var body: some View {
        VStack(spacing: 0) {
            header

            if showsRepositoryPicker {
                repositoryPicker
            } else {
                pullRequestContent
            }

            footer
        }
        .frame(width: 410)
        .task {
            if model.selectedRepository == nil {
                await model.loadRepositories()
            } else {
                await model.refresh()
            }
        }
    }

    private var header: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 3) {
                Text("PR Status")
                    .font(.headline)

                Button {
                    if showsRepositoryPicker && model.selectedRepository != nil {
                        isChoosingRepository = false
                    } else {
                        isChoosingRepository = true
                        Task { await model.loadRepositories() }
                    }
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "shippingbox")
                        Text(model.selectedRepository ?? "Choose a repository")
                            .lineLimit(1)
                            .truncationMode(.middle)
                        Image(systemName: showsRepositoryPicker && model.selectedRepository != nil ? "chevron.up" : "chevron.down")
                            .font(.caption2)
                    }
                }
                .buttonStyle(.plain)
                .font(.caption)
                .foregroundStyle(model.selectedRepository == nil ? Color.accentColor : Color.secondary)
                .help(model.selectedRepository == nil ? "Choose a repository" : "Change repository")
            }

            Spacer()

            if showsRepositoryPicker {
                if model.isLoadingRepositories {
                    ProgressView()
                        .controlSize(.small)
                }

                Button {
                    Task { await model.loadRepositories(force: true) }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(.borderless)
                .disabled(model.isLoadingRepositories)
                .help("Reload repositories")
            } else {
                if model.isRefreshing {
                    ProgressView()
                        .controlSize(.small)
                }

                Button {
                    Task { await model.refresh() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(.borderless)
                .disabled(model.isRefreshing)
                .help("Refresh pull requests")
            }
        }
        .padding(14)
    }

    @ViewBuilder
    private var pullRequestContent: some View {
        if let errorMessage = model.errorMessage {
            errorView(errorMessage)
        }

        if model.pullRequests.isEmpty && !model.isRefreshing {
            emptyPullRequestView
        } else {
            pullRequestList
        }
    }

    private var repositoryPicker: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Search all repositories", text: $repositoryQuery)
                    .textFieldStyle(.plain)
                if !repositoryQuery.isEmpty {
                    Button {
                        repositoryQuery = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(.quaternary.opacity(0.55), in: RoundedRectangle(cornerRadius: 8))
            .padding(.horizontal, 12)
            .padding(.bottom, 10)

            if let repositoryErrorMessage = model.repositoryErrorMessage {
                errorView(repositoryErrorMessage)
            }

            if model.repositories.isEmpty {
                repositoryEmptyView
            } else if filteredRepositories.isEmpty {
                ContentUnavailableView.search(text: repositoryQuery)
                    .frame(height: 220)
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(Array(filteredRepositories.enumerated()), id: \.element.id) { index, repository in
                            if index > 0 {
                                Divider()
                                    .padding(.leading, 42)
                            }

                            RepositoryRow(
                                repository: repository,
                                isSelected: repository.fullName == model.selectedRepository
                            ) {
                                model.selectRepository(repository)
                                isChoosingRepository = false
                                repositoryQuery = ""
                            }
                        }
                    }
                }
                .frame(height: min(CGFloat(filteredRepositories.count) * 48, 480))
            }
        }
    }

    private var filteredRepositories: [Repository] {
        RepositorySearch.filter(model.repositories, query: repositoryQuery)
    }

    private var repositoryEmptyView: some View {
        VStack(spacing: 8) {
            if model.isLoadingRepositories {
                ProgressView()
                Text("Loading repositories…")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Image(systemName: "shippingbox")
                    .font(.title2)
                    .foregroundStyle(.secondary)
                Text(model.repositoryErrorMessage == nil ? "No repositories found" : "Could not load repositories")
                    .font(.subheadline.weight(.medium))
                if model.repositoryErrorMessage == nil {
                    Text("The signed-in GitHub account has no accessible repositories.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 34)
    }

    private func errorView(_ message: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
            Text(message)
                .font(.caption)
                .textSelection(.enabled)
            Spacer(minLength: 0)
        }
        .padding(10)
        .background(Color.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))
        .padding(.horizontal, 12)
        .padding(.bottom, 8)
    }

    private var emptyPullRequestView: some View {
        VStack(spacing: 8) {
            Image(systemName: "arrow.triangle.branch")
                .font(.title2)
                .foregroundStyle(.secondary)
            Text(model.errorMessage == nil ? "No open PRs" : "Could not load PRs")
                .font(.subheadline.weight(.medium))
            if model.errorMessage == nil {
                Text("Open PRs authored by you will appear here.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 34)
    }

    private var pullRequestList: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(Array(model.pullRequests.enumerated()), id: \.element.id) { index, pullRequest in
                    if index > 0 {
                        Divider()
                            .padding(.leading, 14)
                    }
                    PullRequestRow(pullRequest: pullRequest) {
                        model.openInChrome(pullRequest.url)
                    }
                }
            }
        }
        .frame(height: pullRequestListHeight)
    }

    private var pullRequestListHeight: CGFloat {
        min(CGFloat(model.pullRequests.count) * 104, 520)
    }

    private var footer: some View {
        HStack {
            if showsRepositoryPicker {
                if model.repositories.isEmpty {
                    Text("Uses your gh login")
                } else {
                    Text("\(model.repositories.count) repositories")
                }
            } else if let lastUpdated = model.lastUpdated {
                Text("Updated ") + Text(lastUpdated, style: .relative)
            } else {
                Text("Uses your gh login")
            }

            Spacer()

            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
            .buttonStyle(.borderless)
        }
        .font(.caption)
        .foregroundStyle(.secondary)
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(.quaternary.opacity(0.45))
    }
}

private struct RepositoryRow: View {
    let repository: Repository
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: repository.isPrivate ? "lock.fill" : "shippingbox")
                    .frame(width: 18)
                    .foregroundStyle(.secondary)

                VStack(alignment: .leading, spacing: 1) {
                    Text(repository.name)
                        .font(.subheadline.weight(.medium))
                    Text(repository.owner)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark")
                        .foregroundStyle(Color.accentColor)
                }
            }
            .contentShape(Rectangle())
            .padding(.horizontal, 14)
            .padding(.vertical, 7)
        }
        .buttonStyle(.plain)
    }
}

private struct PullRequestRow: View {
    let pullRequest: PullRequest
    let action: () -> Void

    private var summary: CheckSummary { pullRequest.checkSummary }

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(pullRequest.headRefName)
                        .font(.system(.body, design: .monospaced, weight: .semibold))
                        .lineLimit(1)
                        .truncationMode(.middle)

                    Spacer(minLength: 8)

                    Text("#\(pullRequest.number)")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }

                Text(pullRequest.title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)

                HStack(spacing: 12) {
                    Label(summary.text, systemImage: summary.symbolName)
                        .foregroundStyle(checkColor)

                    Label(reviewText, systemImage: reviewSymbol)
                        .foregroundStyle(reviewColor)

                    if pullRequest.isDraft {
                        Text("Draft")
                            .foregroundStyle(.secondary)
                    }
                }
                .font(.caption.weight(.medium))
                .lineLimit(1)
            }
            .contentShape(Rectangle())
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
        }
        .buttonStyle(.plain)
        .help("Open in Google Chrome")
    }

    private var checkColor: Color {
        if summary.failed > 0 { return .red }
        if summary.pending > 0 { return .orange }
        if summary.total == 0 { return .secondary }
        return .green
    }

    private var reviewText: String {
        if pullRequest.hasChangesRequested { return "Changes requested" }
        if pullRequest.hasApproval { return "Approved" }
        return "No approval"
    }

    private var reviewSymbol: String {
        if pullRequest.hasChangesRequested { return "exclamationmark.bubble.fill" }
        if pullRequest.hasApproval { return "hand.thumbsup.fill" }
        return "hand.thumbsup"
    }

    private var reviewColor: Color {
        if pullRequest.hasChangesRequested { return .red }
        if pullRequest.hasApproval { return .green }
        return .secondary
    }
}
