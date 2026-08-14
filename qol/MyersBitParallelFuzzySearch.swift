import Foundation

/// The match tiers are deliberately ordered by the requested retrieval priority.
public enum FuzzyMatchTier: Int, Comparable, Codable {
    case exact = 0
    case sameLengthOneError = 1
    case oneCharacterShorter = 2
    case containsQuery = 3
    case containsOneError = 4

    public static func < (lhs: FuzzyMatchTier, rhs: FuzzyMatchTier) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

public struct FuzzyCandidate: Equatable {
    public let id: String
    public let name: String

    public init(id: String, name: String) {
        self.id = id
        self.name = name
    }
}

public struct FuzzyCandidateMatch: Equatable {
    public let candidate: FuzzyCandidate
    public let tier: FuzzyMatchTier
}

public struct MyersFuzzySearchRequest {
    public let query: String
    public let limit: Int

    public init(query: String, limit: Int = 50) {
        self.query = query
        self.limit = limit
    }
}

/// Multiword bit-parallel Levenshtein distance over Unicode scalars.
/// It supports arbitrary pattern lengths by carrying additions and shifts across
/// 64-bit words; it does not require a predefined alphabet or Chinese dictionary.
public enum MyersBitParallel {
    public struct Pattern {
        private let length: Int
        private let wordCount: Int
        private let finalMask: UInt64
        private let equalityMasks: [Unicode.Scalar: [UInt64]]
        private let singleWordEqualityMasks: [Unicode.Scalar: UInt64]?

        public init?(_ scalars: [Unicode.Scalar]) {
            guard !scalars.isEmpty else { return nil }
            self.length = scalars.count
            self.wordCount = (scalars.count + 63) / 64
            let remainder = scalars.count % 64
            self.finalMask = remainder == 0 ? ~UInt64(0) : (UInt64(1) << UInt64(remainder)) - 1

            var masks: [Unicode.Scalar: [UInt64]] = [:]
            for (index, scalar) in scalars.enumerated() {
                let word = index / 64
                let bit = index % 64
                var mask = masks[scalar] ?? Array(repeating: 0, count: wordCount)
                mask[word] |= UInt64(1) << UInt64(bit)
                masks[scalar] = mask
            }
            self.equalityMasks = masks
            self.singleWordEqualityMasks = wordCount == 1 ? masks.mapValues { $0[0] } : nil
        }

        public func distance(to text: [Unicode.Scalar]) -> Int {
            if let masks = singleWordEqualityMasks {
                return singleWordDistance(to: text, masks: masks)
            }
            var positive = Array(repeating: ~UInt64(0), count: wordCount)
            positive[wordCount - 1] &= finalMask
            var negative = Array(repeating: UInt64(0), count: wordCount)
            var score = length

            for scalar in text {
                let equality = equalityMasks[scalar]
                var vertical = Array(repeating: UInt64(0), count: wordCount)
                var horizontal = Array(repeating: UInt64(0), count: wordCount)
                var positiveHorizontal = Array(repeating: UInt64(0), count: wordCount)
                var negativeHorizontal = Array(repeating: UInt64(0), count: wordCount)

                var addCarry: UInt64 = 0
                for word in 0..<wordCount {
                    let equalityWord = equality?[word] ?? 0
                    vertical[word] = equalityWord | negative[word]
                    let (sum, carry) = add(equalityWord & positive[word], positive[word], carry: addCarry)
                    addCarry = carry
                    horizontal[word] = (sum ^ positive[word]) | equalityWord
                    positiveHorizontal[word] = negative[word] | ~(horizontal[word] | positive[word])
                    negativeHorizontal[word] = positive[word] & horizontal[word]
                }

                let finalBit = UInt64(1) << UInt64((length - 1) % 64)
                if positiveHorizontal[wordCount - 1] & finalBit != 0 { score += 1 }
                if negativeHorizontal[wordCount - 1] & finalBit != 0 { score -= 1 }

                positiveHorizontal = shiftLeft(positiveHorizontal, initialBit: 1)
                negativeHorizontal = shiftLeft(negativeHorizontal, initialBit: 0)
                for word in 0..<wordCount {
                    positive[word] = negativeHorizontal[word] | ~(vertical[word] | positiveHorizontal[word])
                    negative[word] = positiveHorizontal[word] & vertical[word]
                }
                positive[wordCount - 1] &= finalMask
                negative[wordCount - 1] &= finalMask
            }
            return score
        }

        private func singleWordDistance(to text: [Unicode.Scalar], masks: [Unicode.Scalar: UInt64]) -> Int {
            let highestPatternBit = UInt64(1) << UInt64(length - 1)
            var positive = ~UInt64(0)
            var negative: UInt64 = 0
            var score = length
            for scalar in text {
                let equality = masks[scalar, default: 0]
                let vertical = equality | negative
                let horizontal = (((equality & positive) &+ positive) ^ positive) | equality
                var positiveHorizontal = negative | ~(horizontal | positive)
                var negativeHorizontal = positive & horizontal
                if positiveHorizontal & highestPatternBit != 0 { score += 1 }
                if negativeHorizontal & highestPatternBit != 0 { score -= 1 }
                positiveHorizontal = (positiveHorizontal << 1) | 1
                negativeHorizontal <<= 1
                positive = negativeHorizontal | ~(vertical | positiveHorizontal)
                negative = positiveHorizontal & vertical
            }
            return score
        }

        private func add(_ lhs: UInt64, _ rhs: UInt64, carry: UInt64) -> (UInt64, UInt64) {
            let (first, firstOverflow) = lhs.addingReportingOverflow(rhs)
            let (second, secondOverflow) = first.addingReportingOverflow(carry)
            return (second, firstOverflow || secondOverflow ? 1 : 0)
        }

        private func shiftLeft(_ values: [UInt64], initialBit: UInt64) -> [UInt64] {
            var result = Array(repeating: UInt64(0), count: values.count)
            var carry = initialBit
            for index in values.indices {
                let nextCarry = values[index] >> 63
                result[index] = (values[index] << 1) | carry
                carry = nextCarry
            }
            return result
        }
    }

    public static func distance(pattern: [Unicode.Scalar], text: [Unicode.Scalar]) -> Int? {
        Pattern(pattern)?.distance(to: text)
    }
}

/// Search interface preserving the requested ranking:
/// exact, equal-length one error/exchange, one character shorter, then matches
/// inside longer filenames. All comparison is case- and diacritic-insensitive.
public struct MyersBitParallelFuzzySearch {
    private let candidates: [FuzzyCandidate]
    private let normalized: [[Unicode.Scalar]]
    private let exact: [String: [Int]]
    private let byLength: [Int: [Int]]

    public init(candidates: [FuzzyCandidate]) {
        self.candidates = candidates
        let names = candidates.map { Self.normalize($0.name) }
        self.normalized = names.map { Array($0.unicodeScalars) }
        var exact: [String: [Int]] = [:]
        var byLength: [Int: [Int]] = [:]
        for (index, name) in names.enumerated() {
            exact[name, default: []].append(index)
            byLength[normalized[index].count, default: []].append(index)
        }
        self.exact = exact
        self.byLength = byLength
    }

    public func search(_ request: MyersFuzzySearchRequest) -> [FuzzyCandidateMatch] {
        let queryName = Self.normalize(request.query)
        let query = Array(queryName.unicodeScalars)
        guard !query.isEmpty, request.limit > 0, let pattern = MyersBitParallel.Pattern(query) else { return [] }

        var matches: [FuzzyCandidateMatch] = []
        let exactIndexes = Set(exact[queryName, default: []])
        matches += exactIndexes.map { FuzzyCandidateMatch(candidate: candidates[$0], tier: .exact) }

        // Length window m: only substitutions or an adjacent exchange can be one error.
        for index in byLength[query.count, default: []] where !exactIndexes.contains(index) {
            if withinOneEdit(query, pattern: pattern, candidate: normalized[index]) {
                matches.append(FuzzyCandidateMatch(candidate: candidates[index], tier: .sameLengthOneError))
            }
        }

        // Length window m - 1: this represents the requested one-character-shorter case.
        if query.count > 1 {
            for index in byLength[query.count - 1, default: []] where withinOneEdit(query, pattern: pattern, candidate: normalized[index]) {
                matches.append(FuzzyCandidateMatch(candidate: candidates[index], tier: .oneCharacterShorter))
            }
        }

        // Longer names are searched through triggered contiguous windows of length m.
        for index in candidates.indices where normalized[index].count > query.count {
            let classification = classifyWindows(query: query, pattern: pattern, candidate: normalized[index])
            if classification == .exact {
                matches.append(FuzzyCandidateMatch(candidate: candidates[index], tier: .containsQuery))
            } else if classification == .oneError {
                matches.append(FuzzyCandidateMatch(candidate: candidates[index], tier: .containsOneError))
            }
        }

        return matches.sorted {
            $0.tier == $1.tier
                ? $0.candidate.name.localizedStandardCompare($1.candidate.name) == .orderedAscending
                : $0.tier < $1.tier
        }.prefix(request.limit).map { $0 }
    }

    private enum WindowClassification: Equatable {
        case none
        case oneError
        case exact
    }

    private func classifyWindows(query: [Unicode.Scalar], pattern: MyersBitParallel.Pattern, candidate: [Unicode.Scalar]) -> WindowClassification {
        var foundOneError = false
        for start in triggeredWindowStarts(query: query, candidate: candidate) {
            let window = Array(candidate[start..<(start + query.count)])
            let distance = pattern.distance(to: window)
            if distance == 0 { return .exact }
            if distance == 1 || isAdjacentExchange(query, window) { foundOneError = true }
        }
        return foundOneError ? .oneError : .none
    }

    private func triggeredWindowStarts(query: [Unicode.Scalar], candidate: [Unicode.Scalar]) -> [Int] {
        let maxStart = candidate.count - query.count
        guard maxStart >= 0 else { return [] }

        var starts = Set<Int>()
        let triggerCount = min(3, query.count)
        for candidateIndex in candidate.indices {
            for queryIndex in 0..<triggerCount where candidate[candidateIndex] == query[queryIndex] {
                addWindowStart(candidateIndex - queryIndex, maxStart: maxStart, to: &starts)
                addWindowStart(candidateIndex - queryIndex - 1, maxStart: maxStart, to: &starts)
            }
        }
        return starts.sorted()
    }

    private func addWindowStart(_ start: Int, maxStart: Int, to starts: inout Set<Int>) {
        if start >= 0 && start <= maxStart { starts.insert(start) }
    }

    private func withinOneEdit(_ query: [Unicode.Scalar], pattern: MyersBitParallel.Pattern, candidate: [Unicode.Scalar]) -> Bool {
        let distance = pattern.distance(to: candidate)
        return distance <= 1 || isAdjacentExchange(query, candidate)
    }

    private func isAdjacentExchange(_ query: [Unicode.Scalar], _ candidate: [Unicode.Scalar]) -> Bool {
        guard query.count == candidate.count else { return false }
        let mismatches = query.indices.filter { query[$0] != candidate[$0] }
        guard mismatches.count == 2, mismatches[1] == mismatches[0] + 1 else { return false }
        return query[mismatches[0]] == candidate[mismatches[1]]
            && query[mismatches[1]] == candidate[mismatches[0]]
    }

    private static func normalize(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "en_US_POSIX"))
    }
}

public struct DirectoryFuzzySearchResult: Codable {
    public let relativePath: String
    public let fileName: String
    public let fileExtension: String
    public let size: Int64?
    public let modifiedAt: Date?
    public let score: Int
}

public enum DirectoryFuzzySearchError: LocalizedError {
    case invalidRoot(String)
    case emptyQuery

    public var errorDescription: String? {
        switch self {
        case .invalidRoot(let path): return "Not an accessible directory: \(path)"
        case .emptyQuery: return "query must not be empty"
        }
    }
}

public enum DirectoryFuzzySearch {
    private struct FileRecord {
        let relativePath: String
        let fileName: String
        let fileExtension: String
        let size: Int64?
        let modifiedAt: Date?
    }

    public static func search(root: URL, query: String, limit: Int = 50) throws -> [DirectoryFuzzySearchResult] {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuery.isEmpty else { throw DirectoryFuzzySearchError.emptyQuery }
        let boundedLimit = min(max(limit, 0), 200)
        guard boundedLimit > 0 else { return [] }

        let root = root.standardizedFileURL
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: root.path, isDirectory: &isDirectory), isDirectory.boolValue else {
            throw DirectoryFuzzySearchError.invalidRoot(root.path)
        }

        let scope = root.startAccessingSecurityScopedResource()
        defer { if scope { root.stopAccessingSecurityScopedResource() } }

        let records = enumerateFiles(root: root)
        let candidates = records.map {
            FuzzyCandidate(
                id: $0.relativePath,
                name: URL(fileURLWithPath: $0.fileName).deletingPathExtension().lastPathComponent
            )
        }
        let recordByRelativePath = Dictionary(uniqueKeysWithValues: records.map { ($0.relativePath, $0) })
        let search = MyersBitParallelFuzzySearch(candidates: candidates)

        return search.search(.init(query: trimmedQuery, limit: boundedLimit)).compactMap { match in
            guard let record = recordByRelativePath[match.candidate.id] else { return nil }
            return DirectoryFuzzySearchResult(
                relativePath: record.relativePath,
                fileName: record.fileName,
                fileExtension: record.fileExtension,
                size: record.size,
                modifiedAt: record.modifiedAt,
                score: match.tier.rawValue
            )
        }
    }

    private static func enumerateFiles(root: URL) -> [FileRecord] {
        let keys: Set<URLResourceKey> = [
            .isDirectoryKey,
            .isRegularFileKey,
            .isSymbolicLinkKey,
            .isPackageKey,
            .fileSizeKey,
            .contentModificationDateKey,
        ]
        let options: FileManager.DirectoryEnumerationOptions = [
            .skipsHiddenFiles,
            .skipsPackageDescendants,
        ]
        guard let enumerator = FileManager.default.enumerator(
            at: root,
            includingPropertiesForKeys: Array(keys),
            options: options,
            errorHandler: { _, _ in true }
        ) else {
            return []
        }

        var records: [FileRecord] = []
        for case let url as URL in enumerator {
            guard let values = try? url.resourceValues(forKeys: keys) else { continue }
            if values.isDirectory == true { continue }
            guard values.isRegularFile == true, values.isSymbolicLink != true else { continue }

            let relativePath = relativePath(for: url, root: root)
            records.append(
                FileRecord(
                    relativePath: relativePath,
                    fileName: url.lastPathComponent,
                    fileExtension: url.pathExtension.lowercased(),
                    size: values.fileSize.map(Int64.init),
                    modifiedAt: values.contentModificationDate
                )
            )
        }
        return records.sorted {
            $0.relativePath.localizedStandardCompare($1.relativePath) == .orderedAscending
        }
    }

    private static func relativePath(for url: URL, root: URL) -> String {
        let rootPath = root.path.hasSuffix("/") ? root.path : root.path + "/"
        if url.path.hasPrefix(rootPath) {
            return String(url.path.dropFirst(rootPath.count))
        }
        return url.lastPathComponent
    }
}

private extension JSONEncoder {
    static var fuzzySearchOutput: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }
}

@main
struct MyersBitParallelFuzzySearchCLI {
    static func main() {
        do {
            try run()
        } catch {
            fputs("error: \(error.localizedDescription)\n", stderr)
            exit(EXIT_FAILURE)
        }
    }

    private static func run() throws {
        var args = Array(CommandLine.arguments.dropFirst())
        guard args.first == "search" else { throw Usage.error }
        args.removeFirst()
        guard let query = args.first else { throw Usage.error }
        args.removeFirst()

        guard let root = option(&args, "--root") else { throw Usage.error }
        let limit = Int(option(&args, "--limit") ?? "50") ?? 50
        let results = try DirectoryFuzzySearch.search(root: URL(fileURLWithPath: root), query: query, limit: limit)
        let data = try JSONEncoder.fuzzySearchOutput.encode(results)
        print(String(data: data, encoding: .utf8)!)
    }

    private static func option(_ args: inout [String], _ name: String) -> String? {
        guard let index = args.firstIndex(of: name), index + 1 < args.count else { return nil }
        args.remove(at: index)
        return args.remove(at: index)
    }

    enum Usage: LocalizedError {
        case error

        var errorDescription: String? {
            "usage: MyersBitParallelFuzzySearch search <query> --root <directory> [--limit <count>]"
        }
    }
}
