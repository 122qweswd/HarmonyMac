//
//  ReimportAlbum.swift
//  MutualInfection
//
//  Created by mac on 2025/10/25.
//

import Photos

class ReimportAlbum: ObservableObject {
    
    static let shared = ReimportAlbum()
    private init() {}
    
    var isReimport:[Int64: Bool] = [:]
    //最大分批插入数量
    let CHUNKED_COUNT_MAX = 30
    
    // 获取记录中的数据并重新导入(数据转换)
    func getRecordToSelf(_ params: SaveFileParams) {
        let files =  MIWCDBManager.shared.getUnstoredDataFiles()
        var tempFilePaths:[(String, String, String)] = []
        let docDir = FileManager.default.urls(for: .documentDirectory,
                                               in: .userDomainMask).first!
        let tempDir = docDir.appendingPathComponent("temp", isDirectory: true)
        for file in files {
            let path =  file.fileUrl ?? ""
            let tempPahts = path.components(separatedBy: "/temp/")
            if tempPahts.count > 1 {
                let tempPath = tempPahts[1]
                let components = (tempPath as NSString).pathComponents
                if components.count == 2, params.tempSubDir == nil {
                    params.tempSubDir = components[0]
                }
                let type = SaveFileHandler.shared.getFileTypeByFileName(file.fileName ?? "")
                tempFilePaths.append((file.fileName ?? "", type, "\(tempDir.path)/\(tempPath)"))
                SaveFileHandler.shared.tempFileSizeDict?["\(tempDir.path)/\(tempPath)"] = file.fileSize
            }
        }
        params.tempFilePaths = tempFilePaths
    }
    
    func getRecordToSelfHasFiles(_ files: [MITransferFile], _ params: SaveFileParams) {
        params.noImportFiles = files
        var tempFilePaths:[(String, String, String)] = []
        let docDir = FileManager.default.urls(for: .documentDirectory,
                                               in: .userDomainMask).first!
        let tempDir = docDir.appendingPathComponent("temp", isDirectory: true)
        for file in files {
            let path =  file.fileUrl ?? ""
            let tempPahts = path.components(separatedBy: "/temp/")
            if tempPahts.count > 1 {
                let tempPath = tempPahts[1]
                let components = (tempPath as NSString).pathComponents
                if components.count == 2, params.tempSubDir == nil {
                    params.tempSubDir = components[0]
                }
                let type = SaveFileHandler.shared.getFileTypeByFileName(file.fileName ?? "")
                tempFilePaths.append((file.fileName ?? "", type, "\(tempDir.path)/\(tempPath)"))
                SaveFileHandler.shared.tempFileSizeDict?["\(tempDir.path)/\(tempPath)"] = file.fileSize
            }
        }
        params.tempFilePaths = tempFilePaths
    }
    
    //重新导入
    func reImportImage(_ files: [MITransferFile], id: Int64) {
        // 查询数据库获取文件列表
        var saveFileParams = self.initParams()
        self.isReimport[id] = true
        self.getRecordToSelfHasFiles(files, saveFileParams ?? SaveFileParams())
        if (saveFileParams?.tempFilePaths?.count ?? 0) > 0 {
            isSaveFileToAlbum = true
            let tempPaths = SaveFileHandler.shared.groupAndSplitFiles(tempFilePaths: saveFileParams?.tempFilePaths, self.CHUNKED_COUNT_MAX, saveFileParams ?? SaveFileParams())
            ShareAPI.shared().log(1, "[SaveFile] [ReimportAlbum] 落盘文件组装：\(tempPaths)")
            // 第一层：遍历字典的键值对
            for (category, arrayOfTuples) in tempPaths {
                ShareAPI.shared().log(1, "[SaveFile] [ReimportAlbum] 落盘遍例分组文件类型：\(category)，分组大小\(arrayOfTuples.count)")
                if category != "is_live_or_image" {
                    SaveFileHandler.shared.saveFileListToAlbum(category, arrayOfTuples, "task", saveFileParams ?? SaveFileParams())
                }
            }
            //串行队列执行
            saveFileParams?.serialQueue = SerialAsyncQueue()
            saveFileParams?.serialQueue?.execute(tasks: saveFileParams?.tasks ?? [], getProgress: { progress in
                SaveFileHandler.shared.getProgress(progress)
            }) {[weak self] in
                guard let self = self else { return }
                ShareAPI.shared().log(1, "[SaveFile] [ReimportAlbum] 落盘串行任务结束")
                self.updateNoFileRecording(saveFileParams ?? SaveFileParams())
                let dir = FileSaver.getFileDirectory("temp")
                if saveFileParams?.tempSubDir != nil && saveFileParams?.tempSubDir != "" {
                    FileSaver.removeFolder(atPath: "\(dir ?? "")/\(saveFileParams?.tempSubDir ?? "")", notEmpty: true)
                }
                saveFileParams = nil
                self.isReimport[id] = false
            }
        }
    }
    
    func initParams() -> SaveFileParams? {
        let saveFileParams = SaveFileParams()
        saveFileParams.tempFilePaths = []
        saveFileParams.tempFileSizeDict = [String: Int64]()
        saveFileParams.noImportFiles = []
        saveFileParams.tempSubDir = nil
        saveFileParams.successLocalIdentifiers = [:]
        return saveFileParams
    }
    
    //重试后把没找到文件的记录设置为失败
    func updateNoFileRecording(_ params: SaveFileParams) {
        // SaveFileHandler 保存记录做延迟了，这边保持一致
        DispatchQueue.global().asyncAfter(deadline: .now() + 1.1) {
            self.updateNoFileRecording_ori(params)
        }
    }
    func updateNoFileRecording_ori(_ params: SaveFileParams) {
        let files =  MIWCDBManager.shared.getUnstoredDataFiles()
        // 更新对应记录
        for file in files {
            file.status = .failure
            //只处理这一批记录
            if (file.fileUrl ?? "").contains("/\(params.tempSubDir ?? "")/") {
                //延迟保存，避免出现记录页面已处理完，接收页面未走完的问题
                DispatchQueue.global().asyncAfter(deadline: .now() + 1) {
                    MIWCDBManager.shared.updateFileStoredDataStatus(file: file)
                }
            }
        }
    }
    
    //检查是否有未导入的数据
    func checkHasNoImporting() -> Bool {
        let files =  MIWCDBManager.shared.getUnstoredDataFiles()
        return files.count > 0
    }
    
    //杀掉app重新进入的话,重新导入
    func reimportAlbum() {
        //执行落盘任务中（热启动）
        if SaveFileHandler.shared.isSaveFileing ?? false {
            return
        }
        // 查询数据库获取文件列表
        var saveFileParams = self.initParams()
        self.getRecordToSelf(saveFileParams ?? SaveFileParams())
        if (saveFileParams?.tempFilePaths?.count ?? 0) > 0 {
            isSaveFileToAlbum = true
            let tempPaths = SaveFileHandler.shared.groupAndSplitFiles(tempFilePaths: saveFileParams?.tempFilePaths, SaveFileHandler.shared.CHUNKED_COUNT_MAX, saveFileParams ?? SaveFileParams())
            ShareAPI.shared().log(1, "[SaveFile] [ReimportAlbum] 落盘文件组装：\(tempPaths)")
            // 第一层：遍历字典的键值对
            for (category, arrayOfTuples) in tempPaths {
                ShareAPI.shared().log(1, "[SaveFile] [ReimportAlbum] 落盘遍例分组文件类型：\(category)，分组大小\(arrayOfTuples.count)")
                if category != "is_live_or_image" {
                    SaveFileHandler.shared.saveFileListToAlbum(category, arrayOfTuples, "task", saveFileParams ?? SaveFileParams())
                }
            }
            //串行队列执行
            saveFileParams?.serialQueue = SerialAsyncQueue()
            saveFileParams?.serialQueue?.execute(tasks: saveFileParams?.tasks ?? [], getProgress:{ progress in
                SaveFileHandler.shared.getProgress(progress)
            }) { [weak self] in
                guard let self = self else { return }
                ShareAPI.shared().log(1, "[SaveFile] [ReimportAlbum] 落盘串行任务结束")
                self.updateNoFileRecording(saveFileParams ?? SaveFileParams())
                saveFileParams = nil
            }
        }
    }
}

// MARK: - AppDelegate 打开app时导入
extension ReimportAlbum {
    
    /// 判断是否需要重新导入相册
    func checkNeedReimportImageToAlbum() {
        DispatchQueue.main.async {
            if ReimportAlbum.shared.checkHasNoImporting() {
                ReimportAlbum.shared.reimportAlbum()
            }
        }
    }
}
