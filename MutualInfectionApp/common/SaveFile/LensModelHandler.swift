//
//  LensModelHandler.swift
//  MutualInfection
//
//  Created by mac on 2025/11/3.
//
import ImageIO
#if MAIN_APP || SHARE_EXTENSION
import MobileCoreServices
#endif

class LensModelHandler: NSObject  {
    
    //新镜头信息获取（拼接其他信息生成LensModel）
    static func getNewLensModel(from imageURL: URL) -> String {
        guard imageURL.isFileURL else {
            ShareAPI.shared().log(3, "[SaveFile] [PhotoSaver] 提供的不是本地文件")
            return ""
        }
        
        guard let imageSource = CGImageSourceCreateWithURL(imageURL as CFURL, nil) else {
            ShareAPI.shared().log(3, "[SaveFile] [PhotoSaver] 无法创建图像源。")
            return ""
        }
        
        guard let imageProperties = CGImageSourceCopyPropertiesAtIndex(imageSource, 0, nil) as? [CFString: Any] else {
            ShareAPI.shared().log(3, "[SaveFile] [PhotoSaver] 无法读取图像的属性字典。")
            return ""
        }
        var cameraPosition = ""
        var focalLength: Double?
        var apertureValue: Double?
        if let exifDict = imageProperties[kCGImagePropertyExifDictionary] as? [CFString: Any] {
            let lensModel = exifDict[kCGImagePropertyExifLensModel] as? String
            ShareAPI.shared().log(1, "[SaveFile] [PhotoSaver] [exifDict] [tiffDict] key: LensModel, vlaue: \(String(describing: lensModel))")
            // 已存在镜头信息不需要拼接
            if lensModel != nil, lensModel != "" {
                return ""
            }
            focalLength = exifDict[kCGImagePropertyExifFocalLength] as? Double
            ShareAPI.shared().log(1, "[SaveFile] [PhotoSaver] [exifDict] [tiffDict] key: FocalLength, vlaue: \(String(focalLength ?? 0.0))")
            apertureValue = exifDict[kCGImagePropertyExifFNumber] as? Double
            ShareAPI.shared().log(1, "[SaveFile] [PhotoSaver] [exifDict] [tiffDict] key: FocalLength, vlaue: \(String(apertureValue ?? 0.0))")
            cameraPosition = "camera"
        } else {
            ShareAPI.shared().log(3, "[SaveFile] [PhotoSaver] 未找到镜头信息")
            return ""
        }
        var model = ""
        if let tiffDict = imageProperties[kCGImagePropertyTIFFDictionary] as? [CFString: Any] {
            model = tiffDict[kCGImagePropertyTIFFModel] as? String ?? ""
            ShareAPI.shared().log(1, "[SaveFile] [PhotoSaver] [exifDict] [tiffDict] key: Model, vlaue: \(model)")
        }
        if model != "", focalLength != 0.0,apertureValue != 0.0 {
            let lensModel = "\(model) \(cameraPosition) \(String(focalLength ?? 0.0))mm f/\(String(apertureValue ?? 0.0))"
            ShareAPI.shared().log(1, "[SaveFile] [PhotoSaver] [exifDict] new LensModel\(String(lensModel))")
            return lensModel
        } else {
            return ""
        }
    }
    
    // 获取临时路径
    static func getLensModelTempDri(_ dri: String) -> String {
        let docDir = FileManager.default.urls(for: .documentDirectory,
                                               in: .userDomainMask).first!
        let tempDir = docDir.appendingPathComponent("temp", isDirectory: true)
        let dirPath = "\(tempDir.path)/\(dri)"
        if !FileManager.default.fileExists(atPath: dirPath) {
            do {
                try FileManager.default.createDirectory(at: URL(fileURLWithPath: dirPath), withIntermediateDirectories: true)
                ShareAPI.shared().log(1, "[SaveFile] [LensModelHandler] 临时文件子目录创建成功:\(dirPath)");
            } catch {
                ShareAPI.shared().log(3, "[SaveFile] [LensModelHandler] 创建临时文件子目录失败:\(error.localizedDescription)")
            }
        }
        return dirPath
    }
    
    // 转换图片
    static func writeLensModelToImage(sourceImageURL: URL, destinationImageURL: URL, lensModel: String) -> Bool {
        guard let imageSource = CGImageSourceCreateWithURL(sourceImageURL as CFURL, nil) else {
            ShareAPI.shared().log(3, "[SaveFile] [PhotoSaver] 无法创建图像源。")
            return false
        }
        
        guard let imageProperties = CGImageSourceCopyPropertiesAtIndex(imageSource, 0, nil) as? [CFString: Any] else {
            ShareAPI.shared().log(3, "[SaveFile] [PhotoSaver] 无法读取图像的属性字典。")
            return false
        }
        
        var mutableProperties = imageProperties
        var exifDictionary = mutableProperties[kCGImagePropertyExifDictionary] as? [CFString: Any] ?? [:]
        
        exifDictionary[kCGImagePropertyExifLensModel] = lensModel
        mutableProperties[kCGImagePropertyExifDictionary] = exifDictionary
        
        guard let imageDestination = CGImageDestinationCreateWithURL(destinationImageURL as CFURL, kUTTypeJPEG, 1, nil) else {
            ShareAPI.shared().log(3, "[SaveFile] [PhotoSaver] 创建照片写入资源")
            return false
        }
        
        CGImageDestinationAddImageFromSource(imageDestination, imageSource, 0, mutableProperties as CFDictionary)
        
        if CGImageDestinationFinalize(imageDestination) {
            ShareAPI.shared().log(1, "[SaveFile] [PhotoSaver] 生成图片成功")
            return true
        } else {
            ShareAPI.shared().log(3, "[SaveFile] [PhotoSaver] 生成图片失败")
            return false
        }
        
//        try? FileManager.default.copyItem(atPath: sourceImageURL.path, toPath: destinationImageURL.path)
//        let success = TranscodeMediaOC.sharedInstance().addMetadata(withParent: destinationPath.path, parentKey: "Exif", metadata: ["LensModel" : lensModel])
//        return success
    }
    
    /// 判断图片类型
    static func checkImageIsJpgHeicType(imageURL: URL) -> Bool {
        let imageTypeArr = ["jpg", "jpeg", "heic"]
        let fileExtension = (imageURL.absoluteString as NSString).pathExtension.lowercased()
        return imageTypeArr.contains(fileExtension)
    }
}
