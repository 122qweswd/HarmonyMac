//
//  MediaTool.swift
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

struct FilePaths {
    static let cachesURL: URL = {
        guard let url = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first else {
            fatalError("无法获取系统缓存目录（这是严重错误，通常意味着设备存储不可用）")
        }
        return url
    }()
    struct VidToLive {
        static let liveURL: URL = {
            let url = FilePaths.cachesURL.appendingPathComponent("live")
            do {
                try FileManager.default.createDirectory( at: url, withIntermediateDirectories: true, attributes: nil)
            } catch {
                fatalError("无法创建live目录：\(error.localizedDescription)（路径：\(url.path)）")
            }
            return url
        }()
        static var livePath: String { liveURL.path }
    }
}
/// 媒体文件处理工具类，封装JPEG和MOV文件的元数据操作
final class MediaTool {
    
    // MARK: - JPEG相关操作
    
    /// 读取JPEG文件的Asset Identifier
    /// - Parameter path: JPEG文件路径
    /// - Returns: 资产标识符，若不存在则返回nil
    static func readJPEGAssetIdentifier(from path: String) -> String? {
        return ImageMetaclassDataTool(path: path).read()
    }
    
    /// 写入Asset Identifier到JPEG文件
    /// - Parameters:
    ///   - sourcePath: 源JPEG文件路径
    ///   - destPath: 目标JPEG文件路径
    ///   - assetIdentifier: 要写入的资产标识符
    static func writeJPEGAssetIdentifier(from sourcePath: String, to destPath: String, assetIdentifier: String) {
        let jpeg = ImageMetaclassDataTool(path: sourcePath)
        jpeg.write(destPath, assetIdentifier: assetIdentifier)
    }
    
    // MARK: - MOV相关操作
    
    /// 读取MOV文件的Asset Identifier
    /// - Parameter path: MOV文件路径
    /// - Returns: 资产标识符，若不存在则返回nil
    static func readMOVAssetIdentifier(from path: String) -> String? {
        return VideoMetaclassDataTool(path: path).readAssetIdentifier()
    }
    
    /// 读取MOV文件的静帧时间
    /// - Parameter path: MOV文件路径
    /// - Returns: 静帧时间数值，若不存在则返回nil
    static func readMOVStillImageTime(from path: String) -> NSNumber? {
        return VideoMetaclassDataTool(path: path).readStillImageTime()
    }
    
    /// 写入Asset Identifier到MOV文件
    /// - Parameters:
    ///   - sourcePath: 源MOV文件路径
    ///   - destPath: 目标MOV文件路径
    ///   - assetIdentifier: 要写入的资产标识符
    static func writeMOVAssetIdentifier(from sourcePath: String, to destPath: String, assetIdentifier: String) {
        let mov = VideoMetaclassDataTool(path: sourcePath)
        mov.write(destPath, assetIdentifier: assetIdentifier)
    }
    
    /// 生成实况图
    /// - Parameters:
    ///   - videoURL: 实况图的静态图
    ///   - imageURL: 实况图的mov视频
    ///   - completion: 生成成功->LivePhoto，失败->错误信息
    static func generateLivePhoto(videoURL: URL, imageURL: URL, completion: @escaping (Result<PHLivePhoto, Error>) -> Void) {
        PHLivePhoto.request(withResourceFileURLs: [videoURL, imageURL],
                            placeholderImage: nil,
                            targetSize: .zero,
                            contentMode: PHImageContentMode.aspectFit,
                            resultHandler: { (livePhoto, info) -> Void in
            // 检查是否是低质量的临时结果
            let isDegraded = info[PHLivePhotoInfoIsDegradedKey] as? Bool ?? false
            if !isDegraded {
                if let livePhoto = livePhoto {
                    completion(.success(livePhoto))
                }else {
                    completion(.failure(HarmonyConversionError.partialFailure("生成实况图失败")))
                }
            }
        })
    }
    
    /// 保存实况图到相册
    /// - Parameters:
    ///   - imageURL: 实况图的静态图
    ///   - videoURL: 实况图的mov视频
    static func saveTheLivePhotoToTheAlbum(imageURL: URL, videoURL: URL, _ path:String? , completion: @escaping ([String:String]?) -> Void) {
        var localIdentifiers = [String: String]()
        PHPhotoLibrary.shared().performChanges({ () -> Void in
            let creationRequest = PHAssetCreationRequest.forAsset()
            let options = PHAssetResourceCreationOptions()
            creationRequest.addResource(with: PHAssetResourceType.pairedVideo, fileURL: videoURL, options: options)
            creationRequest.addResource(with: PHAssetResourceType.photo, fileURL: imageURL, options: options)
            localIdentifiers[path ?? ""] = creationRequest.placeholderForCreatedAsset?.localIdentifier ?? ""
            }, completionHandler: { (success, error) -> Void in
                if !success {
                    ShareAPI.shared().log(3,"实况图生成失败：\((error?.localizedDescription)!)")
                    completion(nil)
                } else {
                    completion(localIdentifiers)
                }
        })
    }
}

// MARK: - 原始实现封装（保持内部实现不变）
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
            ShareAPI.shared().log(3, "读取静帧时间错误: \(error)")
            return nil
        }
    }

    func write(_ dest: String, assetIdentifier: String) {
        // 音频相关组件，全部使用可选类型
        var audioReader: AVAssetReader? = nil
        var audioWriterInput: AVAssetWriterInput? = nil
        var audioReaderOutput: AVAssetReaderOutput? = nil
        
        do {
            // 1. 处理视频轨道 - 核心逻辑，必须存在
            guard let videoTrack = self.track(AVMediaType.video) else {
                ShareAPI.shared().log(3, "错误: 未找到视频轨道")
                return
            }
            
            // 初始化视频读取器
            let (videoReader, videoOutput) = try self.reader(
                videoTrack,
                settings: [kCVPixelBufferPixelFormatTypeKey as String: NSNumber(value: kCVPixelFormatType_32BGRA as UInt32)]
            )
            
            // 初始化视频写入器
            let outputURL = URL(fileURLWithPath: dest)
            guard let writer = try? AVAssetWriter(outputURL: outputURL, fileType: .mov) else {
                ShareAPI.shared().log(3, "错误: 无法初始化视频写入器")
                return
            }
            var newMetadata = asset.metadata(forFormat: .quickTimeMetadata)
            newMetadata.append(metadataFor(assetIdentifier))
            writer.metadata = newMetadata
//            writer.metadata = [metadataFor(assetIdentifier)]
            
            // 配置视频输入
            let videoInput = AVAssetWriterInput(
                mediaType: .video,
                outputSettings: videoSettings(videoTrack.naturalSize)
            )
            videoInput.expectsMediaDataInRealTime = true
            videoInput.transform = videoTrack.preferredTransform
            
            guard writer.canAdd(videoInput) else {
                ShareAPI.shared().log(3, "错误: 无法添加视频输入")
                return
            }
            writer.add(videoInput)
            
            // 2. 处理音频轨道 - 可选逻辑
            let audioAsset = AVAsset(url: URL(fileURLWithPath: self.path))
            let audioTracks = audioAsset.tracks(withMediaType: .audio)
            let hasAudio = !audioTracks.isEmpty
            
            if hasAudio, let audioTrack = audioTracks.first {
                // 初始化音频写入输入
                audioWriterInput = AVAssetWriterInput(mediaType: .audio, outputSettings: nil)
                audioWriterInput?.expectsMediaDataInRealTime = false
                
                if let audioWriterInput = audioWriterInput, writer.canAdd(audioWriterInput) {
                    writer.add(audioWriterInput)
                } else {
                    ShareAPI.shared().log(3, "警告: 无法添加音频输入，将仅处理视频")
                    audioWriterInput = nil
                }
                
                // 初始化音频读取器
                do {
                    audioReader = try AVAssetReader(asset: audioAsset)
                } catch {
                    ShareAPI.shared().log(3, "警告: 初始化音频读取器失败: \(error)，将仅处理视频")
                    audioReader = nil
                    audioWriterInput = nil
                }
                
                // 配置音频读取输出
                if let audioReader = audioReader, let audioWriterInput = audioWriterInput {
                    audioReaderOutput = AVAssetReaderTrackOutput(track: audioTrack, outputSettings: nil)
                    
                    if let audioReaderOutput = audioReaderOutput, audioReader.canAdd(audioReaderOutput) {
                        audioReader.add(audioReaderOutput)
                    } else {
                        ShareAPI.shared().log(3, "警告: 无法添加音频输出，将仅处理视频")
//                        audioReader = nil
//                        audioWriterInput = nil
                        audioReaderOutput = nil
                    }
                }
            } else {
                ShareAPI.shared().log(3, "信息: 未检测到音频轨道，将仅处理视频")
            }
            
            // 3. 配置元数据适配器
            let metadataAdapter = self.metadataAdapter()
            writer.add(metadataAdapter.assetWriterInput)
            
            // 4. 开始写入流程
            guard writer.startWriting() else {
                ShareAPI.shared().log(3, "错误: 无法启动写入器: \(writer.error?.localizedDescription ?? "未知错误")")
                return
            }
            
            videoReader.startReading()
            writer.startSession(atSourceTime: CMTime.zero)
            
            // 写入静帧时间元数据
            metadataAdapter.append(AVTimedMetadataGroup(
                items: [metadataForStillImageTime()],
                timeRange: dummyTimeRange
            ))
            
            // 5. 处理视频数据写入
            let videoQueue = DispatchQueue(label: "com.example.videoWriterQueue")
            videoInput.requestMediaDataWhenReady(on: videoQueue) { [weak self] in
                guard let self = self else { return }
                
                while videoInput.isReadyForMoreMediaData {
                    switch videoReader.status {
                    case .reading:
                        if let sampleBuffer = videoOutput.copyNextSampleBuffer() {
                            if !videoInput.append(sampleBuffer) {
                                ShareAPI.shared().log(3, "错误: 视频写入失败: \(writer.error?.localizedDescription ?? "未知错误")")
                                videoReader.cancelReading()
                            }
                        }
                        
                    case .completed:
                        videoInput.markAsFinished()
                        ShareAPI.shared().log(1, "信息: 视频数据处理完成")
                        
                        // 处理音频写入（如果有音频）
                        if hasAudio, let audioReader = audioReader,
                           let audioWriterInput = audioWriterInput, let audioReaderOutput = audioReaderOutput {
                            self.handleAudioWriting(
                                audioReader: audioReader,
                                audioWriterInput: audioWriterInput,
                                audioReaderOutput: audioReaderOutput,
                                writer: writer
                            )
                        } else {
                            // 无音频，直接完成写入
                            writer.finishWriting {
                                if let error = writer.error {
                                    ShareAPI.shared().log(3, "错误: 视频写入完成但有错误: \(error.localizedDescription)")
                                } else {
                                    ShareAPI.shared().log(3, "信息: 视频写入成功")
                                }
                            }
                        }
                        return
                        
                    case .failed, .cancelled:
                        videoInput.markAsFinished()
                        writer.cancelWriting()
                        ShareAPI.shared().log(3, "错误: 视频读取失败: \(videoReader.error?.localizedDescription ?? "未知错误")")
                        return
                        
                    default:
                        break
                    }
                }
            }
            
            // 等待写入完成
            while writer.status == .writing {
                RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.1))
            }
            
        } catch {
            ShareAPI.shared().log(3, "错误: 写入过程发生错误: \(error.localizedDescription)")
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
            ShareAPI.shared().log(3, "错误: 无法启动音频读取器")
            audioWriterInput.markAsFinished()
            writer.finishWriting {
                ShareAPI.shared().log(3, "错误: 音频处理失败，视频已完成")
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
                            ShareAPI.shared().log(3, "错误: 音频写入失败: \(writer.error?.localizedDescription ?? "未知错误")")
                            audioReader.cancelReading()
                        }
                    }
                    
                case .completed:
                    audioWriterInput.markAsFinished()
                    ShareAPI.shared().log(3, "信息: 音频数据处理完成")
                    
                    writer.finishWriting {
                        if let error = writer.error {
                            ShareAPI.shared().log(3, "错误: 写入完成但有错误: \(error.localizedDescription)")
                        } else {
                            ShareAPI.shared().log(3, "信息: 音视频写入成功")
                        }
                    }
                    return
                    
                case .failed, .cancelled:
                    audioWriterInput.markAsFinished()
                    writer.cancelWriting()
                    ShareAPI.shared().log(3, "错误: 音频读取失败: \(audioReader.error?.localizedDescription ?? "未知错误")")
                    return
                    
                default:
                    break
                }
            }
        }
    }

    // 其他辅助方法保持不变
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

/*
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
        if let track = track(AVMediaType.video) {
            let (reader, output) = try! self.reader(track, settings: nil)
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
        }
        return nil
    }

    func write(_ dest: String, assetIdentifier: String) {
        
        var audioReader: AVAssetReader? = nil
        var audioWriterInput: AVAssetWriterInput? = nil
        var audioReaderOutput: AVAssetReaderOutput? = nil
        do {
            guard let track = self.track(AVMediaType.video) else {
                print("not found video track")
                return
            }
            let (reader, output) = try self.reader(track, settings: [kCVPixelBufferPixelFormatTypeKey as String: NSNumber(value: kCVPixelFormatType_32BGRA as UInt32)])
            
            let writer = try AVAssetWriter(outputURL: URL(fileURLWithPath: dest), fileType: .mov)
            writer.metadata = [metadataFor(assetIdentifier)]
            
            let input = AVAssetWriterInput(mediaType: .video,
                                           outputSettings: videoSettings(track.naturalSize))
            input.expectsMediaDataInRealTime = true
            input.transform = track.preferredTransform
            writer.add(input)
            
            
            let url = URL(fileURLWithPath: self.path)
            let aAudioAsset: AVAsset = AVAsset(url: url)
            
            if aAudioAsset.tracks.count > 1 {
                print("Has Audio")
                audioWriterInput = AVAssetWriterInput(mediaType: .audio, outputSettings: nil)
                
                audioWriterInput?.expectsMediaDataInRealTime = false
                if writer.canAdd(audioWriterInput!){
                    writer.add(audioWriterInput!)
                }
                
                guard let audioTrack: AVAssetTrack = aAudioAsset.tracks(withMediaType: .audio).first else {
                    print("未包含音频")
                    return
                }
                audioReaderOutput = AVAssetReaderTrackOutput(track: audioTrack, outputSettings: nil)
                
                do{
                    audioReader = try AVAssetReader(asset: aAudioAsset)
                }catch{
                    fatalError("Unable to read Asset: \(error) : ")
                }
                if (audioReader?.canAdd(audioReaderOutput!))! {
                    audioReader?.add(audioReaderOutput!)
                } else {
                    print("cant add audio reader")
                }
            }
            
            let adapter = metadataAdapter()
            writer.add(adapter.assetWriterInput)
            
            writer.startWriting()
            reader.startReading()
            writer.startSession(atSourceTime: CMTime.zero)
            
            adapter.append(AVTimedMetadataGroup(items: [metadataForStillImageTime()],
                                                timeRange: dummyTimeRange))
            
            input.requestMediaDataWhenReady(on: DispatchQueue(label: "assetVideoWriterQueue", attributes: [])) {
                while(input.isReadyForMoreMediaData) {
                    if reader.status == .reading {
                        if let buffer = output.copyNextSampleBuffer() {
                            if !input.append(buffer) {
                                print("cannot write: \((writer.error?.localizedDescription) ?? "")")
                                reader.cancelReading()
                            }
                        }
                    } else {
                        input.markAsFinished()
                        if reader.status == .completed && aAudioAsset.tracks.count > 1 {
                            audioReader?.startReading()
                            writer.startSession(atSourceTime: CMTime.zero)
                            let mediaQueue = DispatchQueue(label: "assetAudioWriterQueue", attributes: [])
                            audioWriterInput?.requestMediaDataWhenReady(on: mediaQueue) {
                                while (audioWriterInput?.isReadyForMoreMediaData)! {
                                    let sampleBuffer2: CMSampleBuffer? = audioReaderOutput?.copyNextSampleBuffer()
                                    if audioReader?.status == .reading && sampleBuffer2 != nil {
                                        if !(audioWriterInput?.append(sampleBuffer2!))! {
                                            audioReader?.cancelReading()
                                        }
                                    }else {
                                        audioWriterInput?.markAsFinished()
                                        print("Audio writer finish")
                                        writer.finishWriting() {
                                            if let e = writer.error {
                                                print("cannot write: \(e)")
                                            } else {
                                                print("finish writing.")
                                            }
                                        }
                                    }
                                }
                            }
                        }
                        else {
                            print("Video Reader not completed")
                            writer.finishWriting() {
                                if let e = writer.error {
                                    print("cannot write: \(e)")
                                } else {
                                    print("finish writing.")
                                }
                            }
                        }
                    }
                }
            }
            while writer.status == .writing {
                RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.5))
            }
            if let e = writer.error {
                print("cannot write: \(e)")
            }
        } catch {
            print("error")
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
            "com.apple.metadata.datatype.int8"            ]

        var desc: CMFormatDescription? = nil
        
        CMMetadataFormatDescriptionCreateWithMetadataSpecifications(allocator: kCFAllocatorDefault, metadataType: kCMMetadataFormatType_Boxed, metadataSpecifications: [spec] as CFArray, formatDescriptionOut: &desc)
        let input = AVAssetWriterInput(mediaType: .metadata,
            outputSettings: nil, sourceFormatHint: desc)
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
*/
