import Cocoa
import Photos
import SQLite3
import AppKit
import CoreGraphics
import ImageIO


class LivePhotoAddressFetcher {
    
    // 获取 IMG_9509 实况图的视频和图片地址
    static func getLivePhotoAddressesForIMG9509() -> LivePhotoAddressResult {
        return getLivePhotoAddresses(by: "IMG_9509")
    }
    
    // 通用方法：通过基础名称获取实况图地址
    static func getLivePhotoAddresses(by baseName: String) -> LivePhotoAddressResult {
        print("=== 从照片库获取实况图地址 ===")
        print("查询名称: \(baseName)")
        
        var result = LivePhotoAddressResult(baseName: baseName)
        
        // 获取照片库数据库路径
        guard let databasePath = findPhotosDatabasePath() else {
            result.error = "未找到照片库数据库"
            return result
        }
        
        print("照片库数据库: \(databasePath)")
        
        // 查询实况图资产
        if let assets = queryLivePhotoAssets(databasePath, baseName: baseName) {
            result.assets = assets
            (result.imagePath, result.videoPath) = findLivePhotoPair(from: assets, baseName: baseName)
        } else {
            result.error = "数据库查询失败"
        }
        
        return result
    }
    
    func findPhotosDatabasePath() -> String? {
        let fileManager = FileManager.default
        
        let photoLibraryPaths = [
            "~/Pictures/Photos Library.photoslibrary/database/Photos.sqlite",
            "~/Library/Containers/com.apple.Photos/Data/Library/Photos Library.photoslibrary/database/Photos.sqlite"
        ]
        
        for path in photoLibraryPaths {
            let expandedPath = (path as NSString).expandingTildeInPath
            if fileManager.fileExists(atPath: expandedPath) {
                return expandedPath
            }
        }
        
        return nil
    }
}

struct LivePhotoAddressResult {
    let baseName: String
    var assets: [LivePhotoAsset] = []
    var imagePath: String?
    var videoPath: String?
    var error: String?
    
    var success: Bool { imagePath != nil && videoPath != nil }
    var foundAssets: Int { assets.count }
}

struct LivePhotoAsset {
    let uuid: String
    let filename: String
    let directory: String?
    let uniformTypeIdentifier: String
    let creationDate: Date?
    let isVideo: Bool
    let fileSize: Int64?
    let width: Int?
    let height: Int?
}
extension LivePhotoAddressFetcher {
    
    private static func queryLivePhotoAssets(_ databasePath: String, baseName: String) -> [LivePhotoAsset]? {
        var db: OpaquePointer?
        
        guard sqlite3_open(databasePath, &db) == SQLITE_OK else {
            print("❌ 无法打开数据库")
            return nil
        }
        
        defer {
            sqlite3_close(db)
        }
        
        print("✅ 成功打开照片库数据库")
        
        var assets: [LivePhotoAsset] = []
        
        // 查询匹配名称的所有相关资产（图片和视频）
        let query = """
        SELECT 
            ZUUID,
            ZFILENAME,
            ZDIRECTORY,
            ZUNIFORMTYPEIDENTIFIER,
            ZDATECREATED,
            ZPIXELWIDTH,
            ZPIXELHEIGHT,
            ZFILESIZE,
            ZKIND
        FROM ZGENERICASSET 
        WHERE ZFILENAME LIKE '%\(baseName)%'
        ORDER BY ZDATECREATED DESC
        """
        
        var statement: OpaquePointer?
        
        if sqlite3_prepare_v2(db, query, -1, &statement, nil) == SQLITE_OK {
            while sqlite3_step(statement) == SQLITE_ROW {
                if let asset = parseLivePhotoAssetRow(statement) {
                    assets.append(asset)
                    let type = asset.isVideo ? "视频" : "图片"
                    print("找到资产: \(asset.filename) - \(type)")
                }
            }
            sqlite3_finalize(statement)
        } else {
            let error = String(cString: sqlite3_errmsg(db))
            print("❌ 查询失败: \(error)")
            return nil
        }
        
        return assets.isEmpty ? nil : assets
    }
    
    private static func parseLivePhotoAssetRow(_ statement: OpaquePointer?) -> LivePhotoAsset? {
        // UUID
        guard let uuidPtr = sqlite3_column_text(statement, 0) else { return nil }
        let uuid = String(cString: uuidPtr)
        
        // 文件名
        guard let filenamePtr = sqlite3_column_text(statement, 1) else { return nil }
        let filename = String(cString: filenamePtr)
        
        // 目录
        let directoryPtr = sqlite3_column_text(statement, 2)
        let directory = directoryPtr != nil ? String(cString: directoryPtr!) : nil
        
        // 文件类型
        let utiPtr = sqlite3_column_text(statement, 3)
        let uniformTypeIdentifier = utiPtr != nil ? String(cString: utiPtr!) : ""
        
        // 创建时间
        let timestamp = sqlite3_column_double(statement, 4)
        let creationDate = timestamp > 0 ? Date(timeIntervalSinceReferenceDate: timestamp) : nil
        
        // 图片尺寸
        let width = sqlite3_column_int(statement, 5)
        let height = sqlite3_column_int(statement, 6)
        
        // 文件大小
        let fileSize = sqlite3_column_int64(statement, 7)
        
        // 资产类型 (0=图片, 1=视频, 2=其他)
        let kind = sqlite3_column_int(statement, 8)
        let isVideo = (kind == 1 || uniformTypeIdentifier.contains("video"))
        
        return LivePhotoAsset(
            uuid: uuid,
            filename: filename,
            directory: directory,
            uniformTypeIdentifier: uniformTypeIdentifier,
            creationDate: creationDate,
            isVideo: isVideo,
            fileSize: fileSize > 0 ? fileSize : nil,
            width: width > 0 ? Int(width) : nil,
            height: height > 0 ? Int(height) : nil
        )
    }
}
extension LivePhotoAddressFetcher {
    
    private static func findLivePhotoPair(from assets: [LivePhotoAsset], baseName: String) -> (String?, String?) {
        var imageAsset: LivePhotoAsset?
        var videoAsset: LivePhotoAsset?
        
        print("开始配对实况图组件...")
        
        // 首先尝试精确匹配
        for asset in assets {
            let assetBaseName = (asset.filename as NSString).deletingPathExtension
            
            if assetBaseName == baseName {
                if !asset.isVideo {
                    imageAsset = asset
                    print("✅ 找到匹配的图片: \(asset.filename)")
                } else {
                    videoAsset = asset
                    print("✅ 找到匹配的视频: \(asset.filename)")
                }
            }
        }
        
        // 如果精确匹配失败，尝试查找相关文件
        if imageAsset == nil || videoAsset == nil {
            print("精确匹配失败，尝试相关文件匹配...")
            
            for asset in assets {
                let assetBaseName = (asset.filename as NSString).deletingPathExtension
                
                // 检查文件名相关性
                if isFilenameRelated(assetBaseName, baseName) {
                    if !asset.isVideo && imageAsset == nil {
                        imageAsset = asset
                        print("✅ 找到相关的图片: \(asset.filename)")
                    } else if asset.isVideo && videoAsset == nil {
                        videoAsset = asset
                        print("✅ 找到相关的视频: \(asset.filename)")
                    }
                }
            }
        }
        
        // 构建完整路径
        let imagePath = imageAsset != nil ? constructAssetPath(asset: imageAsset!) : nil
        let videoPath = videoAsset != nil ? constructAssetPath(asset: videoAsset!) : nil
        
        if let imagePath = imagePath, let videoPath = videoPath {
            print("🎉 成功找到实况图配对!")
            return (imagePath, videoPath)
        } else {
            print("❌ 未找到完整的实况图配对")
            return (imagePath, videoPath)
        }
    }
    
    private static func isFilenameRelated(_ filename1: String, _ filename2: String) -> Bool {
        // 完全匹配
        if filename1 == filename2 {
            return true
        }
        
        // iPhone 实况图命名模式
        if filename1.hasPrefix("IMG_") && filename2.hasPrefix("IMG_") {
            let number1 = String(filename1.dropFirst(4))
            let number2 = String(filename2.dropFirst(4))
            
            // 数字部分相同
            if number1 == number2 {
                return true
            }
            
            // 处理编辑版本 (IMG_E 前缀)
            if filename1.hasPrefix("IMG_E") && filename2.hasPrefix("IMG_") {
                let editedNumber = String(filename1.dropFirst(5))
                if editedNumber == number2 {
                    return true
                }
            }
            
            // 处理 HEIC 变体
            if filename1.hasSuffix("-HEIC") && !filename2.hasSuffix("-HEIC") {
                let cleanName = String(filename1.dropLast(5))
                if cleanName == filename2 {
                    return true
                }
            }
        }
        
        return false
    }
    
    private static func constructAssetPath(asset: LivePhotoAsset) -> String {
        let photoLibraryRoots = [
            "~/Pictures/Photos Library.photoslibrary",
            "~/Library/Containers/com.apple.Photos/Data/Library/Photos Library.photoslibrary"
        ]
        
        for rootPath in photoLibraryRoots {
            let expandedRoot = (rootPath as NSString).expandingTildeInPath
            
            // 尝试不同目录结构
            let directories = ["Masters", "Originals", "resources/media", "resources/proxies"]
            
            for directoryName in directories {
                let fullDirectoryPath = "\(expandedRoot)/\(directoryName)"
                
                if let assetDirectory = asset.directory {
                    let fullPath = "\(fullDirectoryPath)/\(assetDirectory)/\(asset.filename)"
                    if FileManager.default.fileExists(atPath: fullPath) {
                        print("✅ 找到文件: \(fullPath)")
                        return fullPath
                    }
                }
                
                // 尝试直接文件名
                let directPath = "\(fullDirectoryPath)/\(asset.filename)"
                if FileManager.default.fileExists(atPath: directPath) {
                    print("✅ 找到文件: \(directPath)")
                    return directPath
                }
            }
        }
        
        // 返回理论路径（即使文件不存在）
        if let directory = asset.directory {
            return "Masters/\(directory)/\(asset.filename)"
        } else {
            return "Masters/\(asset.filename)"
        }
    }
}



extension LivePhotoAddressFetcher {
    
    // 获取图库中的所有图片
    static func getAllPhotosFromLibrary(limit: Int = 100, offset: Int = 0) -> PhotoLibraryResult {
        print("=== 获取图库所有图片 ===")
        print("限制: \(limit), 偏移: \(offset)")
        
        var result = PhotoLibraryResult()
        
        // 获取照片库数据库路径
        guard let databasePath = findPhotosDatabasePath() else {
            result.error = "未找到照片库数据库"
            return result
        }
        
        print("照片库数据库: \(databasePath)")
        
        // 查询所有图片
        if let photos = queryAllPhotos(databasePath, limit: limit, offset: offset) {
            result.photos = photos
            result.totalCount = getTotalPhotoCount(databasePath)
        } else {
            result.error = "数据库查询失败"
        }
        
        return result
    }
    
    private static func findPhotosDatabasePath() -> String? {
        let fileManager = FileManager.default
        
        let photoLibraryPaths = [
            "~/Pictures/Photos Library.photoslibrary/database/Photos.sqlite",
            "~/Library/Containers/com.apple.Photos/Data/Library/Photos Library.photoslibrary/database/Photos.sqlite"
        ]
        
        for path in photoLibraryPaths {
            let expandedPath = (path as NSString).expandingTildeInPath
            if fileManager.fileExists(atPath: expandedPath) {
                return expandedPath
            }
        }
        
        return nil
    }
}

struct PhotoLibraryResult {
    var photos: [LibraryPhoto] = []
    var totalCount: Int = 0
    var error: String?
    
    var success: Bool { error == nil }
}

struct LibraryPhoto {
    let uuid: String
    let filename: String
    let directory: String?
    let uniformTypeIdentifier: String
    let creationDate: Date?
    let modificationDate: Date?
    let fileSize: Int64
    let width: Int
    let height: Int
    let filePath: String
    let duration: Double? // 对于实况图和视频
    let isLivePhoto: Bool
}

extension LivePhotoAddressFetcher {
    
    private static func queryAllPhotos(_ databasePath: String, limit: Int, offset: Int) -> [LibraryPhoto]? {
        var db: OpaquePointer?
        
        guard sqlite3_open(databasePath, &db) == SQLITE_OK else {
            print("❌ 无法打开数据库")
            return nil
        }
        
        defer {
            sqlite3_close(db)
        }
        
        print("✅ 成功打开照片库数据库")
        
        var photos: [LibraryPhoto] = []
        
        // 查询所有图片（包括实况图）
        let query = """
        SELECT 
            ZUUID,
            ZFILENAME,
            ZDIRECTORY,
            ZUNIFORMTYPEIDENTIFIER,
            ZDATECREATED,
            ZDATEADDED,
            ZPIXELWIDTH,
            ZPIXELHEIGHT,
            ZFILESIZE,
            ZDURATION,
            ZLIVEPHOTOVIDEOSTATE
        FROM ZGENERICASSET 
        WHERE ZKIND = 0 OR ZUNIFORMTYPEIDENTIFIER LIKE '%image%'
        ORDER BY ZDATECREATED DESC
        LIMIT \(limit) OFFSET \(offset)
        """
        
        var statement: OpaquePointer?
        
        if sqlite3_prepare_v2(db, query, -1, &statement, nil) == SQLITE_OK {
            while sqlite3_step(statement) == SQLITE_ROW {
                if let photo = parsePhotoRow(statement) {
                    photos.append(photo)
                }
            }
            sqlite3_finalize(statement)
        } else {
            let error = String(cString: sqlite3_errmsg(db))
            print("❌ 查询失败: \(error)")
            return nil
        }
        
        print("✅ 找到 \(photos.count) 张图片")
        return photos
    }
    
    private static func parsePhotoRow(_ statement: OpaquePointer?) -> LibraryPhoto? {
        // UUID
        guard let uuidPtr = sqlite3_column_text(statement, 0) else { return nil }
        let uuid = String(cString: uuidPtr)
        
        // 文件名
        guard let filenamePtr = sqlite3_column_text(statement, 1) else { return nil }
        let filename = String(cString: filenamePtr)
        
        // 目录
        let directoryPtr = sqlite3_column_text(statement, 2)
        let directory = directoryPtr != nil ? String(cString: directoryPtr!) : nil
        
        // 文件类型
        let utiPtr = sqlite3_column_text(statement, 3)
        let uniformTypeIdentifier = utiPtr != nil ? String(cString: utiPtr!) : ""
        
        // 创建时间
        let creationTimestamp = sqlite3_column_double(statement, 4)
        let creationDate = creationTimestamp > 0 ? Date(timeIntervalSinceReferenceDate: creationTimestamp) : nil
        
        // 添加时间
        let addedTimestamp = sqlite3_column_double(statement, 5)
        let addedDate = addedTimestamp > 0 ? Date(timeIntervalSinceReferenceDate: addedTimestamp) : nil
        
        // 图片尺寸
        let width = Int(sqlite3_column_int(statement, 6))
        let height = Int(sqlite3_column_int(statement, 7))
        
        // 文件大小
        let fileSize = sqlite3_column_int64(statement, 8)
        
        // 持续时间（实况图/视频）
        let duration = sqlite3_column_double(statement, 9)
        
        // 实况图状态
        let livePhotoState = sqlite3_column_int(statement, 10)
        let isLivePhoto = (livePhotoState == 1)
        
        // 构建文件路径
        let filePath = constructPhotoPath(filename: filename, directory: directory)
        
        return LibraryPhoto(
            uuid: uuid,
            filename: filename,
            directory: directory,
            uniformTypeIdentifier: uniformTypeIdentifier,
            creationDate: creationDate,
            modificationDate: addedDate,
            fileSize: fileSize,
            width: width,
            height: height,
            filePath: filePath,
            duration: duration > 0 ? duration : nil,
            isLivePhoto: isLivePhoto
        )
    }
    
    private static func getTotalPhotoCount(_ databasePath: String) -> Int {
        var db: OpaquePointer?
        
        guard sqlite3_open(databasePath, &db) == SQLITE_OK else {
            return 0
        }
        
        defer {
            sqlite3_close(db)
        }
        
        let query = """
        SELECT COUNT(*) 
        FROM ZGENERICASSET 
        WHERE ZKIND = 0 OR ZUNIFORMTYPEIDENTIFIER LIKE '%image%'
        """
        
        var statement: OpaquePointer?
        var count = 0
        
        if sqlite3_prepare_v2(db, query, -1, &statement, nil) == SQLITE_OK {
            if sqlite3_step(statement) == SQLITE_ROW {
                count = Int(sqlite3_column_int(statement, 0))
            }
            sqlite3_finalize(statement)
        }
        
        return count
    }
}
extension LivePhotoAddressFetcher {
    
    private static func constructPhotoPath(filename: String, directory: String?) -> String {
        let photoLibraryRoots = [
            "~/Pictures/Photos Library.photoslibrary",
            "~/Library/Containers/com.apple.Photos/Data/Library/Photos Library.photoslibrary"
        ]
        
        for rootPath in photoLibraryRoots {
            let expandedRoot = (rootPath as NSString).expandingTildeInPath
            
            // 尝试不同目录结构
            let directories = ["Masters", "Originals", "resources/media", "resources/proxies"]
            
            for directoryName in directories {
                let fullDirectoryPath = "\(expandedRoot)/\(directoryName)"
                
                if let photoDirectory = directory {
                    let fullPath = "\(fullDirectoryPath)/\(photoDirectory)/\(filename)"
                    if FileManager.default.fileExists(atPath: fullPath) {
                        return fullPath
                    }
                }
                
                // 尝试直接文件名
                let directPath = "\(fullDirectoryPath)/\(filename)"
                if FileManager.default.fileExists(atPath: directPath) {
                    return directPath
                }
            }
        }
        
        // 返回理论路径
        if let directory = directory {
            return "Masters/\(directory)/\(filename)"
        } else {
            return "Masters/\(filename)"
        }
    }
}
extension LivePhotoAddressFetcher {
    
    // 获取特定类型的图片
    static func getPhotosByType(_ type: PhotoType, limit: Int = 50) -> PhotoLibraryResult {
        var result = PhotoLibraryResult()
        
        guard let databasePath = findPhotosDatabasePath() else {
            result.error = "未找到照片库数据库"
            return result
        }
        
        var typeCondition = ""
        switch type {
        case .livePhotos:
            typeCondition = "ZLIVEPHOTOVIDEOSTATE = 1"
        case .heic:
            typeCondition = "ZUNIFORMTYPEIDENTIFIER LIKE '%heic%'"
        case .jpeg:
            typeCondition = "ZUNIFORMTYPEIDENTIFIER LIKE '%jpeg%'"
        case .png:
            typeCondition = "ZUNIFORMTYPEIDENTIFIER LIKE '%png%'"
        case .all:
            typeCondition = "ZKIND = 0 OR ZUNIFORMTYPEIDENTIFIER LIKE '%image%'"
        }
        
        let query = """
        SELECT 
            ZUUID, ZFILENAME, ZDIRECTORY, ZUNIFORMTYPEIDENTIFIER,
            ZDATECREATED, ZDATEADDED, ZPIXELWIDTH, ZPIXELHEIGHT,
            ZFILESIZE, ZDURATION, ZLIVEPHOTOVIDEOSTATE
        FROM ZGENERICASSET 
        WHERE \(typeCondition)
        ORDER BY ZDATECREATED DESC
        LIMIT \(limit)
        """
        
        if let photos = executeCustomQuery(databasePath, query: query) {
            result.photos = photos
            result.totalCount = photos.count
        } else {
            result.error = "查询失败"
        }
        
        return result
    }
    
    // 按时间范围获取图片
    static func getPhotosByDateRange(from startDate: Date, to endDate: Date) -> PhotoLibraryResult {
        var result = PhotoLibraryResult()
        
        guard let databasePath = findPhotosDatabasePath() else {
            result.error = "未找到照片库数据库"
            return result
        }
        
        let startTimestamp = startDate.timeIntervalSinceReferenceDate
        let endTimestamp = endDate.timeIntervalSinceReferenceDate
        
        let query = """
        SELECT 
            ZUUID, ZFILENAME, ZDIRECTORY, ZUNIFORMTYPEIDENTIFIER,
            ZDATECREATED, ZDATEADDED, ZPIXELWIDTH, ZPIXELHEIGHT,
            ZFILESIZE, ZDURATION, ZLIVEPHOTOVIDEOSTATE
        FROM ZGENERICASSET 
        WHERE ZDATECREATED BETWEEN \(startTimestamp) AND \(endTimestamp)
          AND (ZKIND = 0 OR ZUNIFORMTYPEIDENTIFIER LIKE '%image%')
        ORDER BY ZDATECREATED DESC
        """
        
        if let photos = executeCustomQuery(databasePath, query: query) {
            result.photos = photos
            result.totalCount = photos.count
        } else {
            result.error = "查询失败"
        }
        
        return result
    }
    
    private static func executeCustomQuery(_ databasePath: String, query: String) -> [LibraryPhoto]? {
        var db: OpaquePointer?
        
        guard sqlite3_open(databasePath, &db) == SQLITE_OK else {
            return nil
        }
        
        defer {
            sqlite3_close(db)
        }
        
        var photos: [LibraryPhoto] = []
        var statement: OpaquePointer?
        
        if sqlite3_prepare_v2(db, query, -1, &statement, nil) == SQLITE_OK {
            while sqlite3_step(statement) == SQLITE_ROW {
                if let photo = parsePhotoRow(statement) {
                    photos.append(photo)
                }
            }
            sqlite3_finalize(statement)
        }
        
        return photos.isEmpty ? nil : photos
    }
}

enum PhotoType {
    case all
    case livePhotos
    case heic
    case jpeg
    case png
}

extension LivePhotoAddressFetcher {
    
    
    static func getImg(ur:URL){
        //        let result = LivePhotoAddressFetcher.getAllPhotosFromLibrary(limit: 100, offset: 0)
        //       print("=====\(result.photos)")
    }
    
    
}

extension LivePhotoAddressFetcher {
    func requestPhotoLibraryAccess(nameStr:String,completion assetBlock: @escaping (PHAsset?) -> Void) {
        PHPhotoLibrary.requestAuthorization { status in
            switch status {
            case .authorized:
                print("已获得照片库访问权限")
                var imgAsset:PHAsset? = nil
                let imgName = nameStr
                let serialQueue = DispatchQueue(label: "com.MutualInfection.serial")
                let dispatchMacGroup = DispatchGroup()
                dispatchMacGroup.enter()
                serialQueue.sync {
                    self.fetchPhotos(nameStr: "\(imgName)") { asset in
                        imgAsset = asset ?? nil
                        dispatchMacGroup.leave()
                    }
                }
                dispatchMacGroup.notify(queue: .main) {
                    assetBlock(imgAsset)
                }
            case .denied, .restricted:
                print("照片库访问被拒绝")
                assetBlock(nil)
            case .notDetermined:
                print("未决定照片库访问权限")
                assetBlock(nil)
            case .limited:
                print("获得有限访问权限")
                assetBlock(nil)
            @unknown default:
                assetBlock(nil)
                break
            }
        }
    }
    
    func fetchPhotos(nameStr:String,completion assetBlock: @escaping (PHAsset?) -> Void) {
        let fetchOptions = PHFetchOptions()
        fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        
        let fetchResult = PHAsset.fetchAssets(with: .image, options: fetchOptions)
        
        // 获取图片作为示例
        // 遍历所有资源获取信息
        fetchResult.enumerateObjects { (asset, index, stop) in
            let assetInfo = LivePhotoAddressFetcher.getAssetNameAndInfo(asset)
            if assetInfo.filename.isEmpty{
                assetBlock(nil)
                return
            }
            print("""
               图片信息:
               名称: \(assetInfo.name)
               文件名: \(assetInfo.filename)
               文件大小: \(assetInfo.fileSize)
               创建日期: \(assetInfo.creationDate?.description ?? "未知")
               """)
            let nameString = assetInfo.filename
            let name = (nameString as NSString).deletingPathExtension
            if name == nameStr{
                assetBlock(asset)
                stop.pointee = true
            }else{
                if index == fetchResult.count - 1 {
                    assetBlock(nil)
                }
            }
        }
    }
    private static func requestImage(for asset: PHAsset) {
        let manager = PHImageManager.default()
        let options = PHImageRequestOptions()
        options.isSynchronous = false
        options.deliveryMode = .highQualityFormat
        
        manager.requestImage(for: asset,
                             targetSize: CGSize(width: 1024, height: 1024),
                             contentMode: .aspectFit,
                             options: options) { (image, info) in
            if let image = image {
                DispatchQueue.main.async {
                    // 处理获取到的图片
                    //                    self.handleSelectedPhotoLibraryImage(image)
                }
            }
        }
    }
    static func getAssetNameAndInfo(_ asset: PHAsset) -> (name: String, filename: String, fileSize: String, creationDate: Date?) {
        
        var assetName = "未命名"
        var originalFilename = "未命名"
        var fileSizeInfo = "未知"
        let creationDate = asset.creationDate
        
        // 获取资源资源列表
        let resources = PHAssetResource.assetResources(for: asset)
        
        // 查找原始图片资源
        if let resource = resources.first {
            // 获取原始文件名（这是最可靠的方法）
            originalFilename = resource.originalFilename
            assetName = originalFilename
            
            // 获取文件大小
            if let fileSize = resource.value(forKey: "fileSize") as? Int {
                fileSizeInfo = self.formatFileSize(fileSize)
            }
            
            // 尝试获取更多元数据
            //            print("资源类型: \(resource.type.rawValue)")
            //            print("统一类型标识: \(resource.uniformTypeIdentifier)")
        }
        
        return (assetName, originalFilename, fileSizeInfo, creationDate)
    }
    
    private static func formatFileSize(_ bytes: Int) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useMB, .useKB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(bytes))
    }
    
    // MARK: - 获取uuid
    func extractUUIDFromPath(_ path: String) -> String? {
        // 从路径中提取 UUID 模式
        // 提取UUID部分
        let url = URL(fileURLWithPath: path)
        let components = url.pathComponents
        
        // 查找 ShareKit-Exports 目录的位置
        if let exportsIndex = components.firstIndex(of: "ShareKit-Exports"),
           exportsIndex + 2 < components.count {
            let photoUUID = components[exportsIndex + 2]
            
            // 验证是否为有效的UUID格式
            func isValidUUID(_ string: String) -> Bool {
                let pattern = "^[0-9A-F]{8}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{12}$"
                return string.range(of: pattern, options: [.regularExpression, .caseInsensitive]) != nil
            }
            print("查找到的路径===\(path)")
            ShareAPI.shared().log(1, "查找到的uuid===\(photoUUID)")
            return (isValidUUID(photoUUID) ? photoUUID : nil)
        }else{
            let uuidPattern = "[A-F0-9]{8}-[A-F0-9]{4}-[A-F0-9]{4}-[A-F0-9]{4}-[A-F0-9]{12}"
            
            if let range = path.range(of: uuidPattern, options: .regularExpression) {
                ShareAPI.shared().log(1, "LivePhotoAddressFetcher找到uuid====\(String(path[range]))")
                return String(path[range])
            }
        }        
        ShareAPI.shared().log(1, "没找到uuid====")

        return nil
    }
    // MARK: - 获取asset
    func fetchPhotoAsset(_ uuid: String) -> PHAsset? {
        // 使用提取的UUID查找照片资产
        let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: [uuid], options: nil)
        
        if let asset = fetchResult.firstObject {
            return asset
        }
        
        return nil
    }
    /// 判断是否实况图
    func checkAssetIsPhotoLive(_ asset: PHAsset?) -> Bool {
        guard let asset = asset else {
            return false
        }
        
        if asset.mediaSubtypes.contains(.photoLive) {
            return true
        }
        
        return false
    }
    
    func isFromSystemPhotoLibrary(_ url: URL) -> Bool {
        guard url.isFileURL else { return false }
        
        let path = url.path
        // 检查系统相库路径
        let photoLibraryPaths = [
            "/Users/\(NSUserName())/Pictures/Photos Library.photoslibrary",
            "/var/folders", // 临时文件路径也可能包含相册图片
            "/com.apple.Photos/"
        ]
        
        return photoLibraryPaths.contains { path.contains($0) }
    } 
    
    func getHDRimgUrl(url:URL) -> URL{
        var tempUrl: URL?
        do {
            let imageData = try Data(contentsOf: url)
            guard let image = NSImage(data: imageData) else {
                return url
            }
            // 判断是否是 HDR 图片
            let isHDR = isHDRImage(image: image)
            ShareAPI.shared().log(1, "非图库图片是否是HDR图===\(isHDR)")
            if isHDR{
                if shouldKeepOriginalImageFile(url) {
                    ShareAPI.shared().log(1, "[EXIF] HDR源文件已是JPEG，保留原文件避免大小变化 path=\(url.path)")
                    return url
                }
                ShareAPI.shared().log(1, "该图片是HDR图")
                let fileName = url.deletingPathExtension().lastPathComponent + ".jpeg"
                tempUrl = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
                
                // 移除已存在的临时文件
                try? FileManager.default.removeItem(at: tempUrl!)
                // HDR 图需要重新落盘为 JPEG，但这里要把原图 EXIF 一并带过去，
                // 否则相机照片的 DateTimeOriginal 会在发送前就丢掉。
                try writeJPEGPreservingMetadata(from: url, image: image, to: tempUrl!)
                return tempUrl!
            }else{
                return url
            }
            
        }catch {
            ShareAPI.shared().log(1, "不不不不是HDR图")
            return url
        }
    }
    func urlToHDRimgUrl(url:URL) -> URL{
        do {
            let imageData = try Data(contentsOf: url)
            guard let image = NSImage(data: imageData) else {
                return url
            }
            if shouldKeepOriginalImageFile(url) {
                ShareAPI.shared().log(1, "[EXIF] 图库HDR导出已是JPEG，保留原文件避免大小变化 path=\(url.path)")
                return url
            }
            let fileName = url.deletingPathExtension().lastPathComponent + ".jpeg"
           var tempUrl = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
            
            // 移除已存在的临时文件
            try? FileManager.default.removeItem(at: tempUrl)
            // 图库导出的 HDR/HEIC 在转成可发送 JPEG 时，保留原始元数据。
            try writeJPEGPreservingMetadata(from: url, image: image, to: tempUrl)
            return tempUrl
        }catch {
            ShareAPI.shared().log(1, "urlToHDRimgUrl = 不不不不是HDR图")
            return url
        }
    }    
    
    private func shouldKeepOriginalImageFile(_ url: URL) -> Bool {
        let lowercasedExtension = url.pathExtension.lowercased()
        if lowercasedExtension == "jpg" || lowercasedExtension == "jpeg" {
            return true
        }
        
        guard let source = CGImageSourceCreateWithURL(url as CFURL, [kCGImageSourceShouldCache: false] as CFDictionary),
              let uti = CGImageSourceGetType(source) as String? else {
            return false
        }
        
        return uti == "public.jpeg"
    }
    
    private func writeJPEGPreservingMetadata(from sourceURL: URL, image: NSImage, to destinationURL: URL) throws {
        let jpegUTType = "public.jpeg" as CFString
        guard let source = CGImageSourceCreateWithURL(sourceURL as CFURL, [kCGImageSourceShouldCache: false] as CFDictionary),
              let sourceProperties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let outputImage = makeJPEGCompatibleCGImage(from: image) else {
            throw NSError(domain: "LivePhotoAddressFetcher", code: -1)
        }
        
        logImageMetadataSummary(at: sourceURL, label: "HDR源文件")
        
        // 尽量带上原图可兼容的 JPEG 属性，同时通过 metadata 对象把 EXIF/IPTC/XMP
        // 这类标准标签整体复制过去，减少转码后的信息变化。
        let sourceMetadata = CGImageSourceCopyMetadataAtIndex(source, 0, nil)
        var outputProperties = sanitizedJPEGProperties(from: sourceProperties)
        outputProperties[kCGImageDestinationOptimizeColorForSharing] = false
        
        let targetFileSize = (try? sourceURL.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
        let encodedResult = try makeJPEGDataMatchingFileSize(
            image: outputImage,
            metadata: sourceMetadata,
            baseProperties: outputProperties,
            targetFileSize: targetFileSize,
            jpegUTType: jpegUTType
        )
        
        try encodedResult.data.write(to: destinationURL, options: .atomic)
        
        ShareAPI.shared().log(
            1,
            "[EXIF] JPEG体积逼近 targetBytes=\(targetFileSize) outputBytes=\(encodedResult.data.count) quality=\(String(format: "%.4f", encodedResult.quality)) embedThumbnail=\(encodedResult.embedThumbnail)"
        )
        
        if encodedResult.data.isEmpty {
            throw NSError(domain: "LivePhotoAddressFetcher", code: -2)
        }
        
        logImageMetadataSummary(at: destinationURL, label: "HDR输出文件")
    }
    
    private func makeJPEGDataMatchingFileSize(
        image: CGImage,
        metadata: CGImageMetadata?,
        baseProperties: [CFString: Any],
        targetFileSize: Int,
        jpegUTType: CFString
    ) throws -> (data: Data, quality: Double, embedThumbnail: Bool) {
        let qualityRange = (lower: 0.4, upper: 1.0)
        let embedThumbnailCandidates = [true, false]
        var bestResult: (data: Data, quality: Double, embedThumbnail: Bool)?
        var bestDistance = Int.max
        
        for embedThumbnail in embedThumbnailCandidates {
            let lowerResult = try encodeJPEGData(
                image: image,
                metadata: metadata,
                baseProperties: baseProperties,
                quality: qualityRange.lower,
                embedThumbnail: embedThumbnail,
                jpegUTType: jpegUTType
            )
            let upperResult = try encodeJPEGData(
                image: image,
                metadata: metadata,
                baseProperties: baseProperties,
                quality: qualityRange.upper,
                embedThumbnail: embedThumbnail,
                jpegUTType: jpegUTType
            )
            
            updateBestJPEGResult(candidate: lowerResult, targetFileSize: targetFileSize, bestResult: &bestResult, bestDistance: &bestDistance)
            updateBestJPEGResult(candidate: upperResult, targetFileSize: targetFileSize, bestResult: &bestResult, bestDistance: &bestDistance)
            
            var lowerQuality = qualityRange.lower
            var upperQuality = qualityRange.upper
            var lowerSize = lowerResult.data.count
            var upperSize = upperResult.data.count
            
            guard targetFileSize > 0,
                  lowerSize != upperSize,
                  min(lowerSize, upperSize) <= targetFileSize,
                  max(lowerSize, upperSize) >= targetFileSize else {
                continue
            }
            
            for _ in 0..<8 {
                let middleQuality = (lowerQuality + upperQuality) / 2
                let middleResult = try encodeJPEGData(
                    image: image,
                    metadata: metadata,
                    baseProperties: baseProperties,
                    quality: middleQuality,
                    embedThumbnail: embedThumbnail,
                    jpegUTType: jpegUTType
                )
                updateBestJPEGResult(candidate: middleResult, targetFileSize: targetFileSize, bestResult: &bestResult, bestDistance: &bestDistance)
                
                if middleResult.data.count == targetFileSize {
                    return middleResult
                }
                
                if middleResult.data.count < targetFileSize {
                    lowerQuality = middleQuality
                    lowerSize = middleResult.data.count
                } else {
                    upperQuality = middleQuality
                    upperSize = middleResult.data.count
                }
                
                if lowerSize == upperSize {
                    break
                }
            }
        }
        
        if let bestResult {
            return bestResult
        }
        
        throw NSError(domain: "LivePhotoAddressFetcher", code: -3)
    }
    
    private func encodeJPEGData(
        image: CGImage,
        metadata: CGImageMetadata?,
        baseProperties: [CFString: Any],
        quality: Double,
        embedThumbnail: Bool,
        jpegUTType: CFString
    ) throws -> (data: Data, quality: Double, embedThumbnail: Bool) {
        let mutableData = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(mutableData, jpegUTType, 1, nil) else {
            throw NSError(domain: "LivePhotoAddressFetcher", code: -4)
        }
        
        var properties = baseProperties
        properties[kCGImageDestinationLossyCompressionQuality] = quality
        properties[kCGImageDestinationEmbedThumbnail] = embedThumbnail
        
        if let metadata {
            CGImageDestinationAddImageAndMetadata(destination, image, metadata, properties as CFDictionary)
        } else {
            CGImageDestinationAddImage(destination, image, properties as CFDictionary)
        }
        
        guard CGImageDestinationFinalize(destination) else {
            throw NSError(domain: "LivePhotoAddressFetcher", code: -5)
        }
        
        return (mutableData as Data, quality, embedThumbnail)
    }
    
    private func updateBestJPEGResult(
        candidate: (data: Data, quality: Double, embedThumbnail: Bool),
        targetFileSize: Int,
        bestResult: inout (data: Data, quality: Double, embedThumbnail: Bool)?,
        bestDistance: inout Int
    ) {
        let distance = targetFileSize > 0 ? abs(candidate.data.count - targetFileSize) : candidate.data.count
        guard distance < bestDistance else {
            return
        }
        
        bestDistance = distance
        bestResult = candidate
    }
    
    private func sanitizedJPEGProperties(from sourceProperties: [CFString: Any]) -> [CFString: Any] {
        let keysToPreserve: [CFString] = [
            kCGImagePropertyExifDictionary,
            kCGImagePropertyExifAuxDictionary,
            kCGImagePropertyTIFFDictionary,
            kCGImagePropertyJFIFDictionary,
            kCGImagePropertyGPSDictionary,
            kCGImagePropertyIPTCDictionary,
            kCGImageProperty8BIMDictionary,
            kCGImagePropertyOrientation,
            kCGImagePropertyDPIWidth,
            kCGImagePropertyDPIHeight,
            kCGImagePropertyColorModel,
            kCGImagePropertyProfileName,
            kCGImagePropertyMakerCanonDictionary,
            kCGImagePropertyMakerNikonDictionary,
            kCGImagePropertyMakerMinoltaDictionary,
            kCGImagePropertyMakerFujiDictionary,
            kCGImagePropertyMakerOlympusDictionary,
            kCGImagePropertyMakerPentaxDictionary,
            kCGImagePropertyMakerAppleDictionary
        ]
        
        var metadata: [CFString: Any] = [:]
        for key in keysToPreserve {
            if let value = sourceProperties[key] {
                metadata[key] = value
            }
        }
        return metadata
    }
    
    private func makeJPEGCompatibleCGImage(from image: NSImage) -> CGImage? {
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return nil
        }
        
        let isWideGamut = isHDRImage(image: image)
        guard isWideGamut else {
            return cgImage
        }
        
        // HDR / 广色域图先压到 JPEG 兼容的 8-bit sRGB，避免直接写出异常色彩。
        guard let sRGBColorSpace = CGColorSpace(name: CGColorSpace.sRGB),
              let context = CGContext(
                data: nil,
                width: cgImage.width,
                height: cgImage.height,
                bitsPerComponent: 8,
                bytesPerRow: 0,
                space: sRGBColorSpace,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
              ) else {
            return cgImage
        }
        
        context.interpolationQuality = .high
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: cgImage.width, height: cgImage.height))
        return context.makeImage() ?? cgImage
    }
    
    private func logImageMetadataSummary(at url: URL, label: String) {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, [kCGImageSourceShouldCache: false] as CFDictionary),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any] else {
            ShareAPI.shared().log(1, "[EXIF] \(label) metadata读取失败 path=\(url.path)")
            return
        }
        
        let exif = properties[kCGImagePropertyExifDictionary] as? [CFString: Any]
        let tiff = properties[kCGImagePropertyTIFFDictionary] as? [CFString: Any]
        let gps = properties[kCGImagePropertyGPSDictionary] as? [CFString: Any]
        let dateTimeOriginal = (exif?[kCGImagePropertyExifDateTimeOriginal] as? String) ?? ""
        let dateTimeDigitized = (exif?[kCGImagePropertyExifDateTimeDigitized] as? String) ?? ""
        let tiffDateTime = (tiff?[kCGImagePropertyTIFFDateTime] as? String) ?? ""
        let uti = (CGImageSourceGetType(source) as String?) ?? ""
        let width = properties[kCGImagePropertyPixelWidth] as? Int ?? 0
        let height = properties[kCGImagePropertyPixelHeight] as? Int ?? 0
        let orientation = properties[kCGImagePropertyOrientation] as? Int ?? -1
        let profileName = (properties[kCGImagePropertyProfileName] as? String) ?? ""
        let pixelFormat = (properties[kCGImagePropertyPixelFormat] as? String) ?? ""
        let hasGPS = gps != nil && !(gps?.isEmpty ?? true)
        let metadata = CGImageSourceCopyMetadataAtIndex(source, 0, nil)
        let metadataTagCountValue = metadata.map { self.metadataTagCount(of: $0) } ?? 0
        let fileSize = (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
        let topLevelKeys = properties.keys.compactMap { $0 as String }.sorted().joined(separator: ",")
        
        ShareAPI.shared().log(
            1,
            """
            [EXIF] \(label) path=\(url.path)
            uti=\(uti) fileBytes=\(fileSize) size=\(width)x\(height) orientation=\(orientation)
            dateTimeOriginal=\(dateTimeOriginal.isEmpty ? "<empty>" : dateTimeOriginal)
            dateTimeDigitized=\(dateTimeDigitized.isEmpty ? "<empty>" : dateTimeDigitized)
            tiffDateTime=\(tiffDateTime.isEmpty ? "<empty>" : tiffDateTime)
            hasGPS=\(hasGPS) profileName=\(profileName.isEmpty ? "<empty>" : profileName)
            pixelFormat=\(pixelFormat.isEmpty ? "<empty>" : pixelFormat)
            metadataTagCount=\(metadataTagCountValue)
            topLevelKeys=\(topLevelKeys.isEmpty ? "<empty>" : topLevelKeys)
            """
        )
    }
    
    private func metadataTagCount(of metadata: CGImageMetadata) -> Int {
        var count = 0
        CGImageMetadataEnumerateTagsUsingBlock(
            metadata,
            nil,
            [kCGImageMetadataEnumerateRecursively: true] as CFDictionary
        ) { _, _ in
            count += 1
            return true
        }
        return count
    }
    
    func isHDRImage(image: NSImage) -> Bool {
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil),
              let colorSpace = cgImage.colorSpace else {
            return false
        }
        
        // 1. 检查位深度（HDR关键指标）
        let bitsPerComponent = cgImage.bitsPerComponent
        if bitsPerComponent > 8 { // HDR通常需要10+位
            print("✅ 高位深图像: \(bitsPerComponent)位/通道")
            return true
        }
        
        // 2. 检查颜色空间（扩展范围）
        let hdrColorSpaceNames: [CFString] = [
            CGColorSpace.displayP3,
            CGColorSpace.extendedLinearSRGB,
            CGColorSpace.extendedSRGB,
            // Rec.2020 - HDR常用色彩空间
            "ITUR_2020" as CFString,
            "ITUR_2100_PQ" as CFString,
            "ITUR_2100_HLG" as CFString
        ].compactMap { $0 }
        
        
        let colorSpaceName = (colorSpace.name as String?) ?? ""
        for hdrSpace in hdrColorSpaceNames {
            if colorSpaceName.contains(hdrSpace as String) {
                print("✅ HDR色彩空间: \(colorSpaceName)")
                return true
            }
        }
        
        // 3. 检查像素格式（浮点组件）
        let bitmapInfo = cgImage.bitmapInfo
        let hasFloatComponents = bitmapInfo.contains(.floatComponents)
        let isFloat = bitmapInfo.rawValue & CGBitmapInfo.floatComponents.rawValue != 0
        
        if hasFloatComponents || isFloat {
            print("✅ 浮点像素格式")
            return true
        }
        
        return false
    }
    func getImageData(for image: NSImage?) -> Data? {
        if let pngData = image?.pngData() {
            return pngData
        }else if let jpegData = image?.jpegData(compressionQuality: 1) {
            return jpegData
        }
        return nil
    }
    /// 同步获取 NSImage（会阻塞线程）
    func getImageSync(from asset: PHAsset, targetSize: CGSize = PHImageManagerMaximumSize) -> NSImage? {
        
        // 警告：这会阻塞当前线程！
        assert(!Thread.isMainThread, "不要在 UI 主线程调用同步方法！")
        
        var resultImage: NSImage?
        let semaphore = DispatchSemaphore(value: 0)
        
        let options = PHImageRequestOptions()
        options.isSynchronous = false  // 必须为 false
        options.deliveryMode = .highQualityFormat
        options.isNetworkAccessAllowed = true
        PHImageManager.default().requestImage(
            for: asset,
            targetSize: targetSize,
            contentMode: .aspectFit,
            options: options
        ) { image, info in
            resultImage = image
            semaphore.signal()
        }
        
        _ = semaphore.wait(timeout: .now() + 30.0)
        return resultImage
    }
        /// 同步判断是否为 HDR 图片（在主线程之外使用）
        static func isHDRAssetSync(_ asset: PHAsset) -> Bool {
            assert(!Thread.isMainThread, "不要在 UI 主线程调用同步方法！")
            
            var isHDR = false
            let semaphore = DispatchSemaphore(value: 0)
            
            // 使用异步方法，但同步等待结果
            isHDRAssetAsync(asset) { result in
                isHDR = result
                semaphore.signal()
            }
            
            _ = semaphore.wait(timeout: .now() + 5.0)
            return isHDR
        }
        
        /// 异步判断是否为 HDR 图片
        static func isHDRAssetAsync(_ asset: PHAsset, completion: @escaping (Bool) -> Void) {
            // 第一步：快速检查
            if quickCheckIsHDRAsset(asset) {
                completion(true)
                return
            }
            
            // 第二步：详细分析
            fetchAndAnalyzeAsset(asset, completion: completion)
        }
        
        /// 快速检查（不加载图片数据）
        private static func quickCheckIsHDRAsset(_ asset: PHAsset) -> Bool {
            print("=== 快速检查 HDR ===")
            
            // 1. 检查 mediaSubtypes（虽然不准确，但可作为参考）
            let hasPhotoHDRSubtype = asset.mediaSubtypes.contains(.photoHDR)
            print("mediaSubtypes 包含 .photoHDR: \(hasPhotoHDRSubtype)")
            
            // 2. 检查文件名（最可靠的快速判断）
            if let filename = asset.value(forKey: "filename") as? String {
                print("文件名: \(filename)")
                let lowerFilename = filename.lowercased()
                
                // HEIC/HEIF 格式很有可能是 HDR
                let isHEIC = lowerFilename.hasSuffix(".heic") || 
                            lowerFilename.hasSuffix(".heif") ||
                            lowerFilename.hasSuffix(".heics") ||
                            lowerFilename.hasSuffix(".heifs")
                print("是否为 HEIC/HEIF 格式: \(isHEIC)")
                
                // 文件名明确包含 HDR 关键词
                let hasHDRKeywords = lowerFilename.contains("hdr") ||
                                    lowerFilename.contains("p3") ||
                                    lowerFilename.contains("display") ||
                                    lowerFilename.contains("pro") ||
                                    lowerFilename.contains("raw")
                print("文件名包含 HDR 关键词: \(hasHDRKeywords)")
                
                if isHEIC || hasHDRKeywords {
                    print("✓ 快速检查确定是 HDR")
                    return true
                }
            }
            
            // 3. 检查图片尺寸（HDR 通常来自较新的高像素设备）
            let megaPixels = (asset.pixelWidth * asset.pixelHeight) / 1_000_000
            print("像素尺寸: \(asset.pixelWidth) × \(asset.pixelHeight) (\(megaPixels)MP)")
            
            let isFromModernDevice = megaPixels >= 8 // 800万像素以上
            print("是否来自现代设备: \(isFromModernDevice)")
            
            // 4. 检查创建时间（HDR 功能普及时间）
            if let creationDate = asset.creationDate {
                let hdrStartDate = Date(timeIntervalSince1970: 1577836800) // 2020-01-01
                let isRecentPhoto = creationDate > hdrStartDate
                print("是否为近期照片: \(isRecentPhoto)")
                
                // 如果同时满足现代设备和近期照片，可能是 HDR
                if isFromModernDevice && isRecentPhoto && hasPhotoHDRSubtype {
                    print("✓ 综合判断可能是 HDR")
                    return true
                }
            }
            
            print("✗ 快速检查未确定")
            return false
        }
        /// 获取并分析图片数据
        private static func fetchAndAnalyzeAsset(_ asset: PHAsset, completion: @escaping (Bool) -> Void) {
            let options = PHImageRequestOptions()
            options.isSynchronous = false
            options.version = .current
            options.deliveryMode = .fastFormat // 快速格式用于分析
            options.isNetworkAccessAllowed = false // 不下载iCloud
            options.resizeMode = .fast
            
            PHImageManager.default().requestImageDataAndOrientation(for: asset,options: options) { data, dataUTI, orientation, info in
                guard let data = data else {
                    print("无法获取图片数据")
                    completion(false)
                    return
                }
                
                let isHDR = analyzeImageDataForHDR(data, dataUTI: dataUTI)
                completion(isHDR)
            }
        }
        
        /// 分析图片数据是否为 HDR
        private static func analyzeImageDataForHDR(_ data: Data, dataUTI: String?) -> Bool {
            print("=== 详细分析图片数据 ===")
            
            guard let source = CGImageSourceCreateWithData(data as CFData, nil),
                  let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [String: Any] else {
                print("无法获取图片属性")
                return false
            }
            
            var hdrIndicators: [String: Bool] = [:]
            
            // 1. 检查 HEIC/HEIF 格式
            if let uti = dataUTI, uti.contains("heic") || uti.contains("heif") {
                print("UTI: \(uti)")
                
                if let heifProperties = properties["{HEIF}"] as? [String: Any] {
                    // iOS 16+/macOS 13+ 的 HDR 增益图
                    if let hasHDR = heifProperties["HasHDRGainMap"] as? Bool, hasHDR {
                        print("✓ 检测到 HEIC HDR 增益图")
                        hdrIndicators["HEIC_HDR"] = true
                        return true
                    }
                    
                    // 检查格式
                    if let format = heifProperties["Format"] as? String {
                        print("HEIC 格式: \(format)")
                        if format.contains("DolbyVision") || format.contains("HLG") || format.contains("HDR") {
                            print("✓ HEIC 格式包含 HDR 标志")
                            hdrIndicators["HEIC_Format"] = true
                            return true
                        }
                    }
                }
                
                // 仅凭 HEIC 格式就有较高概率是 HDR
                print("HEIC 格式可能是 HDR")
                hdrIndicators["Is_HEIC"] = true
            }
            
            // 2. 检查颜色空间
            if let colorModel = properties[kCGImagePropertyColorModel as String] as? String {
                print("颜色模型: \(colorModel)")
                
                if colorModel.contains("Display P3") || colorModel.contains("RGB") {
                    print("✓ 检测到 HDR 颜色空间")
                    hdrIndicators["Color_Space"] = true
                    return true
                }
            }
            
            // 3. 检查位深度
            if let depth = properties[kCGImagePropertyDepth as String] as? Int {
                print("位深度: \(depth)-bit")
                
                if depth > 8 {
                    print("✓ 检测到高位深 (>8-bit)")
                    hdrIndicators["High_Bit_Depth"] = true
                    return true
                }
            }
            
            // 4. 检查颜色配置文件
            if let profile = properties[kCGImagePropertyProfileName as String] as? String {
                print("颜色配置文件: \(profile)")
                
                if profile.contains("Display P3") || profile.contains("P3") || profile.contains("2020") {
                    print("✓ 检测到 HDR 颜色配置文件")
                    hdrIndicators["Color_Profile"] = true
                    return true
                }
            }
            
            // 5. 检查 EXIF 数据
            if let exif = properties[kCGImagePropertyExifDictionary as String] as? [String: Any] {
                // 自定义渲染模式
                if let customRendered = exif[kCGImagePropertyExifCustomRendered as String] as? Int {
                    print("EXIF 自定义渲染: \(customRendered)")
                    if customRendered == 2 || customRendered == 3 { // HDR 处理模式
                        print("✓ EXIF 显示为 HDR 处理")
                        hdrIndicators["EXIF_HDR"] = true
                        return true
                    }
                }
            }
            
            // 综合判断：如果有任意一个强指标，则认为是 HDR
            let strongIndicators = ["HEIC_HDR", "HEIC_Format", "Color_Space", "High_Bit_Depth"]
            let hasStrongIndicator = strongIndicators.contains { hdrIndicators[$0] == true }
            
            print("详细分析结果:")
            print("- 强指标数量: \(hdrIndicators.filter { strongIndicators.contains($0.key) }.count)")
            print("- 总指标数量: \(hdrIndicators.count)")
            print("- 是否为 HDR: \(hasStrongIndicator)")
            
            return hasStrongIndicator
        }
    
    
}
extension URL {
    /// 根据扩展名判断是否是图片文件
    var isImageFile: Bool {
        let imageExtensions: Set<String> = [
            "jpg", "jpeg", "png", "gif", "bmp", "tiff", "tif",
            "webp", "heic", "heif", "ico", "icns", "psd", "svg",
            "raw", "arw", "cr2", "nef", "orf", "sr2"
        ]
        return imageExtensions.contains(pathExtension.lowercased())
    }
    
    /// 根据扩展名获取图片类型
    var imageUTI: String? {
        let utiMapping: [String: String] = [
            "jpg": "public.jpeg",
            "jpeg": "public.jpeg",
            "png": "public.png",
            "gif": "public.gif",
            "bmp": "public.bmp",
            "tiff": "public.tiff",
            "tif": "public.tiff",
            "webp": "public.webp",
            "heic": "public.heic",
            "heif": "public.heif",
            "ico": "public.ico",
            "icns": "com.apple.icns",
            "svg": "public.svg-image"
        ]
        return utiMapping[pathExtension.lowercased()]
    }
}
extension NSImage {
    /// 判断图片在被系统升级色彩空间前是否为真正的HDR
    /// - Returns: 是否为原始HDR照片
    var isOriginalHDR: Bool {
        // 方法1：检查 CGImage 位深
        if let cgImage = self.cgImage(forProposedRect: nil, context: nil, hints: nil) {
            let bitsPerComponent = cgImage.bitsPerComponent
            // HDR图片通常使用16位深度，标准图片使用8位
            ShareAPI.shared().log(1, "HDR图片通常使用16位深度，标准图片使用8位\(bitsPerComponent)")
            if bitsPerComponent > 8 {
                return true
            }
        }
        return false
    }
    
    /// 获取图片的详细HDR信息
    /// - Returns: HDR信息字典
    var hdrInfo: [String: Any]? {
        // 使用 TIFF 数据而不是 PNG 数据，因为 TIFF 是 NSImage 的原生格式
        guard let tiffData = self.tiffRepresentation else { return nil }
        
        let options: [CFString: Any] = [
            kCGImageSourceShouldCache: false
        ]
        
        guard let imageSource = CGImageSourceCreateWithData(tiffData as CFData, options as CFDictionary) else {
            return nil
        }
        
        guard let properties = CGImageSourceCopyPropertiesAtIndex(imageSource, 0, nil) as? [CFString: Any] else {
            return nil
        }
        
        var info: [String: Any] = [:]
        
        // 检查位深
        if let depth = properties[kCGImagePropertyDepth] as? Int {
            info["bitDepth"] = depth
        }
        
        // 检查色彩空间
        if let colorModel = properties[kCGImagePropertyColorModel] as? String {
            info["colorModel"] = colorModel
        }
        
        // 检查色彩空间详情
        if let profileName = properties[kCGImagePropertyProfileName] as? String {
            info["profileName"] = profileName
        }
        
        // 检查像素宽度和高度
        if let width = properties[kCGImagePropertyPixelWidth] as? Int {
            info["width"] = width
        }
        
        if let height = properties[kCGImagePropertyPixelHeight] as? Int {
            info["height"] = height
        }
        
        // 检查DPI
        if let dpiWidth = properties[kCGImagePropertyDPIWidth] as? Double {
            info["dpiWidth"] = dpiWidth
        }
        
        if let dpiHeight = properties[kCGImagePropertyDPIHeight] as? Double {
            info["dpiHeight"] = dpiHeight
        }
        
        // 检查EXIF数据中的HDR标记
        if let exifData = properties[kCGImagePropertyExifDictionary] as? [CFString: Any] {
            info["exifData"] = exifData
        }
        
        // 检查TIFF数据
        if let tiffData = properties[kCGImagePropertyTIFFDictionary] as? [CFString: Any] {
            info["tiffData"] = tiffData
        }
        
        // 检查PNG数据（如果存在）
        if let pngData = properties[kCGImagePropertyPNGDictionary] as? [CFString: Any] {
            info["pngData"] = pngData
        }
        
        // 检查图片格式
        if let uti = CGImageSourceGetType(imageSource) {
            info["format"] = uti as String
        }
        
        // 检查是否是浮点格式（HDR特征）
        if let pixelFormat = properties[kCGImagePropertyPixelFormat] as? String {
            info["pixelFormat"] = pixelFormat
            info["isFloatingPoint"] = pixelFormat.contains("float") || pixelFormat.contains("Float")
        }
        // 检查是否有Alpha通道
        if let hasAlpha = properties[kCGImagePropertyHasAlpha] as? Bool {
            info["hasAlpha"] = hasAlpha
        }
        
        // 检查方向
        if let orientation = properties[kCGImagePropertyOrientation] as? Int {
            info["orientation"] = orientation
        }
        
        return info.isEmpty ? nil : info
    }
    func pngData() -> Data? {
        guard let cgImage = self.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return nil
        }
        
        // 先检查是否为 HDR 图片
        if isHDRImage(cgImage: cgImage) {
            // HDR 图片需要特殊处理
            return convertHDRToPNG(cgImage: cgImage)
        }
        
        // 普通图片直接转换
        let bitmapRep = NSBitmapImageRep(cgImage: cgImage)
        return bitmapRep.representation(using: .png, properties: [:])
    }
    
    private func isHDRImage(cgImage: CGImage) -> Bool {
        // 检查颜色空间
        if let colorSpace = cgImage.colorSpace {
            // 获取颜色空间名称
            if let colorSpaceName = colorSpace.name as String? {
                // Display P3 和广色域通常是 HDR
                if colorSpaceName.contains("DisplayP3") || 
                    colorSpaceName.contains("P3") ||
                    colorSpaceName.contains("Extended") {
                    return true
                }
            }
            
            // 检查是否是 Display P3 颜色空间
            if #available(macOS 10.11.2, *) {
                if colorSpace.name == CGColorSpace.displayP3 {
                    return true
                }
            }
            // 检查颜色空间模型
            if colorSpace.model == .rgb {
                // 检查颜色空间是否是广色域
                if colorSpace.numberOfComponents >= 3 {
                    // 获取颜色空间的 ICC 数据来判断
                    if let iccData = colorSpace.iccData {
                        // 这里可以添加更复杂的 ICC 配置文件分析
                        return true
                    }
                }
            }
        }
        
        // 检查位深度，HDR 通常是 10-bit 或更高
        if cgImage.bitsPerComponent > 8 {
            return true
        }
        
        return false
    }
}
extension NSImage {
    
    /// 转换 HDR 图片为 PNG
    private func convertHDRToPNG(cgImage: CGImage) -> Data? {
        // 1. 先转换为 sRGB 颜色空间
        guard let sRGBColorSpace = CGColorSpace(name: CGColorSpace.sRGB) else {
            return nil
        }
        
        // 2. 创建转换上下文
        let width = cgImage.width
        let height = cgImage.height
        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8, // PNG 通常使用 8-bit
            bytesPerRow: 0, // 自动计算
            space: sRGBColorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return nil
        }
        // 3. 设置高质量渲染
        context.interpolationQuality = .high
        
        // 4. 绘制并转换
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        
        guard let convertedCGImage = context.makeImage() else {
            return nil
        }
        
        // 5. 创建 PNG 数据
        let bitmapRep = NSBitmapImageRep(cgImage: convertedCGImage)
        return bitmapRep.representation(using: .png, properties: [:])
    }
    
    
    
    
}

import Foundation


class iCloudFileUtility {
    // MARK: - 判断是否是 iCloud 中的文件/文件夹
    func isiCloudItem(at url: URL) -> Bool {
        do {
            // 方法 1: 直接检查资源值（最可靠）
            let resourceValues = try url.resourceValues(forKeys: [.isUbiquitousItemKey])
            if let isUbiquitous = resourceValues.isUbiquitousItem, isUbiquitous {
                return true
            }
        } catch {
            // 如果获取失败，尝试备用方法
            return checkByPathPattern(url)
        }
        
        return false
    }
    // 备用方法：通过路径模式判断
    private func checkByPathPattern(_ url: URL) -> Bool {
        let path = url.path.lowercased()
        // iCloud 常见路径模式
        return path.contains("library/mobile documents/") ||
        path.contains("com~apple~clouddocs") ||
        path.contains("icloud drive")
    }
    // MARK: - 修正的判断是否有未下载文件（单文件）- 完全 macOS 兼容版
    func hasUndownloadedFile(at url: URL) -> Bool {
        guard isiCloudItem(at: url) else { return false }
        
        do {
            // 在 macOS 中可用的 keys
            let resourceValues = try url.resourceValues(forKeys: [
                .ubiquitousItemDownloadingStatusKey,  // 下载状态
                .fileSizeKey,                         // 文件大小
                .isRegularFileKey,                    // 是否是普通文件
                .contentAccessDateKey                 // 内容访问日期（可用于判断是否本地可用）
            ])
            
            print("🔍 检查下载状态: \(url.lastPathComponent)")
            
            // 1. 检查下载状态（macOS 主要方法）
            if let status = resourceValues.ubiquitousItemDownloadingStatus {
                print("📊 下载状态: \(status.rawValue)")
                
                // 明确的已下载状态
                if status == .downloaded || status == .current {
                    print("✅ 系统报告: 已下载或当前可用")
                    return false
                } 
                // 明确的未下载状态
                else if status == .notDownloaded {
                    print("⚠️ 系统报告: 未下载")
                    // 但需要验证文件是否真的不存在（有时状态会滞后）
                    return !checkFileActuallyExistsWithContent(url)
                }
                // 这里不需要 default 分支，因为我们已经处理了所有已知的 case
                // URLUbiquitousItemDownloadingStatus 只有三个值：
                // .notDownloaded, .downloaded, .current
            }
            
            // 2. 检查文件大小和类型
            if let fileSize = resourceValues.fileSize,
               let isRegularFile = resourceValues.isRegularFile,
               isRegularFile {
                
                print("📊 文件大小: \(fileSize) 字节")
                
                if fileSize > 1024 { // 大于1KB，可能是已下载文件
                    print("⚠️ 文件有大小 (\(fileSize) 字节)，但iCloud状态可能滞后")
                    // 验证文件内容
                    return !verifyFileContentLocally(url)
                } else if fileSize > 0 {
                    // 小文件，检查是否为有效文件
                    return !checkIfSmallFileIsValid(url)
                } else {
                    // 文件大小为0，很可能是占位符
                    print("❌ 文件大小为0，可能是占位符")
                    return true
                }
            }
            
            // 3. 检查内容访问日期（如果最近被访问过，可能是本地文件）
            if let accessDate = resourceValues.contentAccessDate {
                let timeSinceAccess = Date().timeIntervalSince(accessDate)
                print("📅 最后访问时间: \(timeSinceAccess) 秒前")
                
                // 如果最近被访问过（30分钟内），可能是本地文件
                if timeSinceAccess < 1800 { // 30分钟
                    print("⏰ 文件最近被访问过，可能是本地文件")
                    return !checkFileActuallyExistsWithContent(url)
                }
            }
            
            // 4. 使用 NSMetadataQuery 获取更准确的 iCloud 状态（可选）
            let metadataStatus = getICloudMetadataStatus(for: url)
            if let metadataStatus = metadataStatus {
                print("📡 NSMetadataQuery 状态: \(metadataStatus)")
                if metadataStatus == "downloaded" || metadataStatus == "current" {
                    return false
                }
            }
            
            // 5. 如果以上都无法确定，进行最终验证
            print("⚠️ iCloud状态不确定，进行最终验证...")
            return !performFinalAvailabilityCheckOnMac(url)
            
        } catch {
            print("⚠️ 检查下载状态失败，进行降级检查: \(error)")
            // 降级检查：直接检查文件是否存在且有内容
            return !checkFileActuallyExistsWithContent(url)
        }
    }
        
    /// 使用 NSMetadataQuery 获取文件的 iCloud 状态
    private func getICloudMetadataStatus(for url: URL) -> String? {
        let query = NSMetadataQuery()
        
        // 设置查询范围
        query.searchScopes = [NSMetadataQueryUbiquitousDocumentsScope]
        
        // 创建查询谓词
        let filename = url.lastPathComponent
        let predicate = NSPredicate(format: "%K == %@", 
                                    NSMetadataItemFSNameKey, 
                                    filename)
        query.predicate = predicate
        
        // 设置通知
        let notificationCenter = NotificationCenter.default
        var queryResult: String?
        let semaphore = DispatchSemaphore(value: 0)
        
        notificationCenter.addObserver(
            forName: .NSMetadataQueryDidFinishGathering,
            object: query,
            queue: .main
        ) { notification in
            query.stop()
            
            if let items = query.results as? [NSMetadataItem], 
                let item = items.first {
                
                // 获取下载状态
                if let status = item.value(forAttribute: NSMetadataUbiquitousItemDownloadingStatusKey) as? String {
                    queryResult = status
                }
            }
            
            semaphore.signal()
        }
        
        // 开始查询
        query.start()
        
        // 等待查询完成（最多2秒）
        let timeoutResult = semaphore.wait(timeout: .now() + 2.0)
        
        if timeoutResult == .timedOut {
            print("⏱️ NSMetadataQuery 查询超时")
            query.stop()
        }
        
        notificationCenter.removeObserver(query)
        
        return queryResult
    }
    
    // MARK: - 辅助方法
    /// 检查文件是否实际存在且有内容
    private func checkFileActuallyExistsWithContent(_ url: URL) -> Bool {
        let fileManager = FileManager.default
        
        // 1. 文件必须存在
        guard fileManager.fileExists(atPath: url.path) else {
            return false
        }
        
        do {
            // 2. 检查文件属性
            let attributes = try fileManager.attributesOfItem(atPath: url.path)
            
            // 3. 文件大小必须大于0
            guard let fileSize = attributes[.size] as? Int64, fileSize > 0 else {
                return false
            }
            
            // 4. 尝试读取少量数据验证文件可访问性
            if let fileHandle = try? FileHandle(forReadingFrom: url) {
                defer { try? fileHandle.close() }
                
                // 尝试读取前1024字节
                if #available(macOS 10.15.4, *) {
                    if let data = try? fileHandle.read(upToCount: 1024), !data.isEmpty {
                        print("✅ 文件包含 \(data.count) 字节数据")
                        return true
                    }
                } else {
                    // Fallback on earlier versions
                }
            }
            
            return false
            
        } catch {
            print("❌ 检查文件内容失败: \(error)")
            return false
        }
    }
    /// 验证文件本地内容
    private func verifyFileContentLocally(_ url: URL) -> Bool {
        return checkFileActuallyExistsWithContent(url)
    }
    /// 检查是否是有效的小文件
    private func checkIfSmallFileIsValid(_ url: URL) -> Bool {
        let fileExtension = url.pathExtension.lowercased()
        
        // 允许的小文件类型
        let allowedSmallFileExtensions = [
            "txt", "md", "json", "plist", "xml", "html", "css", "js",
            "csv", "ini", "cfg", "env", "log", "rtf"
        ]
        
        // 如果扩展名在允许列表中，认为是有效文件
        if allowedSmallFileExtensions.contains(fileExtension) {
            return true
        }
        
        // 其他类型的小文件，需要进一步验证
        return checkFileActuallyExistsWithContent(url)
    }
    
    /// macOS 专用的最终可用性检查
    private func performFinalAvailabilityCheckOnMac(_ url: URL) -> Bool {
        let fileManager = FileManager.default
        
        // 尝试获取文件属性
        do {
            let attributes = try fileManager.attributesOfItem(atPath: url.path)
            
            // 检查文件大小
            if let size = attributes[.size] as? Int64 {
                if size > 0 {
                    // 尝试直接打开文件验证
                    if verifyFileCanBeOpenedOnMac(url) {
                        print("✅ macOS验证: 文件可打开")
                        return true
                    }
                }
            }
        } catch {
            print("❌ macOS属性检查失败: \(error)")
        }
        
        return false
    }
    
    /// macOS 上验证文件是否可以打开
    private func verifyFileCanBeOpenedOnMac(_ url: URL) -> Bool {
        // 尝试以只读方式打开文件
        do {
            let fileHandle = try FileHandle(forReadingFrom: url)
            // 如果打开成功，立即关闭
            try fileHandle.close()
            return true
        } catch {
            print("❌ 文件无法打开: \(error)")
            return false
        }
    }    
    // - 判断文件夹中是否有未下载文件（递归检查）
    func hasUndownloadedFilesInFolder(at folderURL: URL) -> Bool {
        guard isiCloudItem(at: folderURL) else { return false }
        
        // 先检查文件夹本身是否未下载
        if hasUndownloadedFile(at: folderURL) {
            return true
        }
        
        // 检查文件夹内容
        return checkFolderContentsRecursively(folderURL)
    }
    private func checkFolderContentsRecursively(_ folderURL: URL) -> Bool {
        let fileManager = FileManager.default
        
        do {
            let contents = try fileManager.contentsOfDirectory(
                at: folderURL,
                includingPropertiesForKeys: [
                    .isDirectoryKey,
                    .isUbiquitousItemKey,
                    .ubiquitousItemDownloadingStatusKey
                ],
                options: .skipsHiddenFiles
            )
            
            for itemURL in contents {
                // 如果是 iCloud 项目
                if isiCloudItem(at: itemURL) {
                    // 检查当前项目是否未下载
                    if hasUndownloadedFile(at: itemURL) {
                        return true
                    }
                    
                    // 如果是文件夹，递归检查
                    var isDirectory: ObjCBool = false
                    if fileManager.fileExists(atPath: itemURL.path, isDirectory: &isDirectory),
                       isDirectory.boolValue {
                        if checkFolderContentsRecursively(itemURL) {
                            return true
                        }
                    }
                }
            }
        } catch {
            print("检查文件夹内容失败: \(error)")
        }
        
        return false
    }
    // - 一键检查方法
    func checkiCloudStatus(for url: URL) -> (isICloud: Bool, hasUndownloaded: Bool) {
        let isICloud = isiCloudItem(at: url)
        
        if !isICloud {
            return (false, false)
        }
        
        // 判断是文件还是文件夹
        var isDirectory: ObjCBool = false
        FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory)
        
        let hasUndownloaded = isDirectory.boolValue ? hasUndownloadedFilesInFolder(at: url) : hasUndownloadedFile(at: url)
        
        return (true, hasUndownloaded)
    }
    
    // MARK: 检查文件是否是本地可访问的
    /// 判断文件是否为照片库占位符或衍生文件（主要检查方法）
    static func isPhotoLibraryPlaceholder(at url: URL) -> Bool {
        print("🔍 检查文件: \(url.lastPathComponent)")
        let (isICloud, hasUndownloaded) = iCloudFileUtility().checkiCloudStatus(for: url)
        if isICloud {
            print("📍 iCloud 项目: \(url.lastPathComponent)")
            if hasUndownloaded {
                print("   ⚠️ 包含未下载内容")
                return true
            } else {
                print("   ✅ 已完全下载")
            }
        }
        
        // 1. 快速路径检查（最快排除）
        if isInternalPhotoLibraryFile(at: url) {
            print("❌ 路径特征: 位于照片库内部目录")
            return true
        }
        
        // 2. 文件属性检查
        let propertyCheck = checkFileProperties(at: url)
        if propertyCheck.isPlaceholder {
            print("❌ 文件属性: \(propertyCheck.reason)")
            return true
        }else{
            if propertyCheck.reason.contains(".folder") {
                return false
            }
        }
        
        let path = url.path.lowercased()
        // 关键检查：是否在照片库包内
        if path.contains(".photoslibrary") {
            // 3. 尝试加载验证（最终确认）
            let loadCheck = attemptToLoadImage(at: url)
            if !loadCheck.isValid {
                print("❌ 加载失败: \(loadCheck.reason)")
                return true
            }
        }else {
            return false
        }
        
        
        print("✅ 文件似乎是可用的原始图片")
        return false
    }
    /// 1. 路径特征检查 - 这是最快最直接的方法
    private static func isInternalPhotoLibraryFile(at url: URL) -> Bool {
        let path = url.path.lowercased()
        
        // 关键检查：是否在照片库包内
        guard path.contains(".photoslibrary") else {
            return false
        }
        
        // 检查是否在特定的内部目录中
        let internalDirectories = [
            "/resources/proxies/",      // 代理文件
            "/masters/",                // 主文件目录
            "/private/",                // 私有数据
            "/thumbnails/",             // 缩略图
            "/renders/",                // 渲染文件
            "/caches/"                  // 缓存
        ]
        
        return internalDirectories.contains { path.contains($0) }
    }
    /// 2. 文件属性检查
    private static func checkFileProperties(at url: URL) -> (isPlaceholder: Bool, reason: String) {
        do {
            let resourceValues = try url.resourceValues(forKeys: [
                .fileSizeKey,
                .typeIdentifierKey,
                .isRegularFileKey,
                .isSymbolicLinkKey
            ])
            
            // 检查文件大小（占位符通常很小）
            if let size = resourceValues.fileSize {
                if size == 0 {
                    return (true, "文件大小为0字节")
                } 
                // 检查文件扩展名，某些小文件是正常的
                let fileExtension = url.pathExtension.lowercased()
                let allowedSmallExtensions = [
                    "plist", "json", "txt", "rtf", "md", "xml",
                    "ini", "cfg", "conf", "properties", "env"
                ]
                
                // 小于512字节且不是允许的小文件类型
                if size < 1 && !allowedSmallExtensions.contains(fileExtension) {
                    return (true, "文件过小 (\(size) 字节)，且不是可接受的小文件类型")
                }
                print("📊 文件大小: \(size) 字节")
            }
            
            // 检查文件类型标识
            if let type = resourceValues.typeIdentifier {
                print("📄 文件类型: \(type)")
                
                // 系统明确标记的类型
                if type == "com.apple.photo.placeholder" {
                    return (true, "系统标识为照片占位符")
                }
                if type == "com.apple.icloud.file-icon" {
                    return (true, "iCloud占位符")
                }
                if type == "com.apple.directory" {
                    return (true, "这是一个目录而非文件")
                }
                if type == "public.folder" {
                    return (false, type)
                }
            }
            
            // 检查是否为符号链接
            if let isSymbolicLink = resourceValues.isSymbolicLink, isSymbolicLink {
                if let destination = try? FileManager.default.destinationOfSymbolicLink(atPath: url.path) {
                    return (true, "符号链接，指向: \(destination)")
                }
                return (true, "这是一个符号链接")
            }
            
            return (false, "文件属性正常")
            
        } catch {
            // 如果无法读取属性，很可能是受保护文件
            return (true, "无法读取文件属性: \(error.localizedDescription)")
        }
    }
    /// 3. 尝试加载图像数据
    private static func attemptToLoadImage(at url: URL) -> (isValid: Bool, reason: String, image: NSImage?) {
        // 首先检查文件是否是图片格式
        let pathExtension = url.pathExtension.lowercased()
        let imageExtensions = ["jpg", "jpeg", "png", "gif", "bmp", "tiff", "tif", "heic", "webp"]
        
        guard imageExtensions.contains(pathExtension) else {
            return (true, "非图片格式 (\(pathExtension))", nil)
        }
        // 尝试直接加载图片
        guard let image = NSImage(contentsOf: url) else {
            return (false, "无法加载图片数据", nil)
        }
        
        // 检查图片是否有效
        guard image.isValid else {
            return (false, "图片对象无效", image)
        }
        
        // 检查图片尺寸（预览图标通常很小）
        let size = image.size
        print("📐 图片尺寸: \(Int(size.width))×\(Int(size.height)) 像素")
        
        if size.width < 50 || size.height < 50 {
            return (false, "尺寸过小，可能只是预览图标", image)
        }
        
        // 尝试获取图像数据
        guard let tiffData = image.tiffRepresentation else {
            return (false, "无法生成TIFF数据", image)
        }
        
        guard let bitmapRep = NSBitmapImageRep(data: tiffData) else {
            return (false, "无法创建位图表示", image)
        }
        
        // 检查实际数据大小
        let actualSize = bitmapRep.size
        print("🎯 实际位图尺寸: \(Int(actualSize.width))×\(Int(actualSize.height))")
        
        return (true, "成功加载有效图片", image)
    }
}


class AppVersionChecker {
    // 从 App Store Connect 获取你的 App ID
//    private let appId: String = ""
//    private let currentVersion: String
    
//    init(appId: String) {
//        self.appId = appId
//        self.currentVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
//    }
    
    func getLatestVersionFromAppStore(appID: String, completion: @escaping (String?) -> Void) {
        guard let url = URL(string: "https://itunes.apple.com/lookup?id=\(appID)&entity=desktopSoftware&country=cn") else {
            completion(nil)
            return
        }
        
        URLSession.shared.dataTask(with: url) { data, _, error in
            guard let data = data, error == nil else {
                completion(nil)
                return
            }
            
            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let results = json["results"] as? [[String: Any]],
                   let firstApp = results.first,
                   let version = firstApp["version"] as? String {
                    DispatchQueue.main.async {
                        completion(version)
                    }
                } else {
                    DispatchQueue.main.async {
                        completion(nil)
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    completion(nil)
                }
            }
        }.resume()
    }   
    
    func chechVersion(nowVer:String,newVer:String) -> Bool{
        let currentParts = nowVer.split(separator: ".").compactMap { Int($0) }
        let storeParts = newVer.split(separator: ".").compactMap { Int($0) }
        
        let maxLength = max(currentParts.count, storeParts.count)
        
        for i in 0..<maxLength {
            let currentNum = i < currentParts.count ? currentParts[i] : 0
            let storeNum = i < storeParts.count ? storeParts[i] : 0
            
            if storeNum > currentNum {
                return true
            } else if storeNum < currentNum {
                return false
            }
        }
        return false
    }

}
