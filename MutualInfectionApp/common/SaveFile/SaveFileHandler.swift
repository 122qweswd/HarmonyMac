//
//  SaveFileHandler.swift
//  MutualInfection
//
//  Created by mac on 2025/9/2.
//
import Photos

class SaveFileHandler: ObservableObject {
    
    static let shared = SaveFileHandler()
    deinit {
        print("===============落盘内存释放完成")
    }
    private init() {}
    
    var directory: String?
    var fileURL: String?
    var fileName: String?
    var imageType: String?
    var tempFilePaths: [(String, String, String)]? = []
    var filePaths: [String]? = []
    var tasks: [(@escaping (Bool) -> Void) -> Void]?
    var tempFileSizeDict: [String: Int64]? = [String: Int64]()
    var failPaths: [(String, String, String)]? = []
    var allFilePaths: [String]? = []
    var failTasks: [(@escaping (Bool) -> Void) -> Void]?
    var failRetryCount: [String: Int]? = [String: Int]()
    var allFilesPosition: String?
    var isSaveFileing: Bool?
    var allFilesType: String?
    var saveFileProgress: Float?
    var customprogress: ((Float) -> Void)?
    var timeInfo: [String: (String, String, String)]?
    var timeInfoDict: [String:[String]]?
    var noImportFiles: [MITransferFile]?
    var tempSubDir: String?
    var curRecordId: Int64?
    
    //错误重试次数
    let FAIL_COUNT_MAX = 1
    //最大分批插入数量
    let CHUNKED_COUNT_MAX = 50
    //默认最大组文件大小为1个G
    let CHUNKED_MEMORY_MAX = 1*1000*1000*1000
    
    //错误重试回退数量
    let CHUNKED_COUNT_ARRAY = [1, 1, 1, 1]
    
    //时间非法值
    let NO_TIME_MS = "-1"
    let NO_TIME_STR = ""
    
    var isSavePhotoLibraryForMac: Bool = false
    
    // 检测描述符是否生成，并返回没生成的错误集合
    func checkFailPathsByAlbum(_ localIdentifiers: [String: String]?, _ paths: [(String, String, String)]) -> ([(String, String, String)], [(String, String, String)]) {
        var successPaths: [(String, String, String)] = []
        var failPaths: [(String, String, String)] = []
        for (fileName, type, path) in paths {
            let identifier = (localIdentifiers ?? [String: String]())[path]
            if identifier == nil || identifier == "" {
                failPaths.append((fileName, type, path))
            } else {
                successPaths.append((fileName, type, path))
            }
        }
        return (failPaths,successPaths)
    }
    
    //合并错误的链接
    func setFailPathsByAlbum(_ paths: [(String, String, String)], _ params: SaveFileParams) {
        params.failPaths = paths
    }
    
    // MARK: 保存照片到图库（批量）
    func savePhotosToAlbum(_ paths: [(String, String, String)], _ params: SaveFileParams) -> (@escaping (Bool) -> Void) -> Void {
        
        return {[weak self] completion in
            guard let self = self else {return}
            
            var tempPaths: [(String, String, String)] = []
            var psdPaths: [(String, String, String)] = []
            // 批量处理URL
            for (index, (_, _, path)) in paths.enumerated() {
                let ext = (path as NSString).pathExtension.lowercased()
                if ext == "psd" {
                    psdPaths.append(paths[index])
                } else {
                    tempPaths.append(paths[index])
                }
            }
            
            if psdPaths.count > 0 {
                //如果image文件夹没有进行创建
                let _ = FileSaver.getFileDirectory("image")
                //失败的文件转移到文管的image中
                let newFailPaths = self.moveFiles(psdPaths, params)
                // 超过重试次数，进行记录修改
                if (params.noImportFiles?.count ?? 0) > 0 {
                    self.updateFailRecording(newFailPaths, params.noImportFiles ?? [], params)
                } else {
                    self.updateFailRecording(newFailPaths, params);
                }
            }
            
            let paths = tempPaths
            if paths.count == 0 {
                completion(true)
                return
            }
            
            PhotoSaver.savePhotosToAlbum(paths) {[weak self] success, error, localIdentifiers in
                
                guard let weakSelf = self else {return}
                if success {
                    ShareAPI.shared().log(1, "[SaveFile] [SaveFileHandler] 保存图片到相册成功\(paths.count)")
                    let (failPaths, successPaths) = weakSelf.checkFailPathsByAlbum(localIdentifiers, paths)
                    //保存失败的文件地址到
                    weakSelf.setFailPathsByAlbum(failPaths, params)
                    weakSelf.updateRecording(localIdentifiers ?? [String: String](), params)
                    //删除临时文件
                    weakSelf.deleteFiles(atPaths: successPaths) { result in
                        switch result {
                        case .success(let count):
                            ShareAPI.shared().log(1, "[SaveFile] [SaveFileHandler] 成功删除\(count)/\(successPaths.count)个文件")
                        case .failure(let error):
                            ShareAPI.shared().log(3, "[SaveFile] [SaveFileHandler] 删除失败: \(error.localizedDescription)")
                        }
                        if failPaths.count > 0 {
                            weakSelf.failRetry(params){
                                completion(failPaths.count == 0)
                            }
                        } else {
                            completion(failPaths.count == 0)
                        }
                    }
                } else {
                    ShareAPI.shared().log(3, "[SaveFile] [SaveFileHandler] 保存图片到相册失败: \(error?.localizedDescription ?? "未知错误")")
                    //保存失败的文件地址到
                    weakSelf.setFailPathsByAlbum(paths, params)
                    weakSelf.failRetry(params){
                        completion(false)
                    }
                }
            }
        }
    }
    //相册写入权限
    func photoLibraryAdd() -> Bool{
        var currentStatus: PHAuthorizationStatus
        if #available(macOS 11, *) {
            currentStatus = PHPhotoLibrary.authorizationStatus(for: .addOnly)
        }else{
            // 低版本使用传统 API
            currentStatus = PHPhotoLibrary.authorizationStatus()
        }
        if currentStatus != .notDetermined {
            print("已授权（低版本或完全访问）")
            return true
        }else{
            return false
        }

    }
    func photoLibraryAuthorized() -> Bool {
        let currentStatus: PHAuthorizationStatus
        if #available(macOS 11, *) {
            // iOS 14+ 使用带访问级别的 API
            currentStatus = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        } else {
            // 低版本使用传统 API
            currentStatus = PHPhotoLibrary.authorizationStatus()
        }
        if currentStatus == .notDetermined {
            print("未请求过照片权限")
            return false
        } else if currentStatus == .authorized {
            print("已授权（低版本或完全访问）")
            return true
        } else if #available(iOS 14, *), currentStatus == .limited {
            return true
        } else if currentStatus == .denied {
            return false
        } else if currentStatus == .restricted {
            return true
        }
        return true
    }
    func contactAuthorized() -> Bool {
        let status = CNContactStore.authorizationStatus(for: .contacts)
        return status == .authorized
    }
    
    func removeFile(_ fileUrl: URL?) {
        let fileManager = FileManager.default
        do {
            let path = fileUrl?.path
            if let fileUrl = fileUrl {
                try fileManager.removeItem(at: fileUrl)
            }
            ShareAPI.shared().log(1, "[SaveFile] [SaveFileHandler] 文件删除成功\(path ?? "")")
        } catch {
            ShareAPI.shared().log(3, "[SaveFile] [SaveFileHandler] 文件删除失败: \(error.localizedDescription)")
        }
    }
    
    // 批量删除文件
    func deleteFiles(atPaths paths: [(String, String, String)], completion: @escaping (Result<Int, Error>) -> Void) {
        var successCount = 0
        let fileManager = FileManager.default
        
        for (_, _, path) in paths {
            do {
                var isDirectory: ObjCBool = false
                guard fileManager.fileExists(atPath: path, isDirectory: &isDirectory) else {
                    continue
                }
                
                try fileManager.removeItem(atPath: path)
                successCount += 1
            } catch {
                completion(.failure(error))
                return
            }
        }
        completion(.success(successCount))
    }
    
    func saveVideosToAlbum(_ paths: [(String, String, String)], _ params: SaveFileParams, completion: @escaping (Bool, Error?) -> Void) {
        VideoSaver.saveVideosToAlbum(paths) {[weak self] success, error, localIdentifiers in
            guard let self = self else { return }
            if success {
                let (failPaths, successPaths) = self.checkFailPathsByAlbum(localIdentifiers, paths)
                //保存失败的文件地址到
                self.setFailPathsByAlbum(failPaths, params)
                self.updateRecording(localIdentifiers ?? [String: String](), params)
                //删除临时文件
                self.deleteFiles(atPaths: successPaths) { result in
                    switch result {
                    case .success(let count):
                        ShareAPI.shared().log(1, "[SaveFile] [SaveFileHandler] 成功删除\(count)/\(successPaths.count)个文件")
                    case .failure(let error):
                        ShareAPI.shared().log(3, "[SaveFile] [SaveFileHandler] 删除失败: \(error.localizedDescription)")
                    }
                    if failPaths.count > 0 {
                        self.failRetry(params){
                            completion(failPaths.count == 0, nil)
                        }
                    } else {
                        completion(failPaths.count == 0, nil)
                    }
                }
            } else {
                //保存失败的文件地址到
                self.setFailPathsByAlbum(paths, params)
                self.failRetry(params){
                    completion(false, error)
                }
            }
        }
    }
    
    //落盘照片 视频 实况图
    // 落盘临时文件 type "image" 照片 "video" 视频 "library_live_photo" 实况图
    func saveTempFileStart(_ fileName: String, _ type: String) -> String? {
        self.fileName = fileName
        self.imageType = type
        let tempURL = FileSaver.getTempFileURL(fileName: fileName )
        self.fileURL = tempURL
        // 开始就往临时数组中加
        if let path = tempURL {
            self.tempFilePaths?.append((fileName ,type, path))
            //总文件列表中也记录保证顺序
            self.allFilePaths?.append(path)
        }
        ShareAPI.shared().log(1, "[SaveFile] [SaveFileHandler] 生成临时文件路径：\(tempURL ?? "")")
        return tempURL
    }
    
    // 更新记录
    func updateRecording(_ localIdentifiers: [String: String], _ params: SaveFileParams) {
        var localIdentifiersTemp = [String: String]()
        for (key, value) in params.successLocalIdentifiers {
            if value.count > 0 {
                localIdentifiersTemp[key] = value
            }
        }
        for (key, value) in localIdentifiers {
            localIdentifiersTemp[key] = value
        }
        params.successLocalIdentifiers = localIdentifiersTemp
        let localIdentifiers = params.successLocalIdentifiers
         
        // 查询未导入的列表
        let files =  MIWCDBManager.shared.getUnstoredDataFiles()
        let docDir = FileManager.default.urls(for: .documentDirectory,
                                               in: .userDomainMask).first!
        let tempDir = docDir.appendingPathComponent("temp", isDirectory: true)
        // 更新对应记录
        for file in files {
            let path =  file.fileUrl ?? ""
            var tempPath = ""
            if path.contains("/temp/") {
               tempPath = (path.components(separatedBy: "/temp/")[1])
            }
            let identifier = localIdentifiers["\(tempDir.path)/\(tempPath)"]
            //只处理这一批的记录
            if identifier != nil,identifier != "", path.contains("/\(params.tempSubDir ?? "")/") {
                params.successLocalIdentifiers["\(tempDir.path)/\(tempPath)"] = nil
                
                file.identifier = identifier
                file.status = .success
                //延迟保存，避免出现记录页面已处理完，接收页面未走完的问题
                MIWCDBManager.shared.updateFileStoredDataStatus(file: file)
            }
        }
    }
    
    //保持失败记录
    func updateFailRecording(_ failPaths: [(String, String, String)], _ files: [MITransferFile], _ params: SaveFileParams) {
        // 查询未导入的列表
        var fileNames: [String] = []
        var fileDict: [String: (String, String, String)] = [:]
        for (index, (_ ,_,path)) in (params.failPaths ?? []).enumerated() {
            let fileName = (path as NSString).lastPathComponent
            fileNames.append(fileName)
            if failPaths.count > index {
                fileDict[fileName] = failPaths[index]
            }
        }
        // 更新对应记录
        for file in files {
            //只处理一批记录
            if fileNames.contains(file.fileName ?? ""), (file.fileUrl ?? "").contains("/\(params.tempSubDir ?? "")/") {
                let path = fileDict[file.fileName ?? ""]?.2
                if (path ?? "").contains("/temp/") {
                    file.status = .failure
                    //延迟保存，避免出现记录页面已处理完，接收页面未走完的问题
                    DispatchQueue.global().asyncAfter(deadline: .now() + 1) {
                        MIWCDBManager.shared.updateFileStoredDataStatus(file: file)
                    }
                } else {
                    file.status = .success
                    file.fileType = .file
                    file.fileFolder = "image"
                    if (path ?? "").contains("Documents") {
                        let tempPath = (path ?? "").components(separatedBy: "Documents")[1]
                        file.fileUrl = "/Documents" + tempPath
                    }
                    //延迟保存，避免出现记录页面已处理完，接收页面未走完的问题
                    DispatchQueue.global().asyncAfter(deadline: .now() + 1) {
                        MIWCDBManager.shared.updateFileStoredDateFileUrl(file: file)
                    }
                }
            }
        }
    }
    
    // 失败的记录保存
    func updateFailRecording(_ failPaths: [(String, String, String)], _ params: SaveFileParams) {
        // 查询未导入的列表
        let files =  MIWCDBManager.shared.getUnstoredDataFiles()
        var fileNames: [String] = []
        var fileDict: [String: (String, String, String)] = [:]
        for (index, (_ ,_,path)) in (params.failPaths ?? []).enumerated() {
            let fileName = (path as NSString).lastPathComponent
            fileNames.append(fileName)
            if failPaths.count > index {
                fileDict[fileName] = failPaths[index]
            }
        }
        // 更新对应记录
        for file in files {
            //只处理一批记录
            if fileNames.contains(file.fileName ?? ""), (file.fileUrl ?? "").contains("/\(params.tempSubDir ?? "")/") {
                let path = fileDict[file.fileName ?? ""]?.2
                if (path ?? "").contains("/temp/") {
                    file.status = .failure
                    //延迟保存，避免出现记录页面已处理完，接收页面未走完的问题
                    DispatchQueue.global().asyncAfter(deadline: .now() + 1) {
                        MIWCDBManager.shared.updateFileStoredDataStatus(file: file)
                    }
                } else {
                    file.status = .success
                    file.fileType = .file
                    file.fileFolder = "image"
                    if (path ?? "").contains("Documents") {
                        let tempPath = (path ?? "").components(separatedBy: "Documents")[1]
                        file.fileUrl = "/Documents" + tempPath
                    }
                    //延迟保存，避免出现记录页面已处理完，接收页面未走完的问题
                    DispatchQueue.global().asyncAfter(deadline: .now() + 1) {
                        MIWCDBManager.shared.updateFileStoredDateFileUrl(file: file)
                    }
                }
            }
        }
    }
    
    // MARK: 单文件落盘(实况图)
    func saveFileToAlbum(_ fileName: String,_ imageType: String, _ fileURL: URL, _ params: SaveFileParams) -> (@escaping (Bool) -> Void) -> Void {
        return {[weak self] completion in
            let fileLiveURL = fileURL
            let fileName = fileLiveURL.deletingPathExtension().lastPathComponent
            let pathID = UUID().uuidString
            let path = "\(FilePaths.VidToLive.livePath)/\(pathID)"
            let ext = fileURL.pathExtension
            let tempImagePath = "\(path)/\(fileName).\(ext)"
            let tempVideoPath = "\(path)/\(fileName).mp4"
            let _ = try? FileManager.default.createDirectory(atPath: path, withIntermediateDirectories: true, attributes: nil)
            try? FileManager.default.removeItem(atPath: tempImagePath)
            try? FileManager.default.removeItem(atPath: tempVideoPath)
            let success = LivePhotoUtilOC.sharedInstance().splitLivePhoto(fileLiveURL.path, imagePath: tempImagePath, videoPath: tempVideoPath)
            if success {
                let newPathID = UUID().uuidString
                let newPath = "\(FilePaths.VidToLive.livePath)/\(newPathID)"
                var convertVideoPath = "\(newPath)/\(fileName).mov"
                let _ = try? FileManager.default.createDirectory(atPath: newPath, withIntermediateDirectories: true, attributes: nil)
                var hvc1Supported: ObjCBool = false
                let livePhotoSuccess = TranscodeMediaOC.sharedInstance().checkVideoCodecSupport(tempVideoPath, isSupported: &hvc1Supported)
                if livePhotoSuccess && !hvc1Supported.boolValue {
                    TranscodeMediaOC.sharedInstance().convert(toHVC1: tempVideoPath, outputPath: convertVideoPath) { convertSuccess, msg in
                        convertVideoPath = convertSuccess ? convertVideoPath : tempVideoPath
                        self?.synthesisSplittingEncodingConversionLivePhoto(tempImagePath: tempImagePath, fileName: fileName, videoPath: convertVideoPath, imageType: imageType, fileURL: fileURL, params: params, completion: completion)
                    }
                }else {
                    self?.synthesisSplittingEncodingConversionLivePhoto(tempImagePath: tempImagePath, fileName: fileName, videoPath: tempVideoPath, imageType: imageType, fileURL: fileURL, params: params, completion: completion)
                }
            } else {
                completion(false)
            }
        }
    }
    private func synthesisSplittingEncodingConversionLivePhoto(tempImagePath: String, fileName: String, videoPath: String, imageType: String, fileURL: URL, params: SaveFileParams, completion: @escaping (Bool) -> Void) {
        //保存实况图后缀不变
        let ext = fileURL.pathExtension
        let newPathID = UUID().uuidString
        let newPath = "\(FilePaths.VidToLive.livePath)/\(newPathID)"
        var imagePath = "\(newPath)/\(fileName).\(ext)"
        let _ = try? FileManager.default.createDirectory(atPath: newPath, withIntermediateDirectories: true, attributes: nil)
        try? FileManager.default.removeItem(atPath: imagePath)
        //注释掉镜头型号兜底逻辑（暂时处理不了经过镜头型号转换造成的照片大小变小的问题）
        // 镜头型号兜底
//        let lensModel = LensModelHandler.getNewLensModel(from: URL(fileURLWithPath: tempImagePath))
//        if lensModel != "" {
//           let lenSuccess = LensModelHandler.writeLensModelToImage(sourceImageURL: URL(fileURLWithPath: tempImagePath), destinationImageURL: URL(fileURLWithPath: imagePath), lensModel: lensModel)
//            //重写失败 切换为原先的路径
//            if !lenSuccess {
//                imagePath = tempImagePath
//            }
//        }else {
            imagePath = tempImagePath
//        }
        let assetIdentifier = UUID().uuidString
        let toPath = "\(FilePaths.VidToLive.livePath)/\(assetIdentifier)"
        let toImagePath = "\(toPath)/\(fileName).\(ext)"
        let toVideoPath = "\(toPath)/\(fileName).MOV"
        let _ = try? FileManager.default.createDirectory(atPath: toPath, withIntermediateDirectories: true, attributes: nil)
        try? FileManager.default.removeItem(atPath: toImagePath)
        try? FileManager.default.removeItem(atPath: toVideoPath)
        LivePhotoToolTransManager.writeJPEGAssetIdentifier(from: imagePath, to: toImagePath, assetIdentifier: assetIdentifier)
        
        LivePhotoToolTransManager.writeMOVAssetIdentifier(from: videoPath, to: toVideoPath, assetIdentifier: assetIdentifier) { livePhotoSuccess in
            if !livePhotoSuccess {
                completion(false)
                return
            }
            let _ = LivePhotoPreprocessor.validateMetadata(jpgURL:  URL(fileURLWithPath: toImagePath), movURL: URL(fileURLWithPath: toVideoPath))
            LivePhotoToolTransManager.generateLivePhoto(videoURL: URL(fileURLWithPath: toVideoPath), imageURL: URL(fileURLWithPath: toImagePath)) { result in
                switch result {
                case .success(let success):
                    LivePhotoToolTransManager.saveTheLivePhotoToTheAlbum(imageURL: URL(fileURLWithPath: toImagePath), videoURL: URL(fileURLWithPath: toVideoPath), fileURL.path) {localIdentifiers in
                        if let localIdentifiers = localIdentifiers {
                            ShareAPI.shared().log(1, "[SaveFile] [SaveFileHandler] 实况图生成成功：success - \(success)")
                            let result = self.checkFailPathsByAlbum(localIdentifiers, [(fileName ,imageType, fileURL.path)])
                            if result.0.count == 0 {
                                //清除临时文件
                                self.removeFile(URL(fileURLWithPath:imagePath))
                                self.removeFile(URL(fileURLWithPath:videoPath))
                                self.removeFile(fileURL)
                                completion(true)
                            } else {
                                self.setFailPathsByAlbum([(fileName, imageType, fileURL.path)], params)
                                self.failRetry(params){
                                    completion(false)
                                }
                            }
                            self.updateRecording(localIdentifiers, params)
                        } else {
                            self.setFailPathsByAlbum([(fileName, imageType, fileURL.path)], params)
                            self.failRetry(params){
                                completion(false)
                            }
                        }
                    }
                case .failure(let failure):
                    ShareAPI.shared().log(3, "[SaveFile] [SaveFileHandler] 实况图生成失败：failure - \(failure)")
                    self.setFailPathsByAlbum([(fileName, imageType, fileURL.path)], params)
                    self.failRetry(params){
                        completion(false)
                    }
                }
            }
        }
    }
    // MARK: 批量落盘
    func saveFileListToAlbum(_ imageType: String, _ paths: [(String, String, String)], _ type: String, _ params: SaveFileParams) {
        if imageType == "library_image" {
            let task = self.savePhotosToAlbum(paths, params)
            if type == "task" {
                params.tasks?.append(task)
            } else {
                params.failTasks?.append(task)
            }
        } else if imageType == "library_video" {
            let task = {(completion: @escaping (Bool) -> Void) in
                self.saveVideosToAlbum(paths, params) { success, error in
                    if success {
                        ShareAPI.shared().log(1,"[SaveFile] [SaveFileHandler] 视频已批量成功保存到相册\(paths.count)")
                        completion(true)
                    } else {
                        ShareAPI.shared().log(3,"[SaveFile] [SaveFileHandler] 保存视频失败: \(error?.localizedDescription ?? "未知错误")")
                        completion(false)
                    }
                }
            }
            if type == "task" {
                params.tasks?.append(task)
            } else {
                params.failTasks?.append(task)
            }
        } else if imageType == "library_live_photo" {
            //实况图还是一张一张的存储
            for (fileName, _, path) in paths {
                let task = self.saveFileToAlbum(fileName, "library_live_photo", URL(fileURLWithPath: path), params)
                if type == "task" {
                    params.tasks?.append(task)
                } else {
                    params.failTasks?.append(task)
                }
            }
        }
    }
    
    //多文件夹多级适配
    func getLastDir(_ fileName: String,_ directoryType:String) -> String {
        if fileName.contains("/") {
            let dirArr = fileName.split(separator:"/")
            var preDir = directoryType
            for (index, dir) in dirArr.enumerated(){
                if index < (dirArr.count - 1) {
                    preDir = preDir + "/" + dir
                }
            }
            self.directory = FileSaver.getFileDirectory(preDir)
            return String (dirArr [dirArr.count - 1])
        } else {
            self.directory = FileSaver.getFileDirectory(directoryType)
            return fileName
        }
    }
    
    // 落盘开始获取文件夹和文件
    func saveFileStart(_ fileName: String, _ directoryType: String) -> String? {
        self.fileName = fileName
        // 文件夹适配
        let tempFileName = getLastDir(fileName, directoryType)
        guard let directory = self.directory else {
            return nil
        }
        self.fileURL = FileSaver.getFileURL(fileName: tempFileName, at: directory)
        if let path = self.fileURL {
            self.filePaths?.append(path)
            //总文件列表中也记录保证顺序
            self.allFilePaths?.append(path)
        }
        ShareAPI.shared().log(1, "[SaveFile] [SaveFileHandler] 生成接收文件路径：\(self.fileURL ?? "")")
        return self.fileURL
    }
    
    // 清理文件接收缓存
    func clearFileParamCache(_ fileName: String, _ fileSize: Int64) {
        if let curFileName = self.fileName,
           fileName == curFileName {
            //保存图库对应的文件大小
            if self.imageType == "is_live_or_image" || self.imageType == "library_live_photo"
                || self.imageType == "library_image" || self.imageType == "library_video" {
                if self.tempFileSizeDict == nil {
                    self.tempFileSizeDict = [String: Int64]()
                }
                self.tempFileSizeDict?[self.fileURL ?? ""] = fileSize
            }
            if self.tempFilePaths == nil {
                self.tempFilePaths = []
            }
            // 实况图已经判断修改其状态
            if (self.imageType == "library_live_photo" || self.imageType == "library_image"),
               self.allFilesType != FileDirectoryType.others.rawValue,
               !(self.tempFilePaths?.isEmpty ?? false),
               self.tempFilePaths?[(self.tempFilePaths?.count ?? 0) - 1].1 == "is_live_or_image" {
                let count = self.tempFilePaths?.count
                if let tempIndex = count {
                    let pathParams = self.tempFilePaths?[tempIndex - 1]
                    self.tempFilePaths?[tempIndex - 1] = (pathParams?.0 ?? "", self.imageType ?? "", pathParams?.2 ?? "")
                }
            }
            self.directory = nil
            self.fileURL = nil
            self.fileName = nil
            self.imageType = nil
        }
    }
    
    //落盘任务初始化
    func taskEndInit() {
        self.tasks = []
        self.tempFileSizeDict = [String: Int64]()
        self.failTasks = []
        self.failRetryCount = [String: Int]()
        self.isSaveFileing = true
        self.saveFileProgress = Float(0.0)
        self.customprogress = nil
        self.failPaths = []
    }
    
    func saveFileInit(_ sendType: String, _ previewSummary: String) {
        self.directory = nil
        self.fileURL = nil
        self.fileName = nil
        self.imageType = nil
        self.filePaths = []
        self.tempFilePaths = []
        self.allFilePaths = []
        self.allFilesPosition = nil
        self.allFilesType = nil
        self.timeInfo = [String: (String, String, String)]()
        self.timeInfoDict = [String:[String]]()
        self.tempSubDir = "\(UUID().uuidString)"
        // 生成临时目录
        _ = FileSaver.getFileDirectory("temp/\(self.tempSubDir ?? "sub")")
        self.checkPreviewSummary(sendType, previewSummary)
    }
    
    func saveTimeInfo(timeInfo: String) {
        let timeDict = self.convertJSONStringToDictionaryForTime(timeInfo)
        if self.timeInfoDict?["date_added"]?.count ?? 0 > 0 {
            let new_date_added = (self.timeInfoDict?["date_added"] ?? []) + (timeDict?["date_added"] ?? [])
            let new_date_taken = (self.timeInfoDict?["date_taken"] ?? []) + (timeDict?["date_taken"] ?? [])
            let new_detail_time = (self.timeInfoDict?["detail_time"] ?? []) + (timeDict?["detail_time"] ?? [])
            self.timeInfoDict?["date_added"] = new_date_added
            self.timeInfoDict?["date_taken"] = new_date_taken
            self.timeInfoDict?["detail_time"] = new_detail_time
        } else {
            self.timeInfoDict = timeDict
        }
    }
    func getTimeinfo(_ path:String) -> (String, String ,String) {
        let timeDict = self.timeInfoDict
        let date_added = timeDict?["date_added"]
        let date_taken = timeDict?["date_taken"]
        let detail_time = timeDict?["detail_time"]
        for (index, tempPath) in (self.allFilePaths ?? []).enumerated(){
            if tempPath == path {
                if (date_added?.count ?? 0) > index {
                    return (date_added?[index] ?? "-1", date_taken?[index] ?? "-1", detail_time?[index] ?? "")
                } else {
                    return ("-1", "-1", "")
                }
            }
        }
        return ("-1", "-1", "")
    }
    
    //判断是否大于4次执行
    func canRetryLimit(_ failPaths: [(String, String, String)], _ params: SaveFileParams) -> [(String, String, String)] {
        var retryLimitPaths: [(String, String, String)] = []
        for item in failPaths {
            let count = params.failRetryCount?[item.2] ?? 0
            if count < FAIL_COUNT_MAX {
                retryLimitPaths.append(item)
            }
        }
        return retryLimitPaths
    }
    
    //迁移单个文件
    func moveFile(from sourcePath: String, to destPath: String, _ params: SaveFileParams) -> String {
        let fileManager = FileManager.default
        var newDestPath = destPath
        //判断是否存在已有文件
        if fileManager.fileExists(atPath: newDestPath) {
            newDestPath = FileSaver.uniqueFilePath(for: destPath, fileManager: fileManager)
        }
        do {
            try fileManager.moveItem(atPath: sourcePath, toPath: newDestPath)
            //累计失败转移数量
            params.failCount = (params.failCount ?? 0) + 1
            ShareAPI.shared().log(1, "[SaveFile] [SaveFileHandler] 迁移失败文件成功：Moved \(sourcePath) to \(newDestPath)")
            return newDestPath
        } catch {
            ShareAPI.shared().log(1, "[SaveFile] [SaveFileHandler] 迁移失败文件失败：Moved \(sourcePath)")
            return sourcePath
        }
    }
    
    //文件迁移
    func moveFiles(_ paths: [(String, String, String)], _ params: SaveFileParams) -> [(String, String, String)] {
        let fileManager = FileManager.default
        let docPath =  fileManager.urls(for: .documentDirectory,
                                         in: .userDomainMask).first?.path
        let imagePath = "\(docPath ?? "")/image"
        var newPaths: [(String, String, String)] = []
        for (tempFileName, type, path) in paths {
            let fileName = (path as NSString).lastPathComponent
            let destPath = self.moveFile(from: path, to: "\(imagePath)/\(fileName)", params)
            newPaths.append((tempFileName, type, destPath))
        }
        return newPaths
    }
    
    //失败文件处理
    func failFilesHandler(_ params: SaveFileParams) {
        //如果image文件夹没有进行创建
        let _ = FileSaver.getFileDirectory("image")
        //失败的文件转移到文管的image中
        let newFailPaths = self.moveFiles(params.failPaths ?? [], params)
        // 超过重试次数，进行记录修改
        if (params.noImportFiles?.count ?? 0) > 0 {
            self.updateFailRecording(newFailPaths, params.noImportFiles ?? [], params)
        } else {
            self.updateFailRecording(newFailPaths, params);
        }
    }
    
    //错误重试机制
    func failRetry(_ params: SaveFileParams, completion: @escaping () -> Void) {
        var maxCount = 0
        let retryLimitPahts = self.canRetryLimit(params.failPaths ?? [],params)
        //全部超过4次不执行错误重试
        if retryLimitPahts.count == 0 {
            self.failFilesHandler(params)
            completion()
            return
        }
        for (_, _, path) in retryLimitPahts {
            let count = params.failRetryCount?[path] ?? 0
            params.failRetryCount?[path] = count + 1
            if (count + 1) > maxCount {
                maxCount = count + 1
            }
        }
        ShareAPI.shared().log(1, "[SaveFile] [SaveFileHandler] 落盘失败重试")
        let tempPaths = groupAndSplitFiles(tempFilePaths: retryLimitPahts, CHUNKED_COUNT_ARRAY[0], params)
        ShareAPI.shared().log(1, "[SaveFile] [SaveFileHandler] 失败重试文件组装：\(tempPaths)")
        // 第一层：遍历字典的键值对
        for (category, arrayOfTuples) in tempPaths {
            ShareAPI.shared().log(1, "[SaveFile] [SaveFileHandler] 失败重试文件类型：\(category)")
            if category != "is_live_or_image" {
                self.saveFileListToAlbum(category, arrayOfTuples, "fail", params)
            }
        }
        // 清空错误链接地址（已组装完成）
        params.failPaths = []
        if tempPaths.count > 0 {
            //任务序列扩充完成
            params.serialQueue?.appendTasks(failTasks: params.failTasks ?? [], getProgress:{ [weak self] progress in
                self?.getProgress(progress)
            })
            //清空失败任务队列
            params.failTasks = []
        }
        completion()
    }
    
    //落盘结束回调接收记录
    func callSaveRecord(_ params: SaveFileParams ,_ completion: @escaping ([String]?, [String]?, SaveFileParams, [String: Int64]) -> Void) {
        isSaveFileToAlbum = false
        let tempFileSizeDict = params.tempFileSizeDict
        //回主线程保存接收记录
        DispatchQueue.main.async {
            completion(params.allFilePaths ?? [], params.filePaths ?? [], params, tempFileSizeDict ?? [String: Int64]())
            params.tempFileSizeDict = [String: Int64]()
        }
    }
    
    func getProgress(_ progress: Float) -> Void {
        if let saveFileProgress = self.saveFileProgress, (saveFileProgress as Float) < progress {
            self.saveFileProgress = progress
            DispatchQueue.main.async {
                self.customprogress?(progress)
            }
        }
    }
    
    func initParams() -> SaveFileParams? {
        let saveFileParams = SaveFileParams()
        saveFileParams.allFilePaths = self.allFilePaths
        saveFileParams.tempFilePaths = self.tempFilePaths
        saveFileParams.filePaths = self.filePaths
        saveFileParams.tasks = self.tasks
        saveFileParams.failTasks = self.failTasks
        saveFileParams.failPaths = self.failPaths
        saveFileParams.failRetryCount = self.failRetryCount
        saveFileParams.tempFileSizeDict = self.tempFileSizeDict
        saveFileParams.tempSubDir = self.tempSubDir
        saveFileParams.successLocalIdentifiers = [:]
        return saveFileParams
    }
    
    //清理全局缓存
    func clearSelfParams() {
        self.filePaths?.removeAll()
        self.allFilePaths?.removeAll()
        self.tempFilePaths?.removeAll()
        self.filePaths?.removeAll()
        self.tasks?.removeAll()
        self.failTasks?.removeAll()
        self.failRetryCount?.removeAll()
        self.tempFileSizeDict?.removeAll()
        self.filePaths = nil
        self.allFilePaths = nil
        self.tempFilePaths = nil
        self.filePaths = nil
        self.tasks = nil
        self.failTasks = nil
        self.failRetryCount = nil
        self.tempFileSizeDict = nil
        self.tempSubDir = nil
    }
    
    
    //接收任务结束，正式开始落盘
    func saveFileTaskEnd(customprogress: @escaping (Float) -> Void, completion: @escaping ([String]?, [String]?, SaveFileParams, [String: Int64]) -> Void) {
        self.taskEndInit()
        self.customprogress = customprogress
        var saveFileParams = self.initParams()
        self.clearSelfParams()
        // 图库落盘开始
        // 落盘保活
        isSaveFileToAlbum = self.tempFilePaths?.count ?? 0 > 0
        let tempPaths = self.groupAndSplitFiles(tempFilePaths: saveFileParams?.tempFilePaths, CHUNKED_COUNT_MAX, saveFileParams ?? SaveFileParams())
        ShareAPI.shared().log(1, "[SaveFile] [SaveFileHandler] 落盘文件组装：\(tempPaths)")
        // 第一层：遍历字典的键值对
        for (category, arrayOfTuples) in tempPaths {
            ShareAPI.shared().log(1, "[SaveFile] [SaveFileHandler] 落盘遍例分组文件类型：\(category)，分组大小\(arrayOfTuples.count)")
            self.saveFileListToAlbum(category, arrayOfTuples, "task", saveFileParams ?? SaveFileParams())
        }
        customprogress(0.0)
        //串行队列执行
        saveFileParams?.serialQueue = SerialAsyncQueue()
        saveFileParams?.serialQueue?.execute(tasks: saveFileParams?.tasks ?? [], getProgress:{ [weak self] progress in
            self?.getProgress(progress)
        }) { [weak self] in
            guard let self = self else {return}
            ShareAPI.shared().log(1, "[SaveFile] [SaveFileHandler] 落盘串行任务结束")
            customprogress(1.0)
            self.callSaveRecord(saveFileParams ?? SaveFileParams(), completion)
            let dir = FileSaver.getFileDirectory("temp")
            if saveFileParams?.tempSubDir != nil && saveFileParams?.tempSubDir != "" {
                FileSaver.removeFolder(atPath: "\(dir ?? "")/\(saveFileParams?.tempSubDir ?? "")", notEmpty: true)
            }
            saveFileParams = nil
        }
    }
    
    //获取记录中保存的时间信息
    func getTimeInfo(_ paths: [(String, String, String)]) -> [String: (String, String, String)] {
        let files =  MIWCDBManager.shared.getUnstoredDataFiles()
        var fileDict = [String: (String, String, String)]()
        for file in files {
            let path =  file.fileUrl ?? ""
            var tempPath = ""
            var timeInfo = "-1|-1|"
            if path.contains("/temp/") {
                tempPath = (path.components(separatedBy: "/temp/")[1])
                timeInfo = (path.components(separatedBy: "/temp/")[0])
            }
            if fileDict[tempPath] == nil {
                let timeArr = timeInfo.components(separatedBy: "|")
                //只有是3个分组的才是时间信息
                if timeArr.count == 3 {
                    fileDict[tempPath] = (timeArr[0], timeArr[1], timeArr[2])
                }
            }
        }
        
        return fileDict
    }
    
    //毫秒数转换为时间
    func millisecondsStringToDate(_ millisecondsString: String) -> Date? {
         guard let milliseconds = Int64(millisecondsString) else {
             ShareAPI.shared().log(3, "[SaveFile] [SaveFileHandler] 无效的毫秒时间戳字符串")
             return nil
         }
        let timeInterval = TimeInterval(milliseconds) / 1000.0
        return Date(timeIntervalSince1970: timeInterval)
    }
    
    func convertStringToDate(_ dateStr: String) -> Date? {
        // 创建日期格式化器
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy:MM:dd HH:mm:ss"
        dateFormatter.locale = Locale(identifier: "en_US_POSIX") // 确保格式一致性
        dateFormatter.timeZone = TimeZone.current // 使用当前时区
        
        // 转换字符串为Date对象
        if let date = dateFormatter.date(from: dateStr) {
            ShareAPI.shared().log(1, "[SaveFile] [SaveFileHandler] 原始字符串: \(dateStr)")
            ShareAPI.shared().log(1, "[SaveFile] [SaveFileHandler] 转换后的Date对象: \(date)")
            ShareAPI.shared().log(1, "[SaveFile] [SaveFileHandler] 格式化显示: \(DateFormatter.localizedString(from: date, dateStyle: .long, timeStyle: .medium))")
            return date
        } else {
            ShareAPI.shared().log(3, "[SaveFile] [SaveFileHandler] 日期转换失败\(dateStr)")
            return nil
        }
    }
    
    //时间转换
    func getTimeInfo (_ timeInfo: (String, String, String)) -> Date? {
        let (date_added, date_taken, detail_time) = timeInfo
        if date_taken != NO_TIME_MS {
            return millisecondsStringToDate(date_taken)
        } else if detail_time != NO_TIME_STR {
            return convertStringToDate(detail_time)
        } else if date_added != NO_TIME_MS {
            return millisecondsStringToDate(date_added)
        } else {
            return nil
        }
    }
    
    // 获取组间内存大小
    func getGroupMemorys(_ currentGroup: [(String, String, String)], _ params: SaveFileParams) -> Int64 {
        var allMenorys: Int64 = 0
        for (_, _, path) in currentGroup {
            allMenorys = allMenorys + (params.tempFileSizeDict?[path] ?? 0)
        }
        return allMenorys
    }
    
    func groupAndSplitFiles(tempFilePaths: [(String, String, String)]?, _ chunkedCount: Int, _ params: SaveFileParams) -> [(String, [(String, String, String)])] {
        var result: [(String, [(String, String, String)])] = []
        guard let paths = tempFilePaths, !paths.isEmpty else {
            return result
        }
        var currentGroup: [(String, String, String)] = []
        var currentType: String? = nil
        
        for tuple in tempFilePaths ?? [] {
            var itemType = tuple.1
            //是否是实况图区分(初始化，点击重试，没有接收的缓存数据，需要重新判断)
            if itemType == "is_live_or_image" {
                if LivePhotoUtilOC.sharedInstance().isLivePhoto(tuple.2) {
                    itemType = "library_live_photo"
                } else {
                    itemType = "library_image"
                }
            }
            if let type = currentType, type == itemType {
                let groupSize = self.getGroupMemorys(currentGroup, params)
                let itemSize = self.getGroupMemorys([tuple], params)
                if currentGroup.count < chunkedCount, (groupSize + itemSize) <= CHUNKED_MEMORY_MAX {
                    currentGroup.append(tuple)
                } else {
                    result.append((type, currentGroup))
                    currentGroup = [tuple]
                }
            } else {
                if let type = currentType {
                    result.append((type, currentGroup))
                }
                currentGroup = [tuple]
                currentType = itemType
            }
        }
        
        if let type = currentType, !currentGroup.isEmpty {
            result.append((type, currentGroup))
        }
        
        return result
    }
    
    func removeAllFiles() {
        //删除任务放异步 （耗时但非紧急任务）
        DispatchQueue.global(qos: .utility).async {
            for filePath in self.filePaths ?? [] {
                self.removeFile(URL(fileURLWithPath: filePath))
            }
            let dir = FileSaver.getFileDirectory("temp")
            ShareAPI.shared().log(1, "[SaveFile] [SaveFileHandler] 取消删除这次接收任务")
            if self.tempSubDir != nil && self.tempSubDir != "" {
                FileSaver.removeFolder(atPath: "\(dir ?? "")/\(self.tempSubDir ?? "")", notEmpty: false)
            }
        }
    }
    
    func convertJSONStringToDictionaryForTime(_ jsonString: String) -> [String: [String]]? {
        let fixedJSONString = jsonString
            .replacingOccurrences(of: "\n", with: "")
            .replacingOccurrences(of: "\t", with: "")
        
        ShareAPI.shared().log(1, "[SaveFile] [SaveFileHandler] [timeInfo] \(jsonString)")
        ShareAPI.shared().log(1, "[SaveFile] [SaveFileHandler] [fixedTimeInfo] \(fixedJSONString)")
        
        guard let jsonData = fixedJSONString.data(using: .utf8) else {
            ShareAPI.shared().log(1, "[SaveFile] [SaveFileHandler] 无法将字符串转换为Data")
            return nil
        }
        
        do {
            let dictionary = try JSONSerialization.jsonObject(with: jsonData, options: []) as? [String: Any]
            var resDict = [String:[String]]()
            for (key, value) in dictionary ?? [String: Any]() {
                if let intArray = value as? [Int] {
                    resDict[key] = intArray.map{ String($0)}
                }else if let anyArray = value as? [Any] {
                    resDict[key] = anyArray.map{ String(describing: $0)}
                }
            }
            return resDict
        } catch {
            ShareAPI.shared().log(3, "[SaveFile] [SaveFileHandler] JSON解析错误: \(error.localizedDescription)")
            return nil
        }
    }
    
    //转换json字符
    func convertJSONStringToDictionary(_ jsonString: String) -> [String: Int]? {
        // 修复JSON字符串格式
        let fixedJSONString = jsonString
            .replacingOccurrences(of: "\n", with: "")
            .replacingOccurrences(of: "\t", with: "")
        
        ShareAPI.shared().log(1, "[SaveFile] [SaveFileHandler] [previewSummary] \(jsonString)")
        ShareAPI.shared().log(1, "[SaveFile] [SaveFileHandler] [fixedPreviewSummary] \(fixedJSONString)")
        
        guard let jsonData = fixedJSONString.data(using: .utf8) else {
            ShareAPI.shared().log(1, "[SaveFile] [SaveFileHandler] 无法将字符串转换为Data")
            return nil
        }
        
        do {
            let dictionary = try JSONSerialization.jsonObject(with: jsonData, options: []) as? [String: Int]
            return dictionary
        } catch {
            ShareAPI.shared().log(3, "[SaveFile] [SaveFileHandler] JSON解析错误: \(error.localizedDescription)")
            return nil
        }
    }
    
    //落盘初始化的时候检测previewSummary
    func checkPreviewSummary(_ sendType: String,_ previewSummary: String) {
        let previewDict = self.convertJSONStringToDictionary(previewSummary)
        //落盘判断（媒体文件如果有不支持图库的文件统一落盘文管中）
        if sendType == "0" {
            self.checkImageLibraryOrFile(previewDict)
            self.allFilesType = nil
        } else if sendType == "3" {
            SaveFileHandler.shared.checkIsMix(previewDict)
        } else if sendType == "4" {
            self.allFilesType = FileDirectoryType.others.rawValue
        } else if sendType == "8" {
            self.allFilesType = FileDirectoryType.contact.rawValue
        }
        
    }
    
    //判断整批媒体文件是否保存到文管或图库
    func checkImageLibraryOrFile(_ previewDict: [String: Int]?) {
//        var isLibrary = true;
//        let isLibraryArr = ["png","jpeg","jpe","webp","bmp","mpo","gif","tif","tiff","heif", "jpg", "heic", "mov", "mp4", "m4v","3g2","3gp","3gpp","mpg","mpeg" ,"mpe","mp4v","mpeg4","3gp2"]
//        _ = ["raw", "arw", "cr2", "psd", "ico", "dng", "flv", "rm", "wmv", "avi", "m2ts", "ts", "f4v"]
//
//        for (ext, _) in previewDict ?? [String: Int]() {
//            let tempExt = ext.dropFirst().lowercased()
//            if !isLibraryArr.contains(tempExt) {
//                isLibrary = false
//                break
//            }
//        }
//        self.allFilesPosition = isLibrary ? "library" : "file"
        self.allFilesPosition = "library"
    }
    
    // 大批量保存记录前判断是否为图库
    func checkImageLibraryOrFileByFiles(_ files: [String]?) -> String {
        var isLibrary = true;
        let isLibraryArr = ["png","jpeg","jpe","webp","bmp","mpo","gif","tif","tiff","heif", "jpg", "heic", "mov", "mp4", "m4v","3g2","3gp","3gpp","mpg","mpeg" ,"mpe","mp4v","mpeg4","3gp2"]
        _ = ["raw", "arw", "cr2", "psd", "ico", "dng", "flv", "rm", "wmv", "avi", "m2ts", "ts", "f4v"]
        for file in files ?? [] {
            let ext = (file as NSString).pathExtension.lowercased()
            if !isLibraryArr.contains(ext) {
                isLibrary = false
                break
            }
        }
        return isLibrary ? "library" : "file"
    }
    
    //文件，文件夹模式下存在mix类型
    func checkIsMix(_ previewDict: [String: Int]?) {
        let mediaArr = ["png","jpeg","jpe","webp","bmp","mpo","gif","tif","tiff","heif", "jpg", "heic", "mov", "mp4", "m4v","3g2","3gp","3gpp","mpg","mpeg" ,"mpe","mp4v","mpeg4","3gp2", "raw", "arw", "cr2", "psd", "ico", "dng", "flv", "rm", "wmv", "avi", "m2ts", "ts", "f4v", "raw", "arw", "cr2", "psd", "ico", "dng", "flv", "rm", "wmv", "avi", "m2ts", "ts", "f4v"]
       var hasMedia = false
       var hasFile = false
        for (ext, _) in previewDict ?? [String: Int]() {
           let tempExt = ext.dropFirst().lowercased()
           if mediaArr.contains(tempExt), !hasMedia {
               hasMedia = true
           } else if !mediaArr.contains(tempExt), !hasFile {
               hasFile = true
           }
       }
       // 同时有媒体文件和文件存入混合模式中
        if hasMedia, hasFile {
            self.allFilesType = "mix"
        } else {
            self.allFilesType = nil
        }
    }
    
    //检查内存大小
    func checkSpace(_ freeSpace: Int64) -> Bool {
        for path in self.allFilePaths ?? [] {
            let size = self.tempFileSizeDict?[path] ?? 0
            if size >= freeSpace {
                return false
            }
        }
        return true
    }
    
    //重新导入
    func reImportImage(files: [MITransferFile], id: Int64) {
        for file in files {
            file.status = .inProgress
            MIWCDBManager.shared.updateFileStoredDataStatus(file: file)
        }
        Task.detached {
            ReimportAlbum.shared.reImportImage(files, id: id)
        }
    }
    
    // 根据文件名称获取文件类型
    func getFileTypeByFileName(_ fileName: String) -> String {
        let fileExtension = (fileName as NSString).pathExtension.lowercased()
        switch fileExtension {
        //图片格式 (heic可以直接落苹果图库，直接当成静态图片存储)
        case "png","jpe","webp","bmp","mpo","gif","tif","tiff","heif":
            return "library_image";
        case "jpg", "heic", "jpeg":
            return "is_live_or_image";
        //视频
        case "mov", "mp4", "m4v","3g2","3gp","3gpp","mpg","mpeg" ,"mpe","mp4v","mpeg4","3gp2":
            return "library_video";
        case "raw", "arw", "cr2", "psd", "ico", "dng", "flv", "rm", "wmv", "avi", "m2ts", "ts", "f4v":
            return "library_image";
        //音频
        case "amr", "aac", "m4a","mp3","mp2","au","ac3","flac","snd","wav","ra":
            return FileDirectoryType.music.rawValue
        // 办公类文件
        case "pdf", "xltx", "xlt", "xlsx","xls","xlsm","doc","docx","docm","dotm","dotx","dot"
            ,"pptx","pptm","potx","pot","ppt","odt","ott","csv","txt","text","rtf","xml","html","htm"
            ,"cpp","c++","cxx","cc","h++","hxx","mm","h","m","hpp":
            return FileDirectoryType.doc.rawValue
        //备忘录
        case "hdoc":
            return FileDirectoryType.doc.rawValue
        // 通讯录
        case "vcf", "zcf":
            return FileDirectoryType.contact.rawValue
        //日历
        case "ics", "vcs":
            return FileDirectoryType.calender.rawValue
        //亚缩文件
        case "zip","rar","tar","gz","tar.gz","tgz","tar.xz","xz","7z","bz2":
            return FileDirectoryType.zip.rawValue
        default:
            return FileDirectoryType.others.rawValue
        }
    }
}

extension Array {
    func chunked(into size: Int) -> [[Element]] {
        return stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
}

// 落盘串行队列生成类
class SerialAsyncQueue {
    private var chainGroup: ChainTaskGroup?
    private var tasks:[(@escaping (Bool) -> Void) -> Void] = []
    private var currentTask: TaskOperation?
    private var currentIndex = 0
    
    func appendTasks(failTasks: [(@escaping (Bool) -> Void) -> Void], getProgress: @escaping(Float) -> Void) {
        self.tasks.insert(contentsOf: failTasks, at: self.currentIndex)
        
        let preTask = self.currentTask
        if (preTask != nil) {
            for failTask in failTasks {
                let task = self.addTaskToGroup(itemTask: failTask, getProgress: getProgress)
                if let tempPreTask = preTask {
                    self.chainGroup?.insert(task, after: tempPreTask)
                }
            }
        }
    }
    
    
    //添加任务到组内
    func addTaskToGroup(itemTask: @escaping (@escaping (Bool) -> Void) -> Void, getProgress: @escaping(Float) -> Void) -> TaskOperation {
        let task = TaskOperation.async(identifier: "\(UUID().uuidString)") {[weak self] task in
            self?.currentTask = task
            itemTask {[weak self] success in
                guard let weakSelf = self else {return}
                getProgress(weakSelf.getProgress())
                weakSelf.currentIndex = weakSelf.currentIndex + 1
                task.finish(true)
            }
        }
        
        return task
    }
    
    func getProgress() -> Float {
        return Float(currentIndex + 1) / Float(self.tasks.count)
    }
    
    func execute(tasks: [(@escaping (Bool) -> Void) -> Void], getProgress: @escaping(Float) -> Void, completion: @escaping () -> Void) {
        self.currentIndex = 0
        self.tasks = tasks
        if self.tasks.count == 0 {
            completion()
            return
        }
        
        self.chainGroup = TaskQueueManager.createChainGroup()
        
        for itemTask in self.tasks {
            let task = self.addTaskToGroup(itemTask: itemTask, getProgress: getProgress)
            self.chainGroup?.add(task)
        }
        
        self.chainGroup?.onAllTasksFinished = { success in
           completion()
        }
        
        self.chainGroup?.start()
    }
}

