import Foundation

@main
struct MyersFuzzyBenchmark {
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
        let arguments = Array(CommandLine.arguments.dropFirst())
        let fixturePath = arguments.first ?? "qol/fuzzy-search-fixture-10000.json"
        let iterations = Int(arguments.dropFirst().first ?? "50") ?? 50
        let fixture = try JSONDecoder().decode(
            Fixture.self,
            from: Data(contentsOf: URL(fileURLWithPath: fixturePath))
        )
        precondition(fixture.files.count == 10_000)

        let myersCandidates = fixture.files.map {
            FuzzyCandidate(
                id: $0.id,
                name: URL(fileURLWithPath: $0.fileName).deletingPathExtension().lastPathComponent
            )
        }
        let baselineCandidates = fixture.files.map {
            BaselineFuzzyCandidate(
                id: $0.id,
                name: URL(fileURLWithPath: $0.fileName).deletingPathExtension().lastPathComponent
            )
        }
        let baseline = BaselineFuzzyCandidateIndex(candidates: baselineCandidates)
        let optimized = MyersBitParallelFuzzySearch(candidates: myersCandidates)

        print("fixtureEntries=\(myersCandidates.count) iterationsPerQuery=\(iterations)")
        for query in fixture.queries {
            let expected = Set(query.expectedIds)
            let baselineResult = baseline.search(query.query, limit: 50)
            let optimizedResult = optimized.search(.init(query: query.query, limit: 50))
            let baselineIds = Set(baselineResult.map { $0.candidate.id })
            let optimizedIds = Set(optimizedResult.map { $0.candidate.id })
            print("query=\(query.query) baselineAccuracy=\(accuracy(actual: baselineIds, expected: expected)) optimizedAccuracy=\(accuracy(actual: optimizedIds, expected: expected))")

            let baselineRun = measure(iterations: iterations) {
                baseline.search(query.query, limit: 50).count
            }
            let optimizedRun = measure(iterations: iterations) {
                optimized.search(.init(query: query.query, limit: 50)).count
            }
            let baselineQPS = Double(iterations) / baselineRun.seconds
            let optimizedQPS = Double(iterations) / optimizedRun.seconds
            let speedup = baselineRun.seconds / max(optimizedRun.seconds, 0.000000001)
            print(String(format: "  baseline=%.3fms total (%.1f qps)", baselineRun.seconds * 1_000, baselineQPS))
            print(String(format: "  myers=%.3fms total (%.1f qps), speedup=%.2fx", optimizedRun.seconds * 1_000, optimizedQPS, speedup))
        }
    }

    private static func accuracy(actual: Set<String>, expected: Set<String>) -> String {
        let truePositives = actual.intersection(expected).count
        let precision = actual.isEmpty ? 1.0 : Double(truePositives) / Double(actual.count)
        let recall = expected.isEmpty ? 1.0 : Double(truePositives) / Double(expected.count)
        return String(format: "precision=%.3f recall=%.3f", precision, recall)
    }

    private static func measure(iterations: Int, operation: () -> Int) -> (seconds: Double, count: Int) {
        let start = DispatchTime.now().uptimeNanoseconds
        var count = 0
        for _ in 0..<iterations { count += operation() }
        let elapsed = DispatchTime.now().uptimeNanoseconds - start
        return (Double(elapsed) / 1_000_000_000, count)
    }
}
