//
//  LivePhotoToolTransManager.swift
//  FrameProduct
//
//  Created by delegate on 2025/9/11.
//

import Foundation
#if MAIN_APP || SHARE_EXTENSION
import MobileCoreServices
#endif
import ImageIO
import AVFoundation
import Photos

/// 媒体文件处理工具类，封装JPEG和MOV文件的元数据操作
final class LivePhotoToolTransManager {
    
    // MARK: - JPEG相关操作
    
    /// 读取JPEG文件的Asset Identifier
    static func readJPEGAssetIdentifier(from path: String) -> String? {
        return ImageMetaclassDataTool(path: path).read()
    }
    
    /// 写入Asset Identifier到JPEG文件
    static func writeJPEGAssetIdentifier(from sourcePath: String, to destPath: String, assetIdentifier: String) {
        let jpeg = ImageMetaclassDataTool(path: sourcePath)
        jpeg.write(destPath, assetIdentifier: assetIdentifier)
    }
    
    // MARK: - MOV相关操作
    
    /// 读取MOV文件的Asset Identifier
    static func readMOVAssetIdentifier(from path: String) -> String? {
        return VideoMetaclassDataTool(path: path).readAssetIdentifier()
    }
    
    /// 读取MOV文件的静帧时间
    static func readMOVStillImageTime(from path: String) -> NSNumber? {
        return VideoMetaclassDataTool(path: path).readStillImageTime()
    }
    
    /// 写入Asset Identifier到MOV文件
//    static func writeMOVAssetIdentifier(from sourcePath: String, to destPath: String, assetIdentifier: String) {
//        let mov = VideoMetaclassDataTool(path: sourcePath)
//        mov.write(destPath, assetIdentifier: assetIdentifier)
//    }
    static func writeMOVAssetIdentifier(from sourcePath: String, to destPath: String, assetIdentifier: String, completion: @escaping (Bool) -> Void) {
            let mov = VideoMetaclassDataTool(path: sourcePath)
            mov.writeWithCompatibility(dest: destPath, assetIdentifier: assetIdentifier, completion: completion)
        }
    
    /// 生成实况图
    static func generateLivePhoto(videoURL: URL, imageURL: URL, completion: @escaping (Result<PHLivePhoto, Error>) -> Void) {
        PHLivePhoto.request(withResourceFileURLs: [videoURL, imageURL],
                            placeholderImage: nil,
                            targetSize: .zero,
                            contentMode: PHImageContentMode.aspectFit,
                            resultHandler: { (livePhoto, info) -> Void in
            let isDegraded = info[PHLivePhotoInfoIsDegradedKey] as? Bool ?? false
            if !isDegraded {
                if let livePhoto = livePhoto {
                    completion(.success(livePhoto))
                } else {
                    completion(.failure(NSError(domain: "LivePhotoToolTransManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "生成实况图失败"])))
                }
            }
        })
    }
    
    /// 保存实况图到相册
    static func saveTheLivePhotoToTheAlbum(imageURL: URL, videoURL: URL, _ path: String? , completion: @escaping ([String:String]?) -> Void) {
        var localIdentifiers = [String: String]()
        let reFileName = FileSaver.getListTwoComponents(from: path ?? "") ?? ""
        let timeInfos = SaveFileHandler.shared.getTimeInfo([((reFileName as NSString).lastPathComponent, "library_live_photo", path ?? "")])
        //时间信息
        let timeInfo = timeInfos[reFileName] ?? (SaveFileHandler.shared.NO_TIME_MS, SaveFileHandler.shared.NO_TIME_MS, SaveFileHandler.shared.NO_TIME_STR)
        let hDate = SaveFileHandler.shared.getTimeInfo(timeInfo)
        // 首先获取或创建目标相册
        AlbumSaver.getOrCreateAlbum(albumName: fileRootDirectoryName) { assetCollection, error in
            guard let album = assetCollection, error == nil else {
                completion(localIdentifiers)
                return
            }
            DispatchQueue.main.async {
                PHLivePhoto.request(withResourceFileURLs: [imageURL, videoURL], placeholderImage: nil, targetSize: .zero, contentMode: .aspectFill) { livePhoto, info in
                    print("livePhoto - \(livePhoto)")
                }
                autoreleasepool{
                    PHPhotoLibrary.shared().performChanges({
                        var createdAssets: [PHObjectPlaceholder] = []
                        let creationRequest = PHAssetCreationRequest.forAsset()
                        let options = PHAssetResourceCreationOptions()
                        creationRequest.addResource(with: PHAssetResourceType.pairedVideo, fileURL: videoURL, options: options)
                        creationRequest.addResource(with: PHAssetResourceType.photo, fileURL: imageURL, options: options)
                        //获取鸿蒙端带过来的时间，如果有添加进去
                        if let date = hDate {
                            creationRequest.creationDate = date
                        }
                        // 存储placeholder与原始路径的映射
                        if let placeholder = creationRequest.placeholderForCreatedAsset {
                            createdAssets.append(placeholder)
                            localIdentifiers[path ?? ""] = placeholder.localIdentifier
                        } else {
                            localIdentifiers[path ?? ""] = ""
                        }
                        
                        // 将创建的资产添加到目标相册
                        if let albumChangeRequest = PHAssetCollectionChangeRequest(for: album) {
                            albumChangeRequest.addAssets(createdAssets as NSArray)
                        }
                    }, completionHandler: { (success, error) -> Void in
                        if !success {
                            ShareAPI.shared().log(1, "实况图生成失败：\((error?.localizedDescription)!)")
                            completion(nil)
                        } else {
                            completion(localIdentifiers)
                        }
                    })
                }
            }
            
        }
    }
}

// MARK: - 图片元数据处理（保持原有逻辑，已正确保留元数据）
fileprivate class ImageMetaclassDataTool {
    fileprivate let kFigAppleMakerNote_AssetIdentifier = "17"
    fileprivate let path: String

    init(path: String) {
        self.path = path
    }

    func read() -> String? {
        guard let makerNote = metadata()?.object(forKey: kCGImagePropertyMakerAppleDictionary) as! NSDictionary? else {
            return nil
        }
        return makerNote.object(forKey: kFigAppleMakerNote_AssetIdentifier) as! String?
    }

    func write(_ dest: String, assetIdentifier: String) {
        guard let dest = CGImageDestinationCreateWithURL(URL(fileURLWithPath: dest) as CFURL, kUTTypeJPEG, 1, nil)
            else { return }
        defer { CGImageDestinationFinalize(dest) }
        guard let imageSource = self.imageSource() else { return }
        // 关键：获取原元数据的可变副本（保留原有信息如GPS）
        guard let metadata = self.metadata()?.mutableCopy() as! NSMutableDictionary? else { return }

        let makerNote = NSMutableDictionary()
        makerNote.setObject(assetIdentifier, forKey: kFigAppleMakerNote_AssetIdentifier as NSCopying)
        metadata.setObject(makerNote, forKey: kCGImagePropertyMakerAppleDictionary as String as NSCopying)
        CGImageDestinationAddImageFromSource(dest, imageSource, 0, metadata)
    }

    fileprivate func metadata() -> NSDictionary? {
        return self.imageSource().flatMap {
            CGImageSourceCopyPropertiesAtIndex($0, 0, nil) as NSDictionary?
        }
    }

    fileprivate func imageSource() -> CGImageSource? {
        return self.data().flatMap {
            CGImageSourceCreateWithData($0 as CFData, nil)
        }
    }

    fileprivate func data() -> Data? {
        return (try? Data(contentsOf: URL(fileURLWithPath: path)))
    }
}

// MARK: - 视频元数据处理（修复元数据丢失问题）
fileprivate class VideoMetaclassDataTool {
    fileprivate let kKeyContentIdentifier =  "com.apple.quicktime.content.identifier"
    fileprivate let kKeyStillImageTime = "com.apple.quicktime.still-image-time"
    fileprivate let kKeySpaceQuickTimeMetadata = "mdta"
    fileprivate let path: String
    fileprivate let dummyTimeRange = CMTimeRangeMake(start: CMTimeMake(value: 0, timescale: 1000), duration: CMTimeMake(value: 200, timescale: 3000))
    
    fileprivate lazy var asset: AVURLAsset = {
        let url = URL(fileURLWithPath: self.path)
        return AVURLAsset(url: url)
    }()
    
    init(path: String) {
        self.path = path
    }
    
    func readAssetIdentifier() -> String? {
        for item in metadata() {
            if item.key as? String == kKeyContentIdentifier &&
                item.keySpace!.rawValue == kKeySpaceQuickTimeMetadata {
                return item.value as? String
            }
        }
        return nil
    }
    
    func readStillImageTime() -> NSNumber? {
        guard let track = track(AVMediaType.video) else { return nil }
        
        do {
            let (reader, output) = try self.reader(track, settings: nil)
            reader.startReading()
            
            while true {
                guard let buffer = output.copyNextSampleBuffer() else { return nil }
                if CMSampleBufferGetNumSamples(buffer) != 0 {
                    let group = AVTimedMetadataGroup(sampleBuffer: buffer)
                    for item in group?.items ?? [] {
                        if item.key as? String == kKeyStillImageTime &&
                            item.keySpace!.rawValue == kKeySpaceQuickTimeMetadata {
                            return item.numberValue
                        }
                    }
                }
            }
        } catch {
            ShareAPI.shared().log(1, "读取静帧时间错误: \(error)")
            return nil
        }
    }
    /*
     func write(_ dest: String, assetIdentifier: String) {
     var audioReader: AVAssetReader? = nil
     var audioWriterInput: AVAssetWriterInput? = nil
     var audioReaderOutput: AVAssetReaderOutput? = nil
     
     do {
     guard let videoTrack = self.track(AVMediaType.video) else {
     print("错误: 未找到视频轨道")
     return
     }
     
     let (videoReader, videoOutput) = try self.reader(
     videoTrack,
     settings: [kCVPixelBufferPixelFormatTypeKey as String: NSNumber(value: kCVPixelFormatType_32BGRA as UInt32)]
     )
     
     let outputURL = URL(fileURLWithPath: dest)
     guard let writer = try? AVAssetWriter(outputURL: outputURL, fileType: .mov) else {
     print("错误: 无法初始化视频写入器")
     return
     }
     
     // ==============================================
     // 核心修复：保留原有元数据（如位置、时间）并追加新数据
     // ==============================================
     // 1. 获取原视频的QuickTime格式元数据（包含GPS、拍摄时间等关键信息）
     var newMetadata = asset.metadata//asset.metadata(forFormat: .quickTimeMetadata)
     
     // 2. 过滤旧的Asset Identifier（避免重复）
     newMetadata = newMetadata.filter { $0.key as? String != kKeyContentIdentifier }
     // 3. 追加新的Asset Identifier
     newMetadata.append(metadataFor(assetIdentifier))
     // 4. 赋值给写入器（保留所有原有元数据）
     writer.metadata = newMetadata
     
     // 配置视频输入
     let videoInput = AVAssetWriterInput(
     mediaType: .video,
     outputSettings: videoSettings(videoTrack.naturalSize)
     )
     videoInput.expectsMediaDataInRealTime = true
     videoInput.transform = videoTrack.preferredTransform
     
     guard writer.canAdd(videoInput) else {
     print("错误: 无法添加视频输入")
     return
     }
     writer.add(videoInput)
     
     // 处理音频轨道
     let audioAsset = AVAsset(url: URL(fileURLWithPath: self.path))
     let audioTracks = audioAsset.tracks(withMediaType: .audio)
     let hasAudio = !audioTracks.isEmpty
     
     if hasAudio, let audioTrack = audioTracks.first {
     audioWriterInput = AVAssetWriterInput(mediaType: .audio, outputSettings: nil)
     audioWriterInput?.expectsMediaDataInRealTime = false
     
     if let audioWriterInput = audioWriterInput, writer.canAdd(audioWriterInput) {
     writer.add(audioWriterInput)
     } else {
     print("警告: 无法添加音频输入，将仅处理视频")
     audioWriterInput = nil
     }
     
     do {
     audioReader = try AVAssetReader(asset: audioAsset)
     } catch {
     print("警告: 初始化音频读取器失败: \(error)，将仅处理视频")
     audioReader = nil
     audioWriterInput = nil
     }
     
     if let audioReader = audioReader, let _ = audioWriterInput {
     audioReaderOutput = AVAssetReaderTrackOutput(track: audioTrack, outputSettings: nil)
     
     if let audioReaderOutput = audioReaderOutput, audioReader.canAdd(audioReaderOutput) {
     audioReader.add(audioReaderOutput)
     } else {
     print("警告: 无法添加音频输出，将仅处理视频")
     audioReaderOutput = nil
     }
     }
     } else {
     print("信息: 未检测到音频轨道，将仅处理视频")
     }
     
     // 配置元数据适配器
     let metadataAdapter = self.metadataAdapter()
     writer.add(metadataAdapter.assetWriterInput)
     
     // 开始写入流程
     guard writer.startWriting() else {
     print("错误: 无法启动写入器: \(writer.error?.localizedDescription ?? "未知错误")")
     return
     }
     
     videoReader.startReading()
     writer.startSession(atSourceTime: CMTime.zero)
     
     // 写入静帧时间元数据
     metadataAdapter.append(AVTimedMetadataGroup(
     items: [metadataForStillImageTime()],
     timeRange: dummyTimeRange
     ))
     
     // 处理视频数据写入
     let videoQueue = DispatchQueue(label: "com.example.videoWriterQueue")
     videoInput.requestMediaDataWhenReady(on: videoQueue) { [weak self] in
     guard let self = self else { return }
     
     while videoInput.isReadyForMoreMediaData {
     switch videoReader.status {
     case .reading:
     if let sampleBuffer = videoOutput.copyNextSampleBuffer() {
     if !videoInput.append(sampleBuffer) {
     print("错误: 视频写入失败: \(writer.error?.localizedDescription ?? "未知错误")")
     videoReader.cancelReading()
     CMSampleBufferInvalidate(sampleBuffer)
     }
     }
     
     case .completed:
     videoInput.markAsFinished()
     print("信息: 视频数据处理完成")
     
     if hasAudio, let audioReader = audioReader,
     let audioWriterInput = audioWriterInput, let audioReaderOutput = audioReaderOutput {
     self.handleAudioWriting(
     audioReader: audioReader,
     audioWriterInput: audioWriterInput,
     audioReaderOutput: audioReaderOutput,
     writer: writer
     )
     } else {
     writer.finishWriting {
     if let error = writer.error {
     print("错误: 视频写入完成但有错误: \(error.localizedDescription)")
     } else {
     print("信息: 视频写入成功")
     }
     }
     }
     return
     
     case .failed, .cancelled:
     videoInput.markAsFinished()
     writer.cancelWriting()
     print("错误: 视频读取失败: \(videoReader.error?.localizedDescription ?? "未知错误")")
     return
     
     default:
     break
     }
     }
     }
     
     while writer.status == .writing {
     RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.1))
     }
     
     } catch {
     print("错误: 写入过程发生错误: \(error.localizedDescription)")
     }
     }
     */
    /// 兼容性写入方法：iOS15+使用自定义处理，iOS14及以下使用AVAssetExportSession
    func writeWithCompatibility(dest: String, assetIdentifier: String, completion: @escaping (Bool) -> Void) {
        let outputURL = URL(fileURLWithPath: dest)
        // iOS 15及以上使用自定义处理器（支持完整功能）
//        if #available(iOS 15, *) {
            ShareAPI.shared().log(1, "使用自定义处理器（iOS 15+）")
            writeUsingCustomProcessor(dest: dest, assetIdentifier: assetIdentifier, completion: completion)
//        } else {
            // iOS 14及以下使用AVAssetExportSession（更稳定）
//            ShareAPI.shared().log(1, "使用AVAssetExportSession（iOS 14及以下）")
//            writeUsingExportSession(outputURL: outputURL, assetIdentifier: assetIdentifier, completion: completion)
//            writeWithoutAudio(outputURL: outputURL, assetIdentifier: assetIdentifier, completion: completion)

//        }
        
    }
    /// iOS 14及以下版本：跳过音频处理
    private func writeWithoutAudio(outputURL: URL, assetIdentifier: String, completion: @escaping (Bool) -> Void) {
        do {
            // 1. 验证视频轨道
            guard let videoTrack = self.track(AVMediaType.video) else {
                ShareAPI.shared().log(1, "错误: 未找到视频轨道")
                DispatchQueue.main.async { completion(false) }
                return
            }
            
            // 2. 检查是否有音频轨道（仅用于日志）
            let audioTracks = asset.tracks(withMediaType: .audio)
            let hasAudio = !audioTracks.isEmpty
            if hasAudio {
                ShareAPI.shared().log(1, "⚠️ 检测到音频轨道，但在iOS 14及以下版本中跳过处理以避免崩溃")
            } else {
                ShareAPI.shared().log(1, "信息: 未检测到音频轨道")
            }
            
            // 3. 创建视频读取器
            let (videoReader, videoOutput) = try self.reader(
                videoTrack,
                settings: [kCVPixelBufferPixelFormatTypeKey as String: NSNumber(value: kCVPixelFormatType_32BGRA as UInt32)]
            )
            
            // 4. 创建视频写入器
            guard let writer = try? AVAssetWriter(outputURL: outputURL, fileType: .mov) else {
                ShareAPI.shared().log(1, "错误: 无法初始化视频写入器")
                DispatchQueue.main.async { completion(false) }
                return
            }
            
            // 5. 配置元数据：保留所有原始元数据并添加Asset Identifier
            var newMetadata = asset.metadata
            
            // 过滤掉旧的Asset Identifier
            newMetadata = newMetadata.filter {
                !($0.key as? String == kKeyContentIdentifier &&
                  $0.keySpace?.rawValue == kKeySpaceQuickTimeMetadata)
            }
            
            // 添加新的Asset Identifier
            newMetadata.append(metadataFor(assetIdentifier))
            
            // 设置写入器的元数据
            writer.metadata = newMetadata
            ShareAPI.shared().log(1, "已设置 \(newMetadata.count) 个元数据项")
            
            // 6. 配置视频输入
            let videoInput = AVAssetWriterInput(
                mediaType: .video,
                outputSettings: videoSettings(videoTrack.naturalSize)
            )
            videoInput.expectsMediaDataInRealTime = true
            videoInput.transform = videoTrack.preferredTransform
            
            guard writer.canAdd(videoInput) else {
                ShareAPI.shared().log(1, "错误: 无法添加视频输入")
                DispatchQueue.main.async { completion(false) }
                return
            }
            writer.add(videoInput)
            
            // 7. 🚨 关键：在iOS 14及以下完全跳过音频处理
            // 不创建任何音频相关的Reader或WriterInput
            
            // 8. 配置静帧时间元数据适配器
            let metadataAdapter = self.metadataAdapter()
            writer.add(metadataAdapter.assetWriterInput)
            
            // 9. 开始写入流程
            guard writer.startWriting() else {
                ShareAPI.shared().log(1, "错误: 无法启动写入器: \(writer.error?.localizedDescription ?? "未知错误")")
                DispatchQueue.main.async { completion(false) }
                return
            }
            
            // 启动视频读取
            guard videoReader.startReading() else {
                ShareAPI.shared().log(1, "错误: 无法启动视频读取器: \(videoReader.error?.localizedDescription ?? "未知错误")")
                DispatchQueue.main.async { completion(false) }
                return
            }
            
            // 🚨 关键：必须在附加数据前启动会话
            writer.startSession(atSourceTime: CMTime.zero)
            
            // 10. 写入静帧时间元数据
            metadataAdapter.append(AVTimedMetadataGroup(
                items: [metadataForStillImageTime()],
                timeRange: dummyTimeRange
            ))
            
            // 11. 处理视频数据写入（无音频）
            processVideoOnly(
                videoReader: videoReader,
                videoOutput: videoOutput as! AVAssetReaderTrackOutput,//
                videoInput: videoInput,
                writer: writer,
                completion: completion
            )
            
        } catch {
            ShareAPI.shared().log(1, "无音频处理错误: \(error.localizedDescription)")
            DispatchQueue.main.async { completion(false) }
        }
    }
    
    /// 仅处理视频数据（无音频）
    private func processVideoOnly(
        videoReader: AVAssetReader,
        videoOutput: AVAssetReaderTrackOutput,
        videoInput: AVAssetWriterInput,
        writer: AVAssetWriter,
        completion: @escaping (Bool) -> Void
    ) {
        let videoQueue = DispatchQueue(label: "com.livephoto.videoOnlyQueue")
        
        videoInput.requestMediaDataWhenReady(on: videoQueue) {
            while videoInput.isReadyForMoreMediaData {
                switch videoReader.status {
                case .reading:
                    if let sampleBuffer = videoOutput.copyNextSampleBuffer() {
                        // 🚨 关键：确保在正确的状态下附加数据
                        guard writer.status == .writing else {
                            ShareAPI.shared().log(1, "错误: 写入器状态异常: \(writer.status.rawValue)")
                            videoReader.cancelReading()
                            CMSampleBufferInvalidate(sampleBuffer)
                            break
                        }
                        
                        let appendSuccess = videoInput.append(sampleBuffer)
                        CMSampleBufferInvalidate(sampleBuffer)
                        
                        if !appendSuccess {
                            ShareAPI.shared().log(1, "错误: 视频写入失败: \(writer.error?.localizedDescription ?? "未知错误")")
                            videoReader.cancelReading()
                            break
                        }
                    } else {
                        // 视频数据读取完毕
                        videoInput.markAsFinished()
                        ShareAPI.shared().log(1, "信息: 视频数据处理完成（无音频）")
                        
                        // 完成写入
                        writer.finishWriting {
                            self.handleVideoOnlyCompletion(writer: writer, completion: completion)
                        }
                        return
                    }
                    
                case .completed:
                    videoInput.markAsFinished()
                    ShareAPI.shared().log(1, "信息: 视频读取完成")
                    
                    // 完成写入
                    writer.finishWriting {
                        self.handleVideoOnlyCompletion(writer: writer, completion: completion)
                    }
                    return
                    
                case .failed, .cancelled:
                    videoInput.markAsFinished()
                    writer.cancelWriting()
                    ShareAPI.shared().log(1, "错误: 视频读取失败: \(videoReader.error?.localizedDescription ?? "未知错误")")
                    DispatchQueue.main.async { completion(false) }
                    return
                    
                default:
                    break
                }
            }
        }
    }
    
    /// 处理仅视频完成的回调
    private func handleVideoOnlyCompletion(writer: AVAssetWriter, completion: @escaping (Bool) -> Void) {
        DispatchQueue.main.async {
            switch writer.status {
            case .completed:
                ShareAPI.shared().log(1, "✅ 无音频视频处理成功")
                completion(true)
            case .failed:
                if let error = writer.error {
                    print("❌ 无音频视频处理失败: \(error.localizedDescription)")
                }
                completion(false)
            case .cancelled:
                ShareAPI.shared().log(1, "⚠️ 无音频视频处理被取消")
                completion(false)
            default:
                ShareAPI.shared().log(1, "❓ 无音频视频处理未知状态: \(writer.status.rawValue)")
                completion(false)
            }
        }
    }
    
    /// 使用自定义处理器处理视频（iOS 15+）
    /// - Parameters:
    ///   - dest: 目标文件路径
    ///   - assetIdentifier: 资产标识符
    ///   - completion: 完成回调
    private func writeUsingCustomProcessor(dest: String, assetIdentifier: String, completion: @escaping (Bool) -> Void) {
        var audioReader: AVAssetReader? = nil
        var audioWriterInput: AVAssetWriterInput? = nil
        var audioReaderOutput: AVAssetReaderOutput? = nil
        
        // 确保在后台队列执行，避免阻塞主线程
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                // 1. 验证视频轨道
                guard let videoTrack = self.track(AVMediaType.video) else {
                    ShareAPI.shared().log(1, "错误: 未找到视频轨道")
                    DispatchQueue.main.async { completion(false) }
                    return
                }
                
                // 2. 创建视频读取器
                let (videoReader, videoOutput) = try self.reader(
                    videoTrack,
                    settings: [kCVPixelBufferPixelFormatTypeKey as String: NSNumber(value: kCVPixelFormatType_32BGRA as UInt32)]
                )
                
                // 3. 创建视频写入器
                let outputURL = URL(fileURLWithPath: dest)
                guard let writer = try? AVAssetWriter(outputURL: outputURL, fileType: .mov) else {
                    ShareAPI.shared().log(1, "错误: 无法初始化视频写入器")
                    DispatchQueue.main.async { completion(false) }
                    return
                }
                
                // 4. 配置元数据：保留所有原始元数据并添加Asset Identifier
                var newMetadata = self.asset.metadata // 获取所有格式的元数据
                
                // 过滤掉旧的Asset Identifier（避免重复）
                newMetadata = newMetadata.filter {
                    !($0.key as? String == self.kKeyContentIdentifier &&
                      $0.keySpace?.rawValue == self.kKeySpaceQuickTimeMetadata)
                }
                
                // 添加新的Asset Identifier
                newMetadata.append(self.metadataFor(assetIdentifier))
                
                // 设置写入器的元数据
                writer.metadata = newMetadata
                ShareAPI.shared().log(1, "已设置 \(newMetadata.count) 个元数据项")
                
                // 5. 配置视频输入
                let videoInput = AVAssetWriterInput(
                    mediaType: .video,
                    outputSettings: self.videoSettings(videoTrack.naturalSize)
                )
                videoInput.expectsMediaDataInRealTime = true
                videoInput.transform = videoTrack.preferredTransform
                
                guard writer.canAdd(videoInput) else {
                    ShareAPI.shared().log(1, "错误: 无法添加视频输入")
                    DispatchQueue.main.async { completion(false) }
                    return
                }
                writer.add(videoInput)
                
                // 6. 处理音频轨道
                let audioAsset = AVAsset(url: URL(fileURLWithPath: self.path))
                let audioTracks = audioAsset.tracks(withMediaType: .audio)
                let hasAudio = !audioTracks.isEmpty
                
                if hasAudio, let audioTrack = audioTracks.first {
                    ShareAPI.shared().log(1, "检测到音频轨道，开始处理音频...")
                    
                    // 配置音频写入输入
                    audioWriterInput = AVAssetWriterInput(mediaType: .audio, outputSettings: nil)
                    audioWriterInput?.expectsMediaDataInRealTime = false
                    
                    if let audioWriterInput = audioWriterInput, writer.canAdd(audioWriterInput) {
                        writer.add(audioWriterInput)
                    } else {
                        ShareAPI.shared().log(1, "警告: 无法添加音频输入，将仅处理视频")
                        audioWriterInput = nil
                    }
                    
                    // 创建音频读取器
                    do {
                        audioReader = try AVAssetReader(asset: audioAsset)
                    } catch {
                        ShareAPI.shared().log(1, "警告: 初始化音频读取器失败: \(error)，将仅处理视频")
                        audioReader = nil
                        audioWriterInput = nil
                    }
                    var outputSetting: [String: Any]? = nil
                    if #unavailable(iOS 15) {
                        outputSetting = [
                            AVFormatIDKey: Int(kAudioFormatLinearPCM),
                            AVSampleRateKey: 44100.0,
                            AVNumberOfChannelsKey: 2,
                            AVLinearPCMBitDepthKey: 16,
                            AVLinearPCMIsBigEndianKey: false,
                            AVLinearPCMIsFloatKey: false,
                            AVLinearPCMIsNonInterleaved: false // 交织
                        ]
                    }
                    
                    // 配置音频读取输出
                    if let audioReader = audioReader, audioWriterInput != nil {
                        audioReaderOutput = AVAssetReaderTrackOutput(track: audioTrack, outputSettings: outputSetting)
                        
                        if let audioReaderOutput = audioReaderOutput, audioReader.canAdd(audioReaderOutput) {
                            audioReader.add(audioReaderOutput)
                        } else {
                            ShareAPI.shared().log(1, "警告: 无法添加音频输出，将仅处理视频")
                            audioReaderOutput = nil
                        }
                    }
                } else {
                    ShareAPI.shared().log(1, "信息: 未检测到音频轨道，将仅处理视频")
                }
                
                // 7. 配置静帧时间元数据适配器
                let metadataAdapter = self.metadataAdapter()
                writer.add(metadataAdapter.assetWriterInput)
                
                // 8. 开始写入流程
                guard writer.startWriting() else {
                    ShareAPI.shared().log(1, "错误: 无法启动写入器: \(writer.error?.localizedDescription ?? "未知错误")")
                    DispatchQueue.main.async { completion(false) }
                    return
                }
                
                // 启动视频读取
                guard videoReader.startReading() else {
                    ShareAPI.shared().log(1, "错误: 无法启动视频读取器: \(videoReader.error?.localizedDescription ?? "未知错误")")
                    DispatchQueue.main.async { completion(false) }
                    return
                }
                
                writer.startSession(atSourceTime: CMTime.zero)
                
                // 9. 写入静帧时间元数据
                metadataAdapter.append(AVTimedMetadataGroup(
                    items: [self.metadataForStillImageTime()],
                    timeRange: self.dummyTimeRange
                ))
                
                // 10. 处理视频数据写入
                let videoQueue = DispatchQueue(label: "com.livephoto.videoWriterQueue")
                var videoWritingFinished = false
                var audioWritingFinished = !hasAudio // 如果没有音频，音频写入直接视为完成
                
                videoInput.requestMediaDataWhenReady(on: videoQueue) {
                    while videoInput.isReadyForMoreMediaData {
                        switch videoReader.status {
                        case .reading:
                            if let sampleBuffer = videoOutput.copyNextSampleBuffer() {
                                let appendSuccess = videoInput.append(sampleBuffer)
                                if !appendSuccess {
                                    ShareAPI.shared().log(1, "错误: 视频写入失败: \(writer.error?.localizedDescription ?? "未知错误")")
                                    videoReader.cancelReading()
                                    break
                                }
                            } else {
                                // 视频数据读取完毕
                                videoInput.markAsFinished()
                                videoWritingFinished = true
                                ShareAPI.shared().log(1, "信息: 视频数据处理完成")
                                
                                // 检查是否所有写入都完成
                                if videoWritingFinished && audioWritingFinished {
                                    writer.finishWriting {
                                        self.handleWritingCompletion(writer: writer, completion: completion)
                                    }
                                }
                                return
                            }
                            
                        case .completed:
                            videoInput.markAsFinished()
                            videoWritingFinished = true
                            ShareAPI.shared().log(1, "信息: 视频读取完成")
                            
                            // 检查是否所有写入都完成
                            if videoWritingFinished && audioWritingFinished {
                                writer.finishWriting {
                                    self.handleWritingCompletion(writer: writer, completion: completion)
                                }
                            }
                            return
                            
                        case .failed, .cancelled:
                            videoInput.markAsFinished()
                            writer.cancelWriting()
                            ShareAPI.shared().log(1, "错误: 视频读取失败: \(videoReader.error?.localizedDescription ?? "未知错误")")
                            DispatchQueue.main.async { completion(false) }
                            return
                            
                        default:
                            break
                        }
                    }
                }
                
                // 11. 处理音频数据写入（如果存在音频）
                if hasAudio, let audioReader = audioReader,
                   let audioWriterInput = audioWriterInput,
                   let audioReaderOutput = audioReaderOutput {
                    
                    guard audioReader.startReading() else {
                        ShareAPI.shared().log(1, "错误: 无法启动音频读取器")
                        audioWriterInput.markAsFinished()
                        audioWritingFinished = true
                        return
                    }
                    
                    let audioQueue = DispatchQueue(label: "com.livephoto.audioWriterQueue")
                    
                    audioWriterInput.requestMediaDataWhenReady(on: audioQueue) {
                        while audioWriterInput.isReadyForMoreMediaData {
                            switch audioReader.status {
                            case .reading:
                                if let sampleBuffer = audioReaderOutput.copyNextSampleBuffer() {
                                    let appendSuccess = audioWriterInput.append(sampleBuffer)
                                    if !appendSuccess {
                                        ShareAPI.shared().log(1, "错误: 音频写入失败: \(writer.error?.localizedDescription ?? "未知错误")")
                                        audioReader.cancelReading()
                                        break
                                    }
                                } else {
                                    // 音频数据读取完毕
                                    audioWriterInput.markAsFinished()
                                    audioWritingFinished = true
                                    ShareAPI.shared().log(1, "信息: 音频数据处理完成")
                                    
                                    // 检查是否所有写入都完成
                                    if videoWritingFinished && audioWritingFinished {
                                        writer.finishWriting {
                                            self.handleWritingCompletion(writer: writer, completion: completion)
                                        }
                                    }
                                    return
                                }
                                
                            case .completed:
                                audioWriterInput.markAsFinished()
                                audioWritingFinished = true
                                ShareAPI.shared().log(1, "信息: 音频读取完成")
                                
                                // 检查是否所有写入都完成
                                if videoWritingFinished && audioWritingFinished {
                                    writer.finishWriting {
                                        self.handleWritingCompletion(writer: writer, completion: completion)
                                    }
                                }
                                return
                                
                            case .failed, .cancelled:
                                audioWriterInput.markAsFinished()
                                writer.cancelWriting()
                                ShareAPI.shared().log(1, "错误: 音频读取失败: \(audioReader.error?.localizedDescription ?? "未知错误")")
                                DispatchQueue.main.async { completion(false) }
                                return
                                
                            default:
                                break
                            }
                        }
                    }
                }
                
                // 12. 监控写入进度（可选，用于长时间处理）
                self.monitorWritingProgress(writer: writer, videoReader: videoReader)
                
            } catch {
                ShareAPI.shared().log(1, "自定义处理器错误: \(error.localizedDescription)")
                DispatchQueue.main.async { completion(false) }
            }
        }
    }

    // MARK: - 辅助方法

    /// 处理写入完成状态
    private func handleWritingCompletion(writer: AVAssetWriter, completion: @escaping (Bool) -> Void) {
        DispatchQueue.main.async {
            switch writer.status {
            case .completed:
                ShareAPI.shared().log(1, "✅ 自定义处理器处理成功")
                completion(true)
            case .failed:
                if let error = writer.error {
                    ShareAPI.shared().log(1, "❌ 自定义处理器失败: \(error.localizedDescription)")
                }
                completion(false)
            case .cancelled:
                ShareAPI.shared().log(1, "⚠️ 自定义处理器被取消")
                completion(false)
            default:
                ShareAPI.shared().log(1, "❓ 自定义处理器未知状态: \(writer.status.rawValue)")
                completion(false)
            }
        }
    }

    /// 监控写入进度（用于长时间处理的反馈）
    private func monitorWritingProgress(writer: AVAssetWriter, videoReader: AVAssetReader) {
        // 创建进度监控计时器（可选）
        let progressTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { timer in
            switch writer.status {
            case .writing:
                // 可以在这里添加进度回调，如果需要的话
                // 例如：progressCallback?(currentProgress)
                break
            case .completed, .failed, .cancelled:
                timer.invalidate()
            default:
                break
            }
            
            // 检查是否超时（安全机制）
            if writer.status == .writing && videoReader.status != .reading {
                ShareAPI.shared().log(1, "警告: 写入器仍在写入但读取器已停止")
            }
        }
        
        // 确保计时器在合适的RunLoop中运行
        RunLoop.current.add(progressTimer, forMode: .common)
    }

    /// 增强的视频设置（提供更好的编码质量）
    private func enhancedVideoSettings(_ size: CGSize, forTrack videoTrack: AVAssetTrack) -> [String: AnyObject] {
        var settings: [String: AnyObject] = [
            AVVideoCodecKey: AVVideoCodecType.h264 as AnyObject,
            AVVideoWidthKey: size.width as AnyObject,
            AVVideoHeightKey: size.height as AnyObject,
        ]
        
        // 为高质量输出添加压缩属性
        let compressionProperties: [String: Any] = [
            AVVideoAverageBitRateKey: NSNumber(value: Int(videoTrack.estimatedDataRate > 0 ? videoTrack.estimatedDataRate : 5_000_000)),
            AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel,
            AVVideoMaxKeyFrameIntervalKey: NSNumber(value: 30),
            AVVideoAllowFrameReorderingKey: NSNumber(value: true)
        ]
        
        settings[AVVideoCompressionPropertiesKey] = compressionProperties as AnyObject
        
        return settings
    }

    /// 验证输出文件完整性
    private func verifyOutputFile(_ fileURL: URL) -> Bool {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            ShareAPI.shared().log(1, "错误: 输出文件不存在")
            return false
        }
        
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: fileURL.path)
            let fileSize = attributes[.size] as? Int64 ?? 0
            
            if fileSize == 0 {
                ShareAPI.shared().log(1, "错误: 输出文件大小为0")
                return false
            }
            
            ShareAPI.shared().log(1, "输出文件验证成功，大小: \(fileSize) 字节")
            return true
            
        } catch {
            ShareAPI.shared().log(1, "验证输出文件错误: \(error.localizedDescription)")
            return false
        }
    }
    /// 使用AVAssetExportSession处理视频（iOS 14及以下版本）
    private func writeUsingExportSession(outputURL: URL, assetIdentifier: String, completion: @escaping (Bool) -> Void) {
        let sourceAsset = AVURLAsset(url: URL(fileURLWithPath: self.path))
        
        // 检查是否支持直通模式（保留原始编码）
        let supportsPassthrough = AVAssetExportSession.allExportPresets().contains(AVAssetExportPresetPassthrough)
        
        // 选择导出预设：优先使用直通模式，否则使用高质量模式
        let exportPreset = supportsPassthrough ? AVAssetExportPresetPassthrough : AVAssetExportPresetHighestQuality
        
        guard let exportSession = AVAssetExportSession(asset: sourceAsset, presetName: exportPreset) else {
            ShareAPI.shared().log(1, "错误: 无法创建AVAssetExportSession")
            completion(false)
            return
        }
        
        exportSession.outputURL = outputURL
        exportSession.outputFileType = .mov
        exportSession.shouldOptimizeForNetworkUse = false // 关闭网络优化以保持质量
        
        // 准备元数据：保留原始元数据并添加Asset Identifier
        prepareMetadataForExportSession(exportSession: exportSession, assetIdentifier: assetIdentifier)
        
        ShareAPI.shared().log(1, "开始导出视频...")
        exportSession.exportAsynchronously {
            DispatchQueue.main.async {
                switch exportSession.status {
                case .completed:
                    ShareAPI.shared().log(1, "AVAssetExportSession处理成功")
                    
                    // 导出成功后，需要手动添加静帧时间元数据
                    self.addStillImageTimeMetadata(to: outputURL) { success in
                        completion(success)
                    }
                    completion(true)
                case .failed:
                    if let error = exportSession.error {
                        ShareAPI.shared().log(1, "AVAssetExportSession失败: \(error.localizedDescription)")
                    }
                    completion(false)
                    
                case .cancelled:
                    ShareAPI.shared().log(1, "AVAssetExportSession被取消")
                    completion(false)
                    
                default:
                    ShareAPI.shared().log(1, "AVAssetExportSession未知状态: \(exportSession.status.rawValue)")
                    completion(false)
                }
            }
        }
    }
    /// 为AVAssetExportSession准备元数据
    private func prepareMetadataForExportSession(exportSession: AVAssetExportSession, assetIdentifier: String) {
        // 获取原始视频的所有元数据
        let sourceAsset = AVURLAsset(url: URL(fileURLWithPath: self.path))
        var allMetadata = sourceAsset.metadata
        
        // 过滤掉可能已存在的Asset Identifier
        allMetadata = allMetadata.filter {
            !($0.key as? String == kKeyContentIdentifier && $0.keySpace?.rawValue == kKeySpaceQuickTimeMetadata)
        }
        
        // 添加新的Asset Identifier
        let assetIdentifierItem = AVMutableMetadataItem()
        assetIdentifierItem.key = kKeyContentIdentifier as (NSCopying & NSObjectProtocol)?
        assetIdentifierItem.keySpace = AVMetadataKeySpace(rawValue: kKeySpaceQuickTimeMetadata)
        assetIdentifierItem.value = assetIdentifier as (NSCopying & NSObjectProtocol)?
        assetIdentifierItem.dataType = "com.apple.metadata.datatype.UTF-8"
        
        allMetadata.append(assetIdentifierItem)
        
        // 设置导出会话的元数据
        exportSession.metadata = allMetadata
        
        ShareAPI.shared().log(1, "已设置 \(allMetadata.count) 个元数据项")
    }
    
    /// 为已导出的视频添加静帧时间元数据
    private func addStillImageTimeMetadata(to videoURL: URL, completion: @escaping (Bool) -> Void) {
        let asset = AVURLAsset(url: videoURL)
        
        // 创建临时输出URL
        guard let tempURL = createTempFileURL() else {
            completion(false)
            return
        }
        
        do {
            guard let videoTrack = asset.tracks(withMediaType: .video).first else {
                ShareAPI.shared().log(1, "错误: 未找到视频轨道")
                completion(false)
                return
            }
            
            let (videoReader, videoOutput) = try self.reader(
                videoTrack,
                settings: [kCVPixelBufferPixelFormatTypeKey as String: NSNumber(value: kCVPixelFormatType_32BGRA as UInt32)]
            )
            
            guard let writer = try? AVAssetWriter(outputURL: tempURL, fileType: .mov) else {
                ShareAPI.shared().log(1, "错误: 无法初始化视频写入器")
                completion(false)
                return
            }
            
            // 复制原始视频的所有元数据
            writer.metadata = asset.metadata
            
            // 配置视频输入
            let videoInput = AVAssetWriterInput(
                mediaType: .video,
                outputSettings: videoSettings(videoTrack.naturalSize)
            )
            videoInput.expectsMediaDataInRealTime = true
            videoInput.transform = videoTrack.preferredTransform
            
            guard writer.canAdd(videoInput) else {
                ShareAPI.shared().log(1, "错误: 无法添加视频输入")
                completion(false)
                return
            }
            writer.add(videoInput)
            
            // 配置静帧时间元数据适配器
            let metadataAdapter = self.metadataAdapter()
            writer.add(metadataAdapter.assetWriterInput)
            
            // 开始写入流程
            guard writer.startWriting() else {
                ShareAPI.shared().log(1, "错误: 无法启动写入器")
                completion(false)
                return
            }
            
            videoReader.startReading()
            writer.startSession(atSourceTime: CMTime.zero)
            
            // 添加静帧时间元数据
            metadataAdapter.append(AVTimedMetadataGroup(
                items: [metadataForStillImageTime()],
                timeRange: dummyTimeRange
            ))
            
            // 处理视频数据写入
            let videoQueue = DispatchQueue(label: "com.example.metadataWriterQueue")
            videoInput.requestMediaDataWhenReady(on: videoQueue) {
                while videoInput.isReadyForMoreMediaData {
                    if let sampleBuffer = videoOutput.copyNextSampleBuffer() {
                        if !videoInput.append(sampleBuffer) {
                            ShareAPI.shared().log(1, "错误: 视频写入失败")
                            videoReader.cancelReading()
                            break
                        }
                    } else {
                        videoInput.markAsFinished()
                        break
                    }
                }
                
                // 完成写入
                writer.finishWriting {
                    if writer.status == .completed {
                        // 用包含静帧时间元数据的新文件替换原文件
                        self.replaceOriginalFile(with: tempURL, originalURL: videoURL, completion: completion)
                    } else {
                        ShareAPI.shared().log(1, "错误: 元数据写入失败")
                        try? FileManager.default.removeItem(at: tempURL)
                        completion(false)
                    }
                }
            }
            
        } catch {
            ShareAPI.shared().log(1, "添加静帧时间元数据错误: \(error)")
            completion(false)
        }
    }
    // 处理音频写入的辅助方法
    private func handleAudioWriting(
        audioReader: AVAssetReader,
        audioWriterInput: AVAssetWriterInput,
        audioReaderOutput: AVAssetReaderOutput,
        writer: AVAssetWriter
    ) {
        let audioQueue = DispatchQueue(label: "com.example.audioWriterQueue")
        
        guard audioReader.startReading() else {
            ShareAPI.shared().log(1, "错误: 无法启动音频读取器")
            audioWriterInput.markAsFinished()
            writer.finishWriting {
                ShareAPI.shared().log(1, "错误: 音频处理失败，视频已完成")
            }
            return
        }
        
        writer.startSession(atSourceTime: CMTime.zero)
        
        audioWriterInput.requestMediaDataWhenReady(on: audioQueue) {
            while audioWriterInput.isReadyForMoreMediaData {
                switch audioReader.status {
                case .reading:
                    if let sampleBuffer = audioReaderOutput.copyNextSampleBuffer() {
                        if !audioWriterInput.append(sampleBuffer) {
                            ShareAPI.shared().log(1, "错误: 音频写入失败: \(writer.error?.localizedDescription ?? "未知错误")")
                            audioReader.cancelReading()
                            CMSampleBufferInvalidate(sampleBuffer)
                        }
                    }
                    
                case .completed:
                    audioWriterInput.markAsFinished()
                    ShareAPI.shared().log(1, "信息: 音频数据处理完成")
                    
                    writer.finishWriting {
                        if let error = writer.error {
                            ShareAPI.shared().log(1, "错误: 写入完成但有错误: \(error.localizedDescription)")
                        } else {
                            ShareAPI.shared().log(1, "信息: 音视频写入成功")
                        }
                    }
                    return
                    
                case .failed, .cancelled:
                    audioWriterInput.markAsFinished()
                    writer.cancelWriting()
                    ShareAPI.shared().log(1, "错误: 音频读取失败: \(audioReader.error?.localizedDescription ?? "未知错误")")
                    return
                    
                default:
                    break
                }
            }
        }
    }
    
    // MARK: - 辅助方法
    
    /// 创建临时文件URL
    private func createTempFileURL() -> URL? {
        let tempDir = FileManager.default.temporaryDirectory
        let fileName = UUID().uuidString + ".mov"
        return tempDir.appendingPathComponent(fileName)
    }
    
    private func replaceOriginalFile(with newFileURL: URL, originalURL: URL, completion: @escaping (Bool) -> Void) {
        do {
            // 删除原始文件
            if FileManager.default.fileExists(atPath: originalURL.path) {
                try FileManager.default.removeItem(at: originalURL)
            }
            
            // 将新文件移动到原始位置
            try FileManager.default.moveItem(at: newFileURL, to: originalURL)
            completion(true)
            
        } catch {
            ShareAPI.shared().log(1, "替换文件错误: \(error)")
            // 清理临时文件
            try? FileManager.default.removeItem(at: newFileURL)
            completion(false)
        }
    }
    fileprivate func metadata() -> [AVMetadataItem] {
        return asset.metadata(forFormat: .quickTimeMetadata)
    }
    
    fileprivate func track(_ mediaType: AVMediaType) -> AVAssetTrack? {
        return asset.tracks(withMediaType: mediaType).first
    }
    
    fileprivate func reader(_ track: AVAssetTrack, settings: [String:AnyObject]?) throws -> (AVAssetReader, AVAssetReaderOutput) {
        let output = AVAssetReaderTrackOutput(track: track, outputSettings: settings)
        let reader = try AVAssetReader(asset: asset)
        reader.add(output)
        return (reader, output)
    }
    
    fileprivate func metadataAdapter() -> AVAssetWriterInputMetadataAdaptor {
        let spec: NSDictionary = [
            kCMMetadataFormatDescriptionMetadataSpecificationKey_Identifier as NSString:
                "\(kKeySpaceQuickTimeMetadata)/\(kKeyStillImageTime)",
            kCMMetadataFormatDescriptionMetadataSpecificationKey_DataType as NSString:
                "com.apple.metadata.datatype.int8"
        ]
        
        var desc: CMFormatDescription? = nil
        CMMetadataFormatDescriptionCreateWithMetadataSpecifications(
            allocator: kCFAllocatorDefault,
            metadataType: kCMMetadataFormatType_Boxed,
            metadataSpecifications: [spec] as CFArray,
            formatDescriptionOut: &desc
        )
        
        let input = AVAssetWriterInput(
            mediaType: .metadata,
            outputSettings: nil,
            sourceFormatHint: desc
        )
        return AVAssetWriterInputMetadataAdaptor(assetWriterInput: input)
    }
    
    fileprivate func videoSettings(_ size: CGSize) -> [String:AnyObject] {
        return [
            AVVideoCodecKey: AVVideoCodecType.h264 as AnyObject,
            AVVideoWidthKey: size.width as AnyObject,
            AVVideoHeightKey: size.height as AnyObject
        ]
    }
    
    fileprivate func metadataFor(_ assetIdentifier: String) -> AVMetadataItem {
        let item = AVMutableMetadataItem()
        item.key = kKeyContentIdentifier as (NSCopying & NSObjectProtocol)?
        item.keySpace = AVMetadataKeySpace(rawValue: kKeySpaceQuickTimeMetadata)
        item.value = assetIdentifier as (NSCopying & NSObjectProtocol)?
        item.dataType = "com.apple.metadata.datatype.UTF-8"
        return item
    }
    
    fileprivate func metadataForStillImageTime() -> AVMetadataItem {
        let item = AVMutableMetadataItem()
        item.key = kKeyStillImageTime as (NSCopying & NSObjectProtocol)?
        item.keySpace = AVMetadataKeySpace(rawValue: kKeySpaceQuickTimeMetadata)
        item.value = 0 as (NSCopying & NSObjectProtocol)?
        item.dataType = "com.apple.metadata.datatype.int8"
        return item
    }
}
