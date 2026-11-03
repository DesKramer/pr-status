import Foundation
import XCTest
@testable import PRStatus

final class PullRequestTests: XCTestCase {
    func testLiveGitHubResponseWhenEnabled() async throws {
        guard ProcessInfo.processInfo.environment["PR_STATUS_LIVE_TEST"] == "1" else {
            throw XCTSkip("Set PR_STATUS_LIVE_TEST=1 to query GitHub")
        }

        let pullRequests = try await GitHubService().fetchPullRequests()

        XCTAssertFalse(pullRequests.isEmpty)
        XCTAssertTrue(pullRequests.allSatisfy { $0.url.host == "github.com" })
    }

    func testCheckSummaryCountsPassedFailedAndPendingChecks() {
        let checks = [
            StatusCheck(typeName: "CheckRun", status: "COMPLETED", conclusion: "SUCCESS", state: nil),
            StatusCheck(typeName: "CheckRun", status: "COMPLETED", conclusion: "SKIPPED", state: nil),
            StatusCheck(typeName: "CheckRun", status: "COMPLETED", conclusion: "FAILURE", state: nil),
            StatusCheck(typeName: "CheckRun", status: "IN_PROGRESS", conclusion: nil, state: nil),
            StatusCheck(typeName: "StatusContext", status: nil, conclusion: nil, state: "PENDING")
        ]

        let summary = CheckSummary(checks: checks)

        XCTAssertEqual(summary.passed, 2)
        XCTAssertEqual(summary.failed, 1)
        XCTAssertEqual(summary.pending, 2)
        XCTAssertEqual(summary.total, 5)
        XCTAssertEqual(summary.text, "2/5 passing · 1 failed · 2 running")
    }

    func testApprovalIsReadFromLatestReviews() throws {
        let json = """
        {
          "number": 42,
          "title": "Ship it",
          "headRefName": "dk/ship-it",
          "url": "https://github.com/CosineAI/cosine-monorepo/pull/42",
          "isDraft": false,
          "reviewDecision": "REVIEW_REQUIRED",
          "statusCheckRollup": [],
          "latestReviews": [{"state": "APPROVED"}],
          "updatedAt": "2026-01-01T00:00:00Z"
        }
        """

        let pullRequest = try JSONDecoder().decode(PullRequest.self, from: Data(json.utf8))

        XCTAssertTrue(pullRequest.hasApproval)
    }
}
