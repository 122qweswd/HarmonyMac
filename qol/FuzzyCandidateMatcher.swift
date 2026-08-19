import Foundation

/// The match tiers are deliberately ordered by the requested retrieval priority.
public enum BaselineFuzzyMatchTier: Int, Comparable {
    case exact = 0
    case sameLengthOneError = 1
    case oneCharacterShorter = 2
    case containsQuery = 3
    case containsOneError = 4

    public static func < (lhs: BaselineFuzzyMatchTier, rhs: BaselineFuzzyMatchTier) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

public struct BaselineFuzzyCandidate: Equatable {
    public let id: String
    public let name: String

    public init(id: String, name: String) {
        self.id = id
        self.name = name
    }
}

public struct BaselineFuzzyCandidateMatch: Equatable {
    public let candidate: BaselineFuzzyCandidate
    public let tier: BaselineFuzzyMatchTier
}

/// Filename matcher for the following ordered rules:
/// 1. Exact normalized text.
/// 2. Same-length text with one substitution or one adjacent transposition.
/// 3. Text one character shorter after deleting one character from the query.
/// 4. Longer text that contains the query as a contiguous substring.
/// 5. Longer text that contains a same-length substring with one substitution
///    or one adjacent transposition.
///
/// Callers should index the filename stem (without its extension) as `name`.
public struct BaselineFuzzyCandidateIndex {
    private let candidates: [BaselineFuzzyCandidate]
    private let normalizedNames: [String]
    private let exact: [String: [Int]]
    private let byLength: [Int: [Int]]

    public init(candidates: [BaselineFuzzyCandidate]) {
        self.candidates = candidates
        self.normalizedNames = candidates.map { Self.normalize($0.name) }
        var exact: [String: [Int]] = [:]
        var byLength: [Int: [Int]] = [:]
        for (index, name) in normalizedNames.enumerated() {
            exact[name, default: []].append(index)
            byLength[Array(name).count, default: []].append(index)
        }
        self.exact = exact
        self.byLength = byLength
    }

    public func search(_ query: String, limit: Int = 50) -> [BaselineFuzzyCandidateMatch] {
        let query = Self.normalize(query)
        let queryLength = Array(query).count
        guard !query.isEmpty, limit > 0 else { return [] }

        var matches: [BaselineFuzzyCandidateMatch] = []
        let exactIndexes = Set(exact[query, default: []])
        matches += exactIndexes.map { BaselineFuzzyCandidateMatch(candidate: candidates[$0], tier: .exact) }

        for index in byLength[queryLength, default: []] where !exactIndexes.contains(index) {
            if Self.hasOneSubstitutionOrAdjacentSwap(query, normalizedNames[index]) {
                matches.append(BaselineFuzzyCandidateMatch(candidate: candidates[index], tier: .sameLengthOneError))
            }
        }

        if queryLength > 0 {
            for index in byLength[queryLength - 1, default: []] {
                if Self.isQueryWithOneCharacterDeleted(query, shorter: normalizedNames[index]) {
                    matches.append(BaselineFuzzyCandidateMatch(candidate: candidates[index], tier: .oneCharacterShorter))
                }
            }
        }

        for index in candidates.indices where normalizedNames[index].count > queryLength {
            if normalizedNames[index].contains(query) {
                matches.append(BaselineFuzzyCandidateMatch(candidate: candidates[index], tier: .containsQuery))
            } else if Self.containsOneSubstitutionOrAdjacentSwap(query, in: normalizedNames[index]) {
                matches.append(BaselineFuzzyCandidateMatch(candidate: candidates[index], tier: .containsOneError))
            }
        }

        return matches.sorted {
            $0.tier == $1.tier
                ? $0.candidate.name.localizedStandardCompare($1.candidate.name) == .orderedAscending
                : $0.tier < $1.tier
        }.prefix(limit).map { $0 }
    }

    private static func normalize(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "en_US_POSIX"))
    }

    private static func hasOneSubstitutionOrAdjacentSwap(_ query: String, _ candidate: String) -> Bool {
        let query = Array(query)
        let candidate = Array(candidate)
        guard query.count == candidate.count else { return false }

        let mismatches = query.indices.filter { query[$0] != candidate[$0] }
        if mismatches.count == 1 { return true }
        guard mismatches.count == 2, mismatches[1] == mismatches[0] + 1 else { return false }
        let first = mismatches[0]
        let second = mismatches[1]
        return query[first] == candidate[second] && query[second] == candidate[first]
    }

    private static func containsOneSubstitutionOrAdjacentSwap(_ query: String, in candidate: String) -> Bool {
        let characters = Array(candidate)
        let queryLength = Array(query).count
        guard characters.count > queryLength else { return false }
        for start in 0...(characters.count - queryLength) {
            if hasOneSubstitutionOrAdjacentSwap(query, String(characters[start..<(start + queryLength)])) {
                return true
            }
        }
        return false
    }

    private static func isQueryWithOneCharacterDeleted(_ query: String, shorter: String) -> Bool {
        let query = Array(query)
        let shorter = Array(shorter)
        guard query.count == shorter.count + 1 else { return false }

        var queryIndex = 0
        var shorterIndex = 0
        var skipped = false
        while queryIndex < query.count && shorterIndex < shorter.count {
            if query[queryIndex] == shorter[shorterIndex] {
                queryIndex += 1
                shorterIndex += 1
            } else if !skipped {
                skipped = true
                queryIndex += 1
            } else {
                return false
            }
        }
        return true
    }
}
