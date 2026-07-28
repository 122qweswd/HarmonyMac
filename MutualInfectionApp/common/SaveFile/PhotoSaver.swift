//
//  PhotoSaver.swift
//  MutualInfection
//
//  Created by mac on 2025/9/26.
//
import ImageIO
import Photos

class PhotoSaver: NSObject {
    private static var completion: ((Bool, Error?) -> Void)?
    
    /// 解析HEIF文件的元数据
    static func parseHEIFMetadata(fileURL: URL) -> [String: Any]? {
        // 1. 创建图像源（CGImageSource）
        guard let imageSource = CGImageSourceCreateWithURL(fileURL as CFURL, nil) else {
            ShareAPI.shared().log(3, "[SaveFile] [PhotoSaver] 无法创建HEIF图像源")
            return nil
        }

        // 2. 获取主图像（索引0）的元数据
        // 注意：HEIF可能包含多帧（如Live Photo），索引0通常是主图像
        guard let metadataDict = CGImageSourceCopyMetadataAtIndex(imageSource, 0, nil as CFDictionary?)  as? [String: Any]  else {
            ShareAPI.shared().log(3, "[SaveFile] [PhotoSaver] HEIF文件无元数据")
            return nil
        }

        return metadataDict
    }
    
    //设置 镜头信息
    static func setLensModel(_ paths: [(String, String, String)], _ tempDri: String) -> [(String, String, String)] {
        var tempPahts: [(String, String, String)] = []
        for (fileName, type, tempPath) in paths {
            //手动补充lensModel（镜头信息）
            let lensModel = LensModelHandler.getNewLensModel(from: URL(fileURLWithPath: tempPath))
            var path = tempPath
            if lensModel != "" {
                let dir = LensModelHandler.getLensModelTempDri(tempDri)
                let fileName = (tempPath as NSString).lastPathComponent
                path = "\(dir)/\(fileName)"
                let success = LensModelHandler.writeLensModelToImage(sourceImageURL: URL(fileURLWithPath: tempPath), destinationImageURL: URL(fileURLWithPath: path), lensModel: lensModel)
                //不成功使用原路径下的文件
                if !success {
                    path = tempPath
                }
            }
            tempPahts.append((fileName, type, path))
        }
        return tempPahts
    }
        
    // 保存到相册（批量）
    static func savePhotosToAlbum(_ tempPaths: [(String, String, String)],  completion: @escaping (Bool, Error?, [String: String]?) -> Void) {
        
        // 1. 同步检查权限（如果已授权）
        if !SaveFileHandler.shared.photoLibraryAuthorized() && 
            !SaveFileHandler.shared.photoLibraryAdd() {
            DispatchQueue.main.async {
                completion(false, NSError(domain: "NoPermission", code: 403, userInfo: nil), nil)
            }
            return
        }
        

        var localIdentifiers = [String: String]()
        let tempDri = "\(UUID().uuidString)"
        //注释掉镜头型号兜底逻辑（暂时处理不了经过镜头型号转换造成的照片大小变小的问题）
        let paths = self.setLensModel(tempPaths, tempDri)
//        let paths = tempPaths
        
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
                    for (index, (fileName, _, path)) in paths.enumerated() {
                        let ext = (path as NSString).pathExtension.lowercased()
                        let reFileName = FileSaver.getListTwoComponents(from: path) ?? ""
                        //时间信息
                        let timeInfo = timeInfos[reFileName] ?? (SaveFileHandler.shared.NO_TIME_MS, SaveFileHandler.shared.NO_TIME_MS, SaveFileHandler.shared.NO_TIME_STR)
                        let hDate = SaveFileHandler.shared.getTimeInfo(timeInfo)
                        //动图单独处理
                        if ext == "gif" || ext == "webp" || ext == "heif" || ext == "mpo‌" || ext == "heic"  {
                            // 1. 读取GIF文件的原始二进制数据
                            guard let gifData = try? Data(contentsOf: URL(fileURLWithPath: path)) else {
                                ShareAPI.shared().log(3, "[SaveFile] [PhotoSaver] 解析动态图片数据失败：\(path)")
                                continue
                            }
                            // 2. 创建资产请求（使用PHAssetCreationRequest，而非从图片文件创建）
                            let creationRequest = PHAssetCreationRequest.forAsset()
                            // 3. 直接添加GIF原始数据作为资源（关键：保留动态信息）
                            creationRequest.addResource(with: .photo, data: gifData, options: nil)
#if os(iOS)
                            // 可在注释中存储原始文件名
                            creationRequest.accessibilityLabel = fileName
#endif
                            // 时间设置(存在时间)
                            if let date = hDate {
                                creationRequest.creationDate = date
                            }
                            // 存储placeholder与原始路径的映射
                            if let placeholder = creationRequest.placeholderForCreatedAsset {
                                createdAssets.append(placeholder)
                                localIdentifiers[tempPaths[index].2] = placeholder.localIdentifier
                            } else {
                                localIdentifiers[tempPaths[index].2] = ""
                            }
                            ShareAPI.shared().log(1, "[SaveFile] [PhotoSaver] gif正在落盘文件：\(path)")
                        } else {
                            let request = PHAssetChangeRequest.creationRequestForAssetFromImage(atFileURL: URL(fileURLWithPath: path))
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
                                localIdentifiers[tempPaths[index].2] = placeholder.localIdentifier
                            } else {
                                localIdentifiers[tempPaths[index].2] = ""
                            }
                            ShareAPI.shared().log(1, "[SaveFile] [PhotoSaver] 正在落盘文件：\(path)")
                        }
                        
                        // 将创建的资产添加到目标相册
                        if let albumChangeRequest = PHAssetCollectionChangeRequest(for: album) {
                            albumChangeRequest.addAssets(createdAssets as NSArray)
                        }
                    }
                }){ success, error in
                    //删除文件夹
                    FileSaver.deleteFolder(LensModelHandler.getLensModelTempDri(tempDri))
                    completion(success, error, localIdentifiers)
                }
            }
        }
    }
}
