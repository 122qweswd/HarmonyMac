//
//  VideoSaver.swift
//  MutualInfection
//
//  Created by mac on 2025/9/26.
//

import Photos

class VideoSaver: NSObject {
    
    // 批量保存视频到图库中
    static func saveVideosToAlbum(_ paths: [(String, String, String)], completion: @escaping (Bool, Error?, [String: String]?) -> Void) {
        
        // 1. 同步检查权限（如果已授权）
        if !SaveFileHandler.shared.photoLibraryAuthorized() && !SaveFileHandler.shared.photoLibraryAdd() {
            DispatchQueue.main.async {
                completion(false, NSError(domain: "NoPermission", code: 403, userInfo: nil), nil)
            }
            return
        }
        var localIdentifiers = [String: String]()
        
        let timeInfos = SaveFileHandler.shared.getTimeInfo(paths)
        // 首先获取或创建目标相册
        AlbumSaver.getOrCreateAlbum(albumName: fileRootDirectoryName) { assetCollection, error in
            guard let album = assetCollection, error == nil else {
                completion(false, error, localIdentifiers)
                return
            }
            autoreleasepool{
                PHPhotoLibrary.shared().performChanges({
                    var createdAssets: [PHObjectPlaceholder] = []
                    // 批量处理URL
                    for (fileName, _, path) in paths {
                        let reFileName = FileSaver.getListTwoComponents(from: path) ?? ""
                        //时间信息
                        let timeInfo = timeInfos[reFileName] ?? (SaveFileHandler.shared.NO_TIME_MS, SaveFileHandler.shared.NO_TIME_MS, SaveFileHandler.shared.NO_TIME_STR)
                        let hDate = SaveFileHandler.shared.getTimeInfo(timeInfo)
                        let url = URL(fileURLWithPath: path)
                        let request = PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: url)
                        // 时间设置(存在时间)
                        if let date = hDate {
                            request?.creationDate = date
                        }
#if os(iOS)
                        // 可在注释中存储原始文件名
                        request?.accessibilityLabel = fileName
#endif
                        // 存储placeholder与原始路径的映射
                        if let placeholder = request?.placeholderForCreatedAsset {
                            createdAssets.append(placeholder)
                            localIdentifiers[path] = placeholder.localIdentifier
                        } else {
                            localIdentifiers[path] = ""
                        }
                        ShareAPI.shared().log(1, "[SaveFile] [SaveFileHandler] 正在落盘文件：\(path)")
                    }
                    
                    // 将创建的资产添加到目标相册
                    if let albumChangeRequest = PHAssetCollectionChangeRequest(for: album) {
                        albumChangeRequest.addAssets(createdAssets as NSArray)
                    }
                }){ success, error in
                    completion(success, error, localIdentifiers)
                }
            }
        }
    }
}
