//
//  TranscodeMedia.m
//  MutualInfectionApp
//
//  Created by mac on 2025/10/27.
//
#include "TranscodeMedia.h"
// 条件编译导入平台特定框架
// 在 .mm 文件顶部添加这些定义
#import <ImageIO/ImageIO.h>
#import <Photos/Photos.h>

#if TARGET_OS_IPHONE
#import <MobileCoreServices/MobileCoreServices.h>
#else
#import <CoreServices/CoreServices.h>
#endif
#include "LogHelper.h"

// 如果仍然缺少常量，手动定义它们
#ifndef kUTTypeHEIC
#define kUTTypeHEIC CFSTR("public.heic")
#endif

#ifndef kCGImagePropertyContentIdentifier
#define kCGImagePropertyContentIdentifier CFSTR("17")
#endif

#ifndef AVMetadataQuickTimeUserDataKeyContentIdentifier
#define AVMetadataQuickTimeUserDataKeyContentIdentifier @"contentIdentifier"
#endif

#ifndef AVMetadataQuickTimeMetadataKeyMediaType
#define AVMetadataQuickTimeMetadataKeyMediaType @"com.apple.quicktime.media-type"
#endif

#ifndef AVMetadataQuickTimeMetadataKeyStillImageTime
#define AVMetadataQuickTimeMetadataKeyStillImageTime @"com.apple.quicktime.still-image-time"
#endif

#ifndef AVMetadataQuickTimeMetadataKeyDirection
#define AVMetadataQuickTimeMetadataKeyDirection @"com.apple.quicktime.direction"
#endif

TranscodeMedia::TranscodeMedia() {};


TranscodeMedia &TranscodeMedia::Instance()
{
    static TranscodeMedia instance;
    return instance;
}

AVURLAsset* TranscodeMedia::createAssetSafely(NSString* path) {
    @autoreleasepool {
        if (!path) return nil;
        
        NSString* fullPath = path;
        if (![path hasPrefix:@"/"]) {
            NSString* documentsPath = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) firstObject];
            fullPath = [documentsPath stringByAppendingPathComponent:path];
        }
        
        if (![[NSFileManager defaultManager] fileExistsAtPath:fullPath]) {
            return nil;
        }
        
        NSURL* fileURL = [NSURL fileURLWithPath:fullPath];
        return [AVURLAsset URLAssetWithURL:fileURL options:nil];
    }
}

/*!
 * @function       checkVideoCodecSupport
 * @abstract       检查视频编码格式的兼容性
 * @discussion     此函数用于检测视频文件的编码格式，判断是否在 iOS 13+ 设备上可播放，
 *                 并提供详细的兼容性信息和所有检测到的编码格式列表。
 *
 * @param          videoPath
 *                 输入视频文件的完整路径
 * @param          isSupported
 *                 输出参数，表示视频编码是否在 iOS 13+ 上支持播放
 *                 - true:  编码格式兼容，可直接播放
 *                 - false: 编码格式不兼容，需要转码
 * @param          reason
 *                 输出参数，详细的兼容性说明或错误信息
 *                 - 支持时: 显示支持的编码格式和特性
 *                 - 不支持时: 说明不兼容的原因和建议
 * @param          allCodecs
 *                 输出参数，视频文件中检测到的所有编码格式列表
 *                 - 包含视频、音频等所有流的编码信息
 *                 - 用于调试和多轨道视频分析
 *
 * @result         函数执行是否成功
 *                 - true:  检测完成，输出参数有效
 *                 - false: 检测失败，请检查 reason 中的错误信息
 *
 * @note 支持的编码格式:
 *   完全支持: H.264 (avc1), HEVC (hvc1), MPEG-4
 *   条件支持: HEVC (需要 iOS 11.0+), AV1 (需要 iOS 16.0+)
 *   不支持: 其他非标准或专业编码格式
 */
bool TranscodeMedia::checkVideoCodecSupport(const std::string &videoPath, bool &isSupported, std::string &reason, std::vector<std::string> &allCodecs)
{
    isSupported = false;
    reason.clear();
    allCodecs.clear();
    
    @autoreleasepool {
        AVURLAsset* asset = createAssetSafely([NSString stringWithUTF8String:videoPath.c_str()]);
        if (!asset) {
            reason = "Failed to create asset";
            LOG_ERROR_S("Failed to create asset for video: %s", videoPath.c_str());
            return false;
        }
        
        // Wait for asset loading
        __block BOOL loaded = NO;
        [asset loadValuesAsynchronouslyForKeys:@[@"tracks"] completionHandler:^{
            loaded = YES;
        }];
        
        NSDate* timeout = [NSDate dateWithTimeIntervalSinceNow:5.0];
        while (!loaded && [[NSDate date] compare:timeout] == NSOrderedAscending) {
            [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.1]];
        }
        
        // Get video tracks
        NSArray* videoTracks = [asset tracksWithMediaType:AVMediaTypeVideo];
        if (videoTracks.count == 0) {
            reason = "No video tracks found";
            LOG_ERROR_S("No video tracks found in asset: %s", videoPath.c_str());
            return false;
        }
        
        AVAssetTrack* videoTrack = videoTracks.firstObject;
        NSArray* formatDescriptions = [videoTrack formatDescriptions];
        
        if (formatDescriptions.count == 0) {
            reason = "No format descriptions";
            LOG_ERROR_S("No format descriptions available for video track");
            return false;
        }
        
        // Collect all codec information
        for (NSUInteger i = 0; i < formatDescriptions.count; i++) {
            CMFormatDescriptionRef formatDesc = (__bridge CMFormatDescriptionRef)formatDescriptions[i];
            FourCharCode codecType = CMFormatDescriptionGetMediaSubType(formatDesc);
            
            char codecStr[5];
            codecStr[0] = (codecType >> 24) & 0xFF;
            codecStr[1] = (codecType >> 16) & 0xFF;
            codecStr[2] = (codecType >> 8) & 0xFF;
            codecStr[3] = codecType & 0xFF;
            codecStr[4] = '\0';
            
            allCodecs.push_back(std::string(codecStr));
        }
        
        // Use first format description for primary judgment
        CMFormatDescriptionRef primaryFormatDesc = (__bridge CMFormatDescriptionRef)formatDescriptions.firstObject;
        FourCharCode primaryCodecType = CMFormatDescriptionGetMediaSubType(primaryFormatDesc);
        
        char primaryCodecStr[5];
        primaryCodecStr[0] = (primaryCodecType >> 24) & 0xFF;
        primaryCodecStr[1] = (primaryCodecType >> 16) & 0xFF;
        primaryCodecStr[2] = (primaryCodecType >> 8) & 0xFF;
        primaryCodecStr[3] = primaryCodecType & 0xFF;
        primaryCodecStr[4] = '\0';
        
        LOG_INFO("Primary video codec: '%s'", primaryCodecStr);
        LOG_DEBUG_S("Total codecs found: %zu", allCodecs.size());
        
        // Judgment logic
        switch (primaryCodecType) {
            case kCMVideoCodecType_H264:
                isSupported = true;
                reason = "H.264 codec, supported on all platforms";
                LOG_INFO("H.264 codec detected - fully supported");
                break;
                
            case kCMVideoCodecType_HEVC:
                if (@available(iOS 11.0, *)) {
                    isSupported = true;
                    reason = "HEVC codec, iOS 11.0+ supported";
                    LOG_INFO("HEVC codec detected - supported (iOS 11.0+)");
                } else {
                    isSupported = false;
                    reason = "HEVC codec requires iOS 11.0+";
                    LOG_ERROR_S("HEVC codec detected but requires iOS 11.0+");
                }
                break;
                
            case kCMVideoCodecType_AV1:
                if (@available(iOS 16.0, *)) {
                    isSupported = true;
                    reason = "AV1 codec, iOS 16.0+ supported";
                    LOG_INFO("AV1 codec detected - supported (iOS 16.0+)");
                } else {
                    isSupported = false;
                    reason = "AV1 codec requires iOS 16.0+";
                    LOG_ERROR_S("AV1 codec detected but requires iOS 16.0+");
                }
                break;
                
            case kCMVideoCodecType_MPEG4Video:
                isSupported = true;
                reason = "MPEG-4 codec, basic support";
                LOG_INFO("MPEG-4 codec detected - basic support");
                break;
                
            case kCMVideoCodecType_JPEG:
                isSupported = true;
                reason = "Motion JPEG codec";
                LOG_INFO("Motion JPEG codec detected - supported");
                break;
                
            case kCMVideoCodecType_AppleProRes422:
            case kCMVideoCodecType_AppleProRes4444:
                isSupported = true;
                reason = "ProRes codec, requires high-performance device";
                LOG_INFO("ProRes codec detected - requires high-performance device");
                break;
                
            default:
                isSupported = false;
                reason = "Unsupported video codec format: " + std::string(primaryCodecStr);
                LOG_ERROR_S("Unsupported video codec format: %s", primaryCodecStr);
                break;
        }
        
        LOG_INFO("Video codec support check completed - supported: %s, reason: %s",
                 isSupported ? "true" : "false", reason.c_str());
        return true;
    }
}

void TranscodeMedia::convertToHVC1(const std::string &videoPath, std::string &outputPath, std::function<void(bool)> completion) {
    @autoreleasepool {
        // Auto-generate output path if not provided
        if (outputPath.empty()) {
            LOG_ERROR_S("Output path is empty");
            completion(false);
            return;
        }
        
        // Convert paths to NSURL
        NSString* inputNsPath = [NSString stringWithUTF8String:videoPath.c_str()];
        NSString* outputNsPath = [NSString stringWithUTF8String:outputPath.c_str()];
        NSURL* outputURL = [NSURL fileURLWithPath:outputNsPath];
        
        LOG_INFO("Starting HVC1 conversion - input: %s, output: %s", videoPath.c_str(), outputPath.c_str());
        
        VideoOrientation videoOrientation = getVideoOrientation(videoPath);
        LOG_DEBUG_S("Video orientation detected: %d", videoOrientation);
        
        AVURLAsset* asset = createAssetSafely(inputNsPath);
        if (asset) {
            // Step 1: First perform HVC1 conversion
            LOG_INFO("Starting HVC1 conversion process");
            convertEntireVideoToHVC1(asset, outputURL, [this, outputURL, videoOrientation, completion](bool success) {
                if (success) {
                #if TARGET_OS_MAC
                        // Only perform rotation on macOS
                        if (videoOrientation == ORIENTATION_PORTRAIT) {
                            LOG_INFO("Starting video rotation on macOS for portrait video");
                            this->rotateVideoAfterConversion(outputURL, completion);
                        } else {
                            LOG_INFO("HVC1 conversion completed successfully, no rotation needed");
                            completion(true);
                        }
                #else
                        // Complete directly on iOS, no rotation
                        LOG_INFO("HVC1 conversion completed on iOS, skipping rotation");
                        completion(true);
                #endif
                    } else {
                        LOG_ERROR_S("HVC1 conversion failed");
                        completion(false);
                    }
            });
        }
        else
        {
            LOG_ERROR_S("Asset creation failed for video: %s", videoPath.c_str());
            completion(false);
        }
    }
}

void TranscodeMedia::rotateVideoAfterConversion(NSURL *videoURL, std::function<void(bool)> completion) {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        @autoreleasepool {
            LOG_INFO("Starting precise lossless video rotation: %s", [[videoURL path] UTF8String]);
            
            if (![[NSFileManager defaultManager] fileExistsAtPath:[videoURL path]]) {
                LOG_ERROR_S("Input file does not exist: %s", [[videoURL path] UTF8String]);
                completion(false);
                return;
            }
            
            const char *input_path = [[videoURL path] UTF8String];
            
            // Create temporary file
            NSString *tempPath = [NSTemporaryDirectory() stringByAppendingPathComponent:
                                [NSString stringWithFormat:@"rotate_meta_%@.mov", [[NSUUID UUID] UUIDString]]];
            const char *output_path = [tempPath UTF8String];
            
            LOG_DEBUG_S("Temporary output path: %s", output_path);
            
            AVFormatContext *input_ctx = nullptr;
            AVFormatContext *output_ctx = nullptr;
            int ret = 0;
            
            // Open input file
            ret = avformat_open_input(&input_ctx, input_path, nullptr, nullptr);
            if (ret < 0) {
                LOG_ERROR_S("Failed to open input file: %d", ret);
                completion(false);
                return;
            }
            
            // Get stream information
            ret = avformat_find_stream_info(input_ctx, nullptr);
            if (ret < 0) {
                LOG_ERROR_S("Failed to get stream info: %d", ret);
                avformat_close_input(&input_ctx);
                completion(false);
                return;
            }
            
            LOG_INFO("Input format: %s", input_ctx->iformat->name ? input_ctx->iformat->name : "unknown");
            
            // Use same format as input
            const AVOutputFormat *output_format = input_ctx->oformat ? input_ctx->oformat : av_guess_format("mov", nullptr, nullptr);
            if (!output_format) {
                LOG_ERROR_S("Failed to determine output format");
                avformat_close_input(&input_ctx);
                completion(false);
                return;
            }
            
            LOG_INFO("Output format: %s", output_format->name ? output_format->name : "unknown");
            
            // Create output context
            ret = avformat_alloc_output_context2(&output_ctx, nullptr, output_format->name, output_path);
            if (ret < 0 || !output_ctx) {
                LOG_ERROR_S("Failed to create output context: %d", ret);
                avformat_close_input(&input_ctx);
                completion(false);
                return;
            }
            
            // Copy global metadata
            av_dict_copy(&output_ctx->metadata, input_ctx->metadata, 0);
            
            // Precisely copy all streams
            for (unsigned int i = 0; i < input_ctx->nb_streams; i++) {
                AVStream *in_stream = input_ctx->streams[i];
                AVStream *out_stream = avformat_new_stream(output_ctx, nullptr);
                if (!out_stream) {
                    LOG_ERROR_S("Failed to create output stream for index: %d", i);
                    continue;
                }
                
                // Precisely copy codec parameters
                ret = avcodec_parameters_copy(out_stream->codecpar, in_stream->codecpar);
                if (ret < 0) {
                    LOG_ERROR_S("Failed to copy codec parameters for stream %d: %d", i, ret);
                    continue;
                }
                
                // Precisely copy all stream properties
                out_stream->time_base = in_stream->time_base;
                out_stream->avg_frame_rate = in_stream->avg_frame_rate;
                out_stream->r_frame_rate = in_stream->r_frame_rate;
                out_stream->sample_aspect_ratio = in_stream->sample_aspect_ratio;
                out_stream->start_time = in_stream->start_time;
                out_stream->duration = in_stream->duration;
                out_stream->nb_frames = in_stream->nb_frames;
                
                // For HEVC video, ensure all extension data is copied
                if (in_stream->codecpar->codec_id == AV_CODEC_ID_HEVC) {
                    LOG_DEBUG_S("Detected HEVC encoded video stream");
                }
                
                // Copy all metadata
                av_dict_copy(&out_stream->metadata, in_stream->metadata, 0);
                
                // Only modify rotation metadata for video streams
                if (in_stream->codecpar->codec_type == AVMEDIA_TYPE_VIDEO) {
                    // Set rotation flag to 90 degrees
                    av_dict_set(&out_stream->metadata, "rotate", "90", 0);
                    LOG_INFO("Set rotation metadata to 90 degrees for video stream");
                    
                    LOG_DEBUG_S("Video codec: %s", avcodec_get_name(in_stream->codecpar->codec_id));
                    LOG_DEBUG_S("Video dimensions: %dx%d", in_stream->codecpar->width, in_stream->codecpar->height);
                    LOG_DEBUG_S("Time base: %d/%d", in_stream->time_base.num, in_stream->time_base.den);
                    
                    // Record original bitrate information
                    if (in_stream->codecpar->bit_rate > 0) {
                        LOG_DEBUG_S("Original bitrate: %d bps", in_stream->codecpar->bit_rate);
                    }
                }
            }
            
            // Open output file
            if (!(output_ctx->oformat->flags & AVFMT_NOFILE)) {
                ret = avio_open(&output_ctx->pb, output_path, AVIO_FLAG_WRITE);
                if (ret < 0) {
                    LOG_ERROR_S("Failed to open output file: %d", ret);
                    avformat_close_input(&input_ctx);
                    avformat_free_context(output_ctx);
                    completion(false);
                    return;
                }
            }
            
            // Set precise copy flag
            output_ctx->flags |= AVFMT_FLAG_BITEXACT;
            
            // Write file header - use same options as input
            AVDictionary *opts = nullptr;
            // For MOV format, use same container options as input
            av_dict_set(&opts, "movflags", "frag_keyframe+empty_moov+default_base_moof", 0);
            
            ret = avformat_write_header(output_ctx, &opts);
            if (ret < 0) {
                LOG_ERROR_S("Failed to write file header: %d", ret);
                av_dict_free(&opts);
                avformat_close_input(&input_ctx);
                if (!(output_ctx->oformat->flags & AVFMT_NOFILE)) {
                    avio_closep(&output_ctx->pb);
                }
                avformat_free_context(output_ctx);
                completion(false);
                return;
            }
            av_dict_free(&opts);
            
            LOG_INFO("File header written successfully, starting data copy...");
            
            // Copy all packets
            AVPacket packet;
            av_init_packet(&packet);
            
            int64_t total_size = 0;
            int frame_count = 0;
            
            while (av_read_frame(input_ctx, &packet) >= 0) {
                AVStream *in_stream = input_ctx->streams[packet.stream_index];
                AVStream *out_stream = output_ctx->streams[packet.stream_index];
                
                // Precisely copy packet, preserving all original information
                packet.pts = av_rescale_q(packet.pts, in_stream->time_base, out_stream->time_base);
                packet.dts = av_rescale_q(packet.dts, in_stream->time_base, out_stream->time_base);
                packet.duration = av_rescale_q(packet.duration, in_stream->time_base, out_stream->time_base);
                packet.pos = -1;
                packet.stream_index = out_stream->index;
                
                // Preserve all original flags
                packet.flags = packet.flags;
                
                total_size += packet.size;
                if (packet.stream_index == 0) { // Assume video stream is first
                    frame_count++;
                }
                
                ret = av_interleaved_write_frame(output_ctx, &packet);
                if (ret < 0) {
                    LOG_ERROR_S("Failed to write packet: %d", ret);
                    av_packet_unref(&packet);
                    break;
                }
                av_packet_unref(&packet);
            }
            
            // Write file trailer
            av_write_trailer(output_ctx);
            
            LOG_INFO("FFmpeg processing completed");
            LOG_DEBUG_S("Processing statistics: %d video frames, %lld bytes data", frame_count, total_size);
            
            // Clean up resources
            avformat_close_input(&input_ctx);
            if (!(output_ctx->oformat->flags & AVFMT_NOFILE)) {
                avio_closep(&output_ctx->pb);
            }
            avformat_free_context(output_ctx);
            
            // Verify and replace file
            if ([[NSFileManager defaultManager] fileExistsAtPath:tempPath]) {
                NSDictionary *attrs = [[NSFileManager defaultManager] attributesOfItemAtPath:tempPath error:nil];
                int64_t output_size = [attrs[NSFileSize] longLongValue];
                LOG_DEBUG_S("Output file size: %lld bytes", output_size);
                
                // Check original file size
                NSDictionary *inputAttrs = [[NSFileManager defaultManager] attributesOfItemAtPath:[videoURL path] error:nil];
                int64_t input_size = [inputAttrs[NSFileSize] longLongValue];
                LOG_DEBUG_S("Input file size: %lld bytes", input_size);
                LOG_DEBUG_S("Size change: %lld bytes", (output_size - input_size));
                
                // Replace original file with temporary file
                NSFileManager *fileManager = [NSFileManager defaultManager];
                NSError *error = nil;
                
                [fileManager removeItemAtURL:videoURL error:&error];
                [fileManager moveItemAtURL:[NSURL fileURLWithPath:tempPath] toURL:videoURL error:&error];
                
                if (error) {
                    LOG_ERROR_S("File replacement failed: %s", [[error localizedDescription] UTF8String]);
                    completion(false);
                } else {
                    LOG_INFO("Rotation metadata modification completed successfully");
                    completion(true);
                }
            } else {
                LOG_ERROR_S("Output file does not exist at path: %s", [tempPath UTF8String]);
                completion(false);
            }
        }
    });
}

std::string TranscodeMedia::generateOutputPath(const std::string &inputPath) {
    @autoreleasepool {
        // 从输入路径提取文件名（不含扩展名）
        NSString* inputNsPath = [NSString stringWithUTF8String:inputPath.c_str()];
        NSString* fileName = [[inputNsPath lastPathComponent] stringByDeletingPathExtension];
        
        // 获取文档目录
        NSArray* paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
        NSString* documentsDir = [paths firstObject];
        
        // 生成输出路径：文档目录/原文件名_hvc1.mov
        NSString* outputFileName = [NSString stringWithFormat:@"%@_hvc1.mov", fileName];
        NSString* outputNsPath = [documentsDir stringByAppendingPathComponent:outputFileName];
        
        return [outputNsPath UTF8String];
    }
}

void TranscodeMedia::convertEntireVideoToHVC1(AVAsset* asset, NSURL* outputURL, std::function<void(bool)> completion)
{
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        AVFormatContext *input_ctx = NULL;
        AVFormatContext *output_ctx = NULL;
        AVCodecContext *video_dec_ctx = NULL, *video_enc_ctx = NULL;
        AVStream *video_stream = NULL;
        AVStream *out_stream = NULL;
        const AVCodec *video_decoder = NULL, *video_encoder = NULL;
        
        int video_stream_idx = -1;
        int ret = 0;
        
        LOG_INFO("Starting HVC1 conversion process");
        
        if ([asset isKindOfClass:[AVURLAsset class]]) {
            AVURLAsset *urlAsset = (AVURLAsset *)asset;
            NSURL *sourceURL = [urlAsset URL];
            const char *input_filename = [[sourceURL path] UTF8String];
            
            LOG_INFO("Source file: %s", input_filename);
            
            // Open input file
            if (avformat_open_input(&input_ctx, input_filename, NULL, NULL) < 0) {
                LOG_ERROR_S("Failed to open input file");
                dispatch_async(dispatch_get_main_queue(), ^{
                    completion(false);
                });
                return;
            }
            
            if (avformat_find_stream_info(input_ctx, NULL) < 0) {
                LOG_ERROR_S("Failed to get stream information");
                avformat_close_input(&input_ctx);
                dispatch_async(dispatch_get_main_queue(), ^{
                    completion(false);
                });
                return;
            }
            
            // Find video stream
            for (int i = 0; i < input_ctx->nb_streams; i++) {
                if (input_ctx->streams[i]->codecpar->codec_type == AVMEDIA_TYPE_VIDEO) {
                    video_stream_idx = i;
                    video_stream = input_ctx->streams[i];
                    LOG_INFO("Found video stream: %d, codec: %s, dimensions: %dx%d",
                            i,
                            avcodec_get_name(video_stream->codecpar->codec_id),
                            video_stream->codecpar->width,
                            video_stream->codecpar->height);
                    break;
                }
            }
            
            if (video_stream_idx == -1) {
                LOG_ERROR_S("No video stream found");
                avformat_close_input(&input_ctx);
                dispatch_async(dispatch_get_main_queue(), ^{
                    completion(false);
                });
                return;
            }
            
            int64_t original_bit_rate = 0;
                    
            // Method 1: Get from codecpar
            if (video_stream->codecpar->bit_rate > 0) {
                original_bit_rate = video_stream->codecpar->bit_rate;
                LOG_DEBUG_S("Using codecpar bit_rate: %lld", original_bit_rate);
            }
            
            // Initialize video decoder
            video_decoder = avcodec_find_decoder(video_stream->codecpar->codec_id);
            if (!video_decoder) {
                LOG_ERROR_S("Decoder not found for codec: %s", avcodec_get_name(video_stream->codecpar->codec_id));
                avformat_close_input(&input_ctx);
                dispatch_async(dispatch_get_main_queue(), ^{
                    completion(false);
                });
                return;
            }
            
            video_dec_ctx = avcodec_alloc_context3(video_decoder);
            avcodec_parameters_to_context(video_dec_ctx, video_stream->codecpar);
            
            if (avcodec_open2(video_dec_ctx, video_decoder, NULL) < 0) {
                LOG_ERROR_S("Failed to open decoder");
                avcodec_free_context(&video_dec_ctx);
                avformat_close_input(&input_ctx);
                dispatch_async(dispatch_get_main_queue(), ^{
                    completion(false);
                });
                return;
            }
           
            // If decoder context has better bitrate information, use it
            if (video_dec_ctx->bit_rate > 0 && video_dec_ctx->bit_rate > original_bit_rate) {
                original_bit_rate = video_dec_ctx->bit_rate;
                LOG_DEBUG_S("Using decoder context bit_rate: %lld", original_bit_rate);
            }
            
            // Initialize output format context
            const char *output_filename = [[outputURL path] UTF8String];
            LOG_INFO("Output file: %s", output_filename);
            
            // Remove existing output file
            [[NSFileManager defaultManager] removeItemAtURL:outputURL error:nil];
            
            if (avformat_alloc_output_context2(&output_ctx, NULL, "mp4", output_filename) < 0) {
                LOG_ERROR_S("Failed to create MP4 output context");
                avcodec_free_context(&video_dec_ctx);
                avformat_close_input(&input_ctx);
                dispatch_async(dispatch_get_main_queue(), ^{
                    completion(false);
                });
                return;
            }
            
            // Create HEVC encoder - try VideoToolbox first
            bool use_videotoolbox = true;
            video_encoder = avcodec_find_encoder_by_name("hevc_videotoolbox");
            if (!video_encoder) {
                video_encoder = avcodec_find_encoder(AV_CODEC_ID_HEVC);
                use_videotoolbox = false;
                LOG_INFO("Using software HEVC encoder");
            } else {
                LOG_INFO("Using VideoToolbox HEVC encoder");
            }
            
            if (!video_encoder) {
                LOG_ERROR_S("HEVC encoder not found");
                avformat_free_context(output_ctx);
                avcodec_free_context(&video_dec_ctx);
                avformat_close_input(&input_ctx);
                dispatch_async(dispatch_get_main_queue(), ^{
                    completion(false);
                });
                return;
            }
            
            out_stream = avformat_new_stream(output_ctx, NULL);
            if (!out_stream) {
                LOG_ERROR_S("Failed to create output stream");
                avformat_free_context(output_ctx);
                avcodec_free_context(&video_dec_ctx);
                avformat_close_input(&input_ctx);
                dispatch_async(dispatch_get_main_queue(), ^{
                    completion(false);
                });
                return;
            }
            
            video_enc_ctx = avcodec_alloc_context3(video_encoder);
            
            // Configure encoder parameters
            video_enc_ctx->height = video_dec_ctx->height;
            video_enc_ctx->width = video_dec_ctx->width;
            video_enc_ctx->sample_aspect_ratio = video_dec_ctx->sample_aspect_ratio;
            video_enc_ctx->pix_fmt = AV_PIX_FMT_YUV420P;
            video_enc_ctx->time_base = video_stream->time_base;

            LOG_DEBUG_S("Encoder dimensions: %dx%d", video_enc_ctx->width, video_enc_ctx->height);
            
            // Set frame rate - directly from input stream
            if (video_stream->avg_frame_rate.num > 0 && video_stream->avg_frame_rate.den > 0) {
                video_enc_ctx->framerate = video_stream->avg_frame_rate;
                LOG_DEBUG_S("Set encoder frame rate: %.2f fps", av_q2d(video_stream->avg_frame_rate));
            } else if (video_stream->r_frame_rate.num > 0 && video_stream->r_frame_rate.den > 0) {
                video_enc_ctx->framerate = video_stream->r_frame_rate;
                LOG_DEBUG_S("Set encoder frame rate: %.2f fps", av_q2d(video_stream->r_frame_rate));
            } else {
                video_enc_ctx->framerate = (AVRational){25, 1};
                LOG_DEBUG_S("Using default frame rate: 25 fps");
            }
            
            video_enc_ctx->color_range = video_dec_ctx->color_range;
            video_enc_ctx->colorspace = video_dec_ctx->colorspace;
            video_enc_ctx->color_primaries = video_dec_ctx->color_primaries;
            video_enc_ctx->color_trc = video_dec_ctx->color_trc;
            video_enc_ctx->gop_size = 12;

            // Enhanced bitrate control
            if (original_bit_rate > 0) {
                video_enc_ctx->bit_rate = original_bit_rate * 1.2;
            } else {
                video_enc_ctx->bit_rate = 8000000;  // 8 Mbps default
            }

            video_enc_ctx->rc_max_rate = video_enc_ctx->bit_rate;
            video_enc_ctx->rc_min_rate = video_enc_ctx->bit_rate;
            video_enc_ctx->rc_buffer_size = video_enc_ctx->bit_rate;

            LOG_DEBUG_S("Encoder bitrate: %lld, max: %lld, min: %lld",
                     video_enc_ctx->bit_rate, video_enc_ctx->rc_max_rate, video_enc_ctx->rc_min_rate);
            
            out_stream->time_base = video_enc_ctx->time_base;
            
            // Open encoder
            AVDictionary *encoder_options = NULL;
            av_dict_set(&encoder_options, "profile", "main", 0);
            av_dict_set(&encoder_options, "preset", "medium", 0);
            av_dict_set(&encoder_options, "movflags", "faststart", 0);
            
            if (use_videotoolbox) {
                av_dict_set(&encoder_options, "pix_fmt", "nv12", 0);
                av_dict_set(&encoder_options, "allow_sw", "1", 0);
            } else {
                av_dict_set(&encoder_options, "pix_fmt", "yuv420p", 0);
            }
            
            bool encoder_opened = false;
            
            if (avcodec_open2(video_enc_ctx, video_encoder, &encoder_options) < 0) {
                LOG_INFO("VideoToolbox encoder failed, trying software encoder");
                
                // Fallback to software encoder
                av_dict_free(&encoder_options);
                avcodec_free_context(&video_enc_ctx);
                
                video_encoder = avcodec_find_encoder(AV_CODEC_ID_HEVC);
                if (video_encoder) {
                    video_enc_ctx = avcodec_alloc_context3(video_encoder);
                    video_enc_ctx->height = video_dec_ctx->height;
                    video_enc_ctx->width = video_dec_ctx->width;
                    video_enc_ctx->sample_aspect_ratio = video_dec_ctx->sample_aspect_ratio;
                    video_enc_ctx->pix_fmt = AV_PIX_FMT_YUV420P;
                    video_enc_ctx->color_range = video_dec_ctx->color_range;
                    video_enc_ctx->colorspace = video_dec_ctx->colorspace;
                    video_enc_ctx->color_primaries = video_dec_ctx->color_primaries;
                    video_enc_ctx->color_trc = video_dec_ctx->color_trc;
                    video_enc_ctx->time_base = av_inv_q(video_stream->avg_frame_rate);
                    video_enc_ctx->framerate = video_stream->avg_frame_rate;
                    video_enc_ctx->gop_size = 12;
                    video_enc_ctx->bit_rate = video_dec_ctx->bit_rate;
                    
                    av_dict_set(&encoder_options, "profile", "main", 0);
                    av_dict_set(&encoder_options, "preset", "medium", 0);
                    av_dict_set(&encoder_options, "movflags", "faststart", 0);
                    av_dict_set(&encoder_options, "pix_fmt", "yuv420p", 0);
                    
                    if (avcodec_open2(video_enc_ctx, video_encoder, &encoder_options) >= 0) {
                        encoder_opened = true;
                        LOG_INFO("Software HEVC encoder opened successfully");
                    }
                }
            } else {
                encoder_opened = true;
            }
            
            av_dict_free(&encoder_options);
            
            if (!encoder_opened) {
                LOG_ERROR_S("All encoder attempts failed");
                avcodec_free_context(&video_enc_ctx);
                avformat_free_context(output_ctx);
                avcodec_free_context(&video_dec_ctx);
                avformat_close_input(&input_ctx);
                dispatch_async(dispatch_get_main_queue(), ^{
                    completion(false);
                });
                return;
            }
            
            // Copy encoder parameters to output stream
            avcodec_parameters_from_context(out_stream->codecpar, video_enc_ctx);
            out_stream->time_base = video_enc_ctx->time_base;
            
            // Force set hvc1 codec tag
            out_stream->codecpar->codec_tag = MKTAG('h', 'v', 'c', '1');
            out_stream->duration = video_stream->duration;
            
            // Open output file
            if (avio_open(&output_ctx->pb, output_filename, AVIO_FLAG_WRITE) < 0) {
                LOG_ERROR_S("Failed to open output file for writing");
                avcodec_free_context(&video_enc_ctx);
                avformat_free_context(output_ctx);
                avcodec_free_context(&video_dec_ctx);
                avformat_close_input(&input_ctx);
                dispatch_async(dispatch_get_main_queue(), ^{
                    completion(false);
                });
                return;
            }
            
            // Write file header
            AVDictionary *format_options = NULL;
            av_dict_set(&format_options, "movflags", "faststart", 0);
            
            if (avformat_write_header(output_ctx, &format_options) < 0) {
                LOG_ERROR_S("Failed to write file header");
                av_dict_free(&format_options);
                avcodec_free_context(&video_enc_ctx);
                avformat_free_context(output_ctx);
                avcodec_free_context(&video_dec_ctx);
                avformat_close_input(&input_ctx);
                dispatch_async(dispatch_get_main_queue(), ^{
                    completion(false);
                });
                return;
            }
            av_dict_free(&format_options);
            
            AVPacket *packet = av_packet_alloc();
            AVFrame *frame = av_frame_alloc();
            AVFrame *converted_frame = NULL;
            int64_t frame_count = 0;
            int64_t next_pts = 0;
            
            // Create format conversion context
            struct SwsContext *sws_ctx = NULL;
            bool need_conversion = (video_dec_ctx->pix_fmt != video_enc_ctx->pix_fmt);
            
            if (need_conversion) {
                LOG_DEBUG_S("Pixel format conversion required: %s -> %s",
                         av_get_pix_fmt_name(video_dec_ctx->pix_fmt),
                         av_get_pix_fmt_name(video_enc_ctx->pix_fmt));
                
                sws_ctx = sws_getContext(
                    video_dec_ctx->width, video_dec_ctx->height, video_dec_ctx->pix_fmt,
                    video_enc_ctx->width, video_enc_ctx->height, video_enc_ctx->pix_fmt,
                    SWS_BICUBIC, NULL, NULL, NULL
                );
                
                if (!sws_ctx) {
                    LOG_ERROR_S("Failed to create pixel format conversion context");
                    av_packet_free(&packet);
                    av_frame_free(&frame);
                    avcodec_free_context(&video_enc_ctx);
                    avformat_free_context(output_ctx);
                    avcodec_free_context(&video_dec_ctx);
                    avformat_close_input(&input_ctx);
                    dispatch_async(dispatch_get_main_queue(), ^{
                        completion(false);
                    });
                    return;
                }
                
                converted_frame = av_frame_alloc();
                if (!converted_frame) {
                    LOG_ERROR_S("Failed to allocate conversion frame");
                    sws_freeContext(sws_ctx);
                    av_packet_free(&packet);
                    av_frame_free(&frame);
                    avcodec_free_context(&video_enc_ctx);
                    avformat_free_context(output_ctx);
                    avcodec_free_context(&video_dec_ctx);
                    avformat_close_input(&input_ctx);
                    dispatch_async(dispatch_get_main_queue(), ^{
                        completion(false);
                    });
                    return;
                }
                
                converted_frame->format = video_enc_ctx->pix_fmt;
                converted_frame->width = video_enc_ctx->width;
                converted_frame->height = video_enc_ctx->height;
                
                if (av_frame_get_buffer(converted_frame, 0) < 0) {
                    LOG_ERROR_S("Failed to pre-allocate conversion frame buffer");
                    av_frame_free(&converted_frame);
                    sws_freeContext(sws_ctx);
                    av_packet_free(&packet);
                    av_frame_free(&frame);
                    avcodec_free_context(&video_enc_ctx);
                    avformat_free_context(output_ctx);
                    avcodec_free_context(&video_dec_ctx);
                    avformat_close_input(&input_ctx);
                    dispatch_async(dispatch_get_main_queue(), ^{
                        completion(false);
                    });
                    return;
                }
            }
            
            LOG_INFO("Starting transcoding...");
            
            // Transcoding loop
            while (av_read_frame(input_ctx, packet) >= 0) {
                if (packet->stream_index == video_stream_idx) {
                    ret = avcodec_send_packet(video_dec_ctx, packet);
                    if (ret < 0) {
                        LOG_ERROR_S("Failed to send packet to decoder: %d", ret);
                        av_packet_unref(packet);
                        continue;
                    }
                    
                    while (true) {
                        ret = avcodec_receive_frame(video_dec_ctx, frame);
                        if (ret == AVERROR(EAGAIN) || ret == AVERROR_EOF) {
                            break;
                        } else if (ret < 0) {
                            LOG_ERROR_S("Failed to receive frame from decoder: %d", ret);
                            break;
                        }
                        
                        AVFrame *frame_to_encode = frame;

                        // Format conversion
                        if (need_conversion && sws_ctx && converted_frame) {
                            converted_frame->pts = frame->pts;
                            converted_frame->pkt_dts = frame->pkt_dts;
                            
                            sws_scale(sws_ctx,
                                     (const uint8_t* const*)frame->data, frame->linesize,
                                     0, frame->height,
                                     converted_frame->data, converted_frame->linesize);
                            
                            frame_to_encode = converted_frame;
                        }

                        // Process timestamps
                        frame_to_encode->pts = next_pts;
                        frame_to_encode->pkt_dts = next_pts;

                        AVRational frame_rate = video_enc_ctx->framerate;
                        if (frame_rate.num > 0 && frame_rate.den > 0) {
                            next_pts += av_rescale_q(1, (AVRational){frame_rate.den, frame_rate.num}, video_enc_ctx->time_base);
                        } else {
                            next_pts++;
                        }

                        // Send frame to encoder
                        ret = avcodec_send_frame(video_enc_ctx, frame_to_encode);
                        if (ret < 0) {
                            LOG_ERROR_S("Failed to send frame to encoder: %d", ret);
                        }
                        frame_count++;

                        // Process encoded packets
                        AVPacket *enc_packet = av_packet_alloc();
                        while (avcodec_receive_packet(video_enc_ctx, enc_packet) == 0) {
                            enc_packet->stream_index = out_stream->index;
                            enc_packet->pts = av_rescale_q(enc_packet->pts, video_enc_ctx->time_base, out_stream->time_base);
                            enc_packet->dts = av_rescale_q(enc_packet->dts, video_enc_ctx->time_base, out_stream->time_base);
                            enc_packet->duration = av_rescale_q(enc_packet->duration, video_enc_ctx->time_base, out_stream->time_base);
                            
                            ret = av_interleaved_write_frame(output_ctx, enc_packet);
                            if (ret < 0) {
                                LOG_ERROR_S("Failed to write frame: %d", ret);
                            }
                            av_packet_unref(enc_packet);
                        }
                        av_packet_free(&enc_packet);
                        
                        av_frame_unref(frame);
                    }
                }
                av_packet_unref(packet);
            }
            
            LOG_DEBUG_S("Decoded %lld frames", frame_count);

            // Flush decoder
            LOG_DEBUG_S("Flushing decoder to get delayed frames");
            avcodec_send_packet(video_dec_ctx, NULL);

            int flush_decoder_frames = 0;
            while (true) {
                ret = avcodec_receive_frame(video_dec_ctx, frame);
                if (ret == AVERROR_EOF) {
                    break;
                } else if (ret < 0 && ret != AVERROR(EAGAIN)) {
                    LOG_ERROR_S("Failed to flush decoder: %d", ret);
                    break;
                } else if (ret == 0) {
                    AVFrame *frame_to_encode = frame;
                    
                    // Format conversion
                    if (need_conversion && sws_ctx && converted_frame) {
                        converted_frame->pts = next_pts;
                        sws_scale(sws_ctx,
                                 (const uint8_t* const*)frame->data, frame->linesize,
                                 0, frame->height,
                                 converted_frame->data, converted_frame->linesize);
                        frame_to_encode = converted_frame;
                    } else {
                        frame_to_encode->pts = next_pts;
                    }
                    
                    ret = avcodec_send_frame(video_enc_ctx, frame_to_encode);
                    if (ret == 0) {
                        frame_count++;
                        flush_decoder_frames++;
                    }
                    
                    av_frame_unref(frame);
                    
                    // Update timestamp
                    AVRational frame_rate = video_enc_ctx->framerate;
                    if (frame_rate.num > 0 && frame_rate.den > 0) {
                        next_pts += av_rescale_q(1, (AVRational){frame_rate.den, frame_rate.num}, video_enc_ctx->time_base);
                    }
                }
            }

            // Flush encoder
            LOG_DEBUG_S("Flushing encoder to get delayed packets");
            avcodec_send_frame(video_enc_ctx, NULL);

            int flush_encoder_packets = 0;
            while (true) {
                AVPacket *enc_packet = av_packet_alloc();
                ret = avcodec_receive_packet(video_enc_ctx, enc_packet);
                
                if (ret == AVERROR_EOF) {
                    av_packet_free(&enc_packet);
                    break;
                } else if (ret < 0 && ret != AVERROR(EAGAIN)) {
                    LOG_ERROR_S("Failed to flush encoder: %d", ret);
                    av_packet_free(&enc_packet);
                    break;
                } else if (ret == 0) {
                    enc_packet->stream_index = out_stream->index;
                    enc_packet->pts = av_rescale_q(enc_packet->pts, video_enc_ctx->time_base, out_stream->time_base);
                    enc_packet->dts = av_rescale_q(enc_packet->dts, video_enc_ctx->time_base, out_stream->time_base);
                    enc_packet->duration = av_rescale_q(enc_packet->duration, video_enc_ctx->time_base, out_stream->time_base);
                    
                    ret = av_interleaved_write_frame(output_ctx, enc_packet);
                    if (ret < 0) {
                        LOG_ERROR_S("Failed to write delayed packet: %d", ret);
                    } else {
                        flush_encoder_packets++;
                    }
                    av_packet_unref(enc_packet);
                }
                av_packet_free(&enc_packet);
            }

            // Write file trailer
            av_write_trailer(output_ctx);
            
            LOG_INFO("Transcoding completed - Total frames: %lld, Decoder flush: %d, Encoder flush: %d",
                    frame_count, flush_decoder_frames, flush_encoder_packets);
            
            // Clean up resources
            if (sws_ctx) {
                sws_freeContext(sws_ctx);
            }
            if (converted_frame) {
                av_frame_free(&converted_frame);
            }
            av_packet_free(&packet);
            av_frame_free(&frame);
            avcodec_free_context(&video_enc_ctx);
            avcodec_free_context(&video_dec_ctx);
            avio_closep(&output_ctx->pb);
            avformat_free_context(output_ctx);
            avformat_close_input(&input_ctx);
            
            LOG_INFO("HVC1 conversion completed successfully");
            dispatch_async(dispatch_get_main_queue(), ^{
                completion(true);
            });
            
        } else {
            LOG_ERROR_S("Unsupported AVAsset type");
            dispatch_async(dispatch_get_main_queue(), ^{
                completion(false);
            });
        }
    });
}

VideoOrientation TranscodeMedia::getVideoOrientation(const std::string& videoPath) {
    AVFormatContext* fmt_ctx = nullptr;
    VideoOrientation orientation = ORIENTATION_LANDSCAPE;
    
    if (avformat_open_input(&fmt_ctx, videoPath.c_str(), nullptr, nullptr) < 0) {
        LOG_ERROR_S("Failed to open video file for orientation detection: %s", videoPath.c_str());
        return orientation;
    }
    
    if (avformat_find_stream_info(fmt_ctx, nullptr) < 0) {
        LOG_ERROR_S("Failed to get video stream information");
        avformat_close_input(&fmt_ctx);
        return orientation;
    }
    
    // Find video stream
    int video_stream_index = -1;
    for (int i = 0; i < fmt_ctx->nb_streams; i++) {
        if (fmt_ctx->streams[i]->codecpar->codec_type == AVMEDIA_TYPE_VIDEO) {
            video_stream_index = i;
            break;
        }
    }
    
    if (video_stream_index == -1) {
        LOG_ERROR_S("No video stream found");
        avformat_close_input(&fmt_ctx);
        return orientation;
    }
    
    AVStream* video_stream = fmt_ctx->streams[video_stream_index];
    int width = video_stream->codecpar->width;
    int height = video_stream->codecpar->height;
    
    LOG_DEBUG_S("Video dimensions: %dx%d", width, height);
    
    // Method 1: FFmpeg 4.4 compatible display matrix check
    for (int i = 0; i < video_stream->nb_side_data; i++) {
        AVPacketSideData* side_data = &video_stream->side_data[i];
        
        if (side_data->type == AV_PKT_DATA_DISPLAYMATRIX && side_data->size >= 9 * sizeof(int32_t)) {
            const int32_t* display_matrix = (const int32_t*)side_data->data;
            
            double rotation_radians = atan2(-(double)display_matrix[3], (double)display_matrix[0]);
            double rotation_degrees = rotation_radians * (180.0 / M_PI);
            
            LOG_DEBUG_S("Detected display matrix rotation angle: %.2f degrees", rotation_degrees);
            
            if (!std::isnan(rotation_degrees)) {
                double normalized_rotation = fmod(rotation_degrees, 360.0);
                if (normalized_rotation < 0) {
                    normalized_rotation += 360.0;
                }
                
                if (normalized_rotation == 90.0 || normalized_rotation == 270.0) {
                    LOG_INFO("Determined as portrait video based on display matrix");
                    orientation = ORIENTATION_PORTRAIT;
                    avformat_close_input(&fmt_ctx);
                    return orientation;
                } else if (normalized_rotation == 0.0 || normalized_rotation == 180.0) {
                    LOG_INFO("Determined as landscape video based on display matrix");
                    orientation = ORIENTATION_LANDSCAPE;
                    avformat_close_input(&fmt_ctx);
                    return orientation;
                }
            }
            break;
        }
    }
    
    // Method 2: Check rotation metadata (fallback)
    AVDictionaryEntry* rotate_tag = av_dict_get(video_stream->metadata, "rotate", NULL, 0);
    if (rotate_tag) {
        int rotation = atoi(rotate_tag->value);
        LOG_DEBUG_S("Detected rotation tag: %d degrees", rotation);
        
        if (rotation == 90 || rotation == 270) {
            LOG_INFO("Determined as portrait video (rotation tag)");
            orientation = ORIENTATION_PORTRAIT;
            avformat_close_input(&fmt_ctx);
            return orientation;
        }
    }
    
    // Method 3: Aspect ratio based determination (final fallback)
    if (height > width) {
        LOG_INFO("Determined as portrait based on aspect ratio");
        orientation = ORIENTATION_PORTRAIT;
    } else {
        LOG_INFO("Determined as landscape based on aspect ratio");
        orientation = ORIENTATION_LANDSCAPE;
    }
    
    avformat_close_input(&fmt_ctx);
    return orientation;
}
