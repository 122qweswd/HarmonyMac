import Foundation

@main
struct MyersBitParallelFuzzySearchTests {
    private struct Fixture: Decodable {
        let queries: [Query]
        let files: [File]
    }

    private struct Query: Decodable {
        let query: String
        let expectedIds: [String]
    }

    private struct File: Decodable {
        let id: String
        let fileName: String
    }

    static func main() throws {
        try assertDistance("plan", "plon", is: 1)
        try assertDistance("myPhoto", "myPhoto", is: 0)
        try assertDistance("plan", "plna", is: 2) // Exchange is ranked separately as one group.
        let longChinese = String(repeating: "中文检索", count: 24)
        let changedChinese = String(longChinese.dropLast()) + "试"
        try assertDistance(longChinese, changedChinese, is: 1)
        let chineseSearch = MyersBitParallelFuzzySearch(candidates: [
            .init(id: "exact", name: longChinese),
            .init(id: "one-error", name: changedChinese),
        ])
        precondition(
            Set(chineseSearch.search(.init(query: longChinese)).map { $0.candidate.id }) == ["exact", "one-error"],
            "Long Chinese query did not return expected matches"
        )
        let triggeredWindowSearch = MyersBitParallelFuzzySearch(candidates: [
            .init(id: "first-char-error", name: "archive__xLaN__2026"),
            .init(id: "third-char-trigger", name: "archive__xxaN__2026"),
            .init(id: "too-far", name: "archive__xxzN__2026"),
        ])
        precondition(
            Set(triggeredWindowSearch.search(.init(query: "plan")).map { $0.candidate.id }) == ["first-char-error"],
            "Triggered window search did not keep the correct one-error result"
        )

        let fixturePath = CommandLine.arguments.dropFirst().first ?? "qol/fuzzy-search-fixture-10000.json"
        let fixture = try JSONDecoder().decode(Fixture.self, from: Data(contentsOf: URL(fileURLWithPath: fixturePath)))
        precondition(fixture.files.count == 10_000, "Fixture must contain 10,000 entries")
        let candidates = fixture.files.map {
            FuzzyCandidate(id: $0.id, name: URL(fileURLWithPath: $0.fileName).deletingPathExtension().lastPathComponent)
        }
        let search = MyersBitParallelFuzzySearch(candidates: candidates)
        for query in fixture.queries {
            let actual = Set(search.search(.init(query: query.query, limit: 50)).map { $0.candidate.id })
            precondition(actual == Set(query.expectedIds), "Unexpected results for \(query.query): \(actual)")
        }
        print("MyersBitParallelFuzzySearchTests passed")
    }

    private static func assertDistance(_ pattern: String, _ text: String, is expected: Int) throws {
        let distance = MyersBitParallel.distance(pattern: Array(pattern.unicodeScalars), text: Array(text.unicodeScalars))
        precondition(distance == expected, "Expected distance \(expected), got \(String(describing: distance))")
    }
}
