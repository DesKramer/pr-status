import AppKit
import SwiftUI

struct MenuBarView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        VStack(spacing: 0) {
            header

            if let errorMessage = model.errorMessage {
                errorView(errorMessage)
            }

            if model.pullRequests.isEmpty && !model.isRefreshing {
                emptyView
            } else {
                pullRequestList
            }

            footer
        }
        .frame(width: 390)
        .task {
            await model.refresh()
        }
    }

    private var header: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Cosine PRs")
                    .font(.headline)
                Text(GitHubService.repository)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

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
            .help("Refresh")
        }
        .padding(14)
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

    private var emptyView: some View {
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
            if let lastUpdated = model.lastUpdated {
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
