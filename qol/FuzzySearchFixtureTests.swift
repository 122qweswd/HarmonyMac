import Foundation

@main
struct FuzzySearchFixtureTests {
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
        let fixturePath = CommandLine.arguments.dropFirst().first ?? "qol/fuzzy-search-fixture-10000.json"
        let fixture = try JSONDecoder().decode(Fixture.self, from: Data(contentsOf: URL(fileURLWithPath: fixturePath)))
        precondition(fixture.files.count == 10_000, "Fixture must contain 10,000 entries")

        let candidates = fixture.files.map {
            FuzzyCandidate(id: $0.id, name: URL(fileURLWithPath: $0.fileName).deletingPathExtension().lastPathComponent)
        }
        let index = FuzzyCandidateIndex(candidates: candidates)
        for query in fixture.queries {
            let actual = Set(index.search(query.query, limit: 50).map { $0.candidate.id })
            let expected = Set(query.expectedIds)
            precondition(actual == expected, "\(query.query): expected \(expected), got \(actual)")
        }
        print("FuzzySearchFixtureTests passed")
    }
}
