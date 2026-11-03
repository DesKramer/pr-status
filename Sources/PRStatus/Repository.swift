import Foundation

struct Repository: Decodable, Identifiable, Equatable, Sendable {
    let fullName: String
    let isPrivate: Bool

    var id: String { fullName }

    var owner: String {
        fullName.split(separator: "/", maxSplits: 1).first.map(String.init) ?? fullName
    }

    var name: String {
        let parts = fullName.split(separator: "/", maxSplits: 1)
        return parts.count == 2 ? String(parts[1]) : fullName
    }

    enum CodingKeys: String, CodingKey {
        case fullName = "full_name"
        case isPrivate = "private"
    }
}

enum RepositorySearch {
    static func filter(_ repositories: [Repository], query: String) -> [Repository] {
        let query = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return repositories }

        return repositories
            .compactMap { repository -> (Repository, Int)? in
                guard let score = score(query: query, candidate: repository.fullName) else {
                    return nil
                }
                return (repository, score)
            }
            .sorted {
                if $0.1 == $1.1 {
                    return $0.0.fullName.localizedCaseInsensitiveCompare($1.0.fullName) == .orderedAscending
                }
                return $0.1 > $1.1
            }
            .map(\.0)
    }

    static func score(query: String, candidate: String) -> Int? {
        let queryCharacters = Array(query.lowercased())
        let candidateCharacters = Array(candidate.lowercased())
        guard !queryCharacters.isEmpty else { return 0 }

        var candidateIndex = 0
        var previousMatch = -2
        var score = 0

        for queryCharacter in queryCharacters {
            var matchIndex: Int?
            while candidateIndex < candidateCharacters.count {
                if candidateCharacters[candidateIndex] == queryCharacter {
                    matchIndex = candidateIndex
                    candidateIndex += 1
                    break
                }
                candidateIndex += 1
            }

            guard let matchIndex else { return nil }

            if matchIndex == previousMatch + 1 {
                score += 12
            } else {
                score += 3
            }

            if matchIndex == 0 || "/-_".contains(candidateCharacters[matchIndex - 1]) {
                score += 8
            }

            previousMatch = matchIndex
        }

        return score - candidateCharacters.count
    }
}
