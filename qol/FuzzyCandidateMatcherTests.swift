import Foundation

@main
struct FuzzyCandidateMatcherTests {
    static func main() {
        let index = BaselineFuzzyCandidateIndex(candidates: [
            .init(id: "exact", name: "plan"),
            .init(id: "accent", name: "plán"),
            .init(id: "substitution", name: "plon"),
            .init(id: "swap", name: "plna"),
            .init(id: "short-a", name: "pla"),
            .init(id: "short-n", name: "pln"),
            .init(id: "too-long", name: "planet"),
            .init(id: "long-prefix", name: "planning"),
            .init(id: "long-middle", name: "deploymentplanreport"),
            .init(id: "long-suffix", name: "masterplan"),
            .init(id: "long-one-error", name: "archive-plon-2026"),
            .init(id: "unrelated", name: "readme"),
        ])

        let results = index.search("PLAN")
        assertTier(results, tier: .exact, ids: ["accent", "exact"])
        assertTier(results, tier: .sameLengthOneError, ids: ["substitution", "swap"])
        assertTier(results, tier: .oneCharacterShorter, ids: ["short-a", "short-n"])
        assertTier(results, tier: .containsQuery, ids: ["long-middle", "long-prefix", "long-suffix", "too-long"])
        assertTier(results, tier: .containsOneError, ids: ["long-one-error"])
        precondition(results.map(\.tier) == results.map(\.tier).sorted(), "Tiers are not ordered: \(results)")

        let partialOnlyIndex = BaselineFuzzyCandidateIndex(candidates: [
            .init(id: "long-prefix", name: "planning"),
            .init(id: "long-middle", name: "deploymentplanreport"),
            .init(id: "long-suffix", name: "masterplan"),
        ])
        assertTier(partialOnlyIndex.search("plan"), tier: .containsQuery,
                   ids: ["long-middle", "long-prefix", "long-suffix"])
        precondition(partialOnlyIndex.search("pxz").isEmpty,
                     "Unexpected partial match for a two-error query")
        print("FuzzyCandidateMatcherTests passed")
    }

    private static func assertTier(_ results: [BaselineFuzzyCandidateMatch], tier: BaselineFuzzyMatchTier, ids: Set<String>) {
        let actual = Set(results.filter { $0.tier == tier }.map { $0.candidate.id })
        precondition(actual == ids, "Expected \(ids) in \(tier), got \(actual)")
    }
}
