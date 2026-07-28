//
//  SaveFileParams.swift
//  MutualInfection
//
//  Created by luchao on 2025/11/2.
//

class SaveFileParams {
    var allFilePaths: [String]? = []
    var tempFilePaths: [(String, String, String)]? = []
    var filePaths: [String]? = []
    var tasks: [(@escaping (Bool) -> Void) -> Void]? = []
    var failTasks: [(@escaping (Bool) -> Void) -> Void]? = []
    var failPaths: [(String, String, String)]? = []
    var failRetryCount: [String: Int]? = [String: Int]()
    var tempFileSizeDict: [String: Int64]? = [String: Int64]()
    var tempSubDir: String?
    var noImportFiles: [MITransferFile]?
    var serialQueue: SerialAsyncQueue?
    var failCount: Int?
    var successLocalIdentifiers: [String: String] = [:]
}
