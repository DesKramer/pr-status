import Foundation

struct PullRequest: Decodable, Identifiable, Sendable {
    let number: Int
    let title: String
    let headRefName: String
    let url: URL
    let isDraft: Bool
    let reviewDecision: String
    let statusCheckRollup: [StatusCheck]
    let latestReviews: [Review]
    let updatedAt: String

    var id: Int { number }

    var hasApproval: Bool {
        latestReviews.contains { $0.state.uppercased() == "APPROVED" }
            || reviewDecision.uppercased() == "APPROVED"
    }

    var hasChangesRequested: Bool {
        latestReviews.contains { $0.state.uppercased() == "CHANGES_REQUESTED" }
            || reviewDecision.uppercased() == "CHANGES_REQUESTED"
    }

    var checkSummary: CheckSummary {
        CheckSummary(checks: statusCheckRollup)
    }
}

struct Review: Decodable, Sendable {
    let state: String
}

struct StatusCheck: Decodable, Sendable {
    let typeName: String?
    let status: String?
    let conclusion: String?
    let state: String?

    enum CodingKeys: String, CodingKey {
        case typeName = "__typename"
        case status
        case conclusion
        case state
    }
}

struct CheckSummary: Equatable, Sendable {
    let passed: Int
    let failed: Int
    let pending: Int
    let total: Int

    init(checks: [StatusCheck]) {
        var passed = 0
        var failed = 0
        var pending = 0

        for check in checks {
            let status = check.status?.uppercased()
            let conclusion = check.conclusion?.uppercased()
            let state = check.state?.uppercased()

            if state == "PENDING" || state == "EXPECTED" || (status != nil && status != "COMPLETED") {
                pending += 1
            } else if ["SUCCESS", "NEUTRAL", "SKIPPED"].contains(conclusion)
                        || state == "SUCCESS" {
                passed += 1
            } else {
                failed += 1
            }
        }

        self.passed = passed
        self.failed = failed
        self.pending = pending
        total = checks.count
    }

    var text: String {
        guard total > 0 else { return "No checks" }

        var parts = ["\(passed)/\(total) passing"]
        if failed > 0 {
            parts.append("\(failed) failed")
        }
        if pending > 0 {
            parts.append("\(pending) running")
        }
        return parts.joined(separator: " · ")
    }

    var symbolName: String {
        if failed > 0 { return "xmark.circle.fill" }
        if pending > 0 { return "clock.fill" }
        if total == 0 { return "minus.circle.fill" }
        return "checkmark.circle.fill"
    }
}
