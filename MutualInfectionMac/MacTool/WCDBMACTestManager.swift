//
//  WCDBMACTestManager.swift
//  MutualInfectionMac
//
//  Created by TS on 2025/11/1.
//  mac端文件互传测试数据

import Foundation
import WCDBSwift
import AppKit
import Photos


struct WCDBMACTestConfig {
    static let testDeviceIds = [
        "device_001",
        "device_002",
        "device_003",
        "device_004"
    ]
    
    static let testDeviceNames = [
        "iPhone 15 Pro",
        "Huawei Mate 70",
        "Xiaomi 14",
        "Samsung S24"
    ]
    
    // MARK: - 文件类型与文件夹映射
    static let fileTypeFolders: [MIFileType: String] = [
        .photoAndVideo: "image",
        .file: "doc",
        .contacts: "contact",
        .location: "others"
    ]
    
    // MARK: - 文件类型与后缀映射
    static let fileTypeExtensions: [MIFileType: [String]] = [
        .photoAndVideo: ["jpg", "jpeg", "png", "heic", "mp4", "mov"],
        .file: ["txt", "pdf", "doc", "docx"],
        .contacts: ["vcard"],
        .location: ["kml", "gpx"]
    ]
    
    // MARK: - 文件名模板（按类型分类）
    static let photoFileNames = [
        "vacation_photo", "family_portrait", "landscape", "selfie", "event_photo",
        "birthday_party", "wedding_photo", "nature_shot", "city_view", "sunset"
    ]
    
    static let videoFileNames = [
        "travel_vlog", "family_movie", "event_recording", "tutorial", "interview",
        "presentation", "celebration", "sports_highlight", "music_video", "documentary"
    ]
    
    static let documentFileNames = [
        "project_proposal", "financial_report", "meeting_minutes", "contract_agreement",
        "research_paper", "business_plan", "user_manual", "technical_specification",
        "invoice_receipt", "presentation_slides"
    ]
    
    static let contactFileNames = [
        "business_contacts", "family_contacts", "friends_list", "emergency_contacts",
        "work_colleagues", "client_list", "team_members", "network_contacts"
    ]
    
    static let locationFileNames = [
        "hiking_trail", "travel_route", "business_locations", "favorite_places",
        "vacation_spots", "running_path", "road_trip", "city_tour"
    ]
    
    // MARK: - 测试文件目录
    static var testFilesDirectory: URL {
        let documents = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first!
        let testDir = documents.appendingPathComponent("TestFiles")
        try? FileManager.default.createDirectory(at: testDir, withIntermediateDirectories: true)
        return testDir
    }
    
    // MARK: - 获取文件夹路径
    static func getFolderPath(for fileType: MIFileType) -> URL {
        let folderName = fileTypeFolders[fileType] ?? "others"
        let folderURL = testFilesDirectory.appendingPathComponent(folderName)
        try? FileManager.default.createDirectory(at: folderURL, withIntermediateDirectories: true)
        return folderURL
    }
    
    // MARK: - 生成随机文件数据（确保fileType与fileUrl后缀对应，async/await 版本）
    static func generateRandomFile(recordId: Int64, transferType: MITransferType) async throws -> MITransferFile? {
        let file = MITransferFile()
        // 随机文件类型
        let fileTypes: [MIFileType] = [.location, .photoAndVideo, .file, .contacts]
        let fileType = fileTypes.randomElement()!
        file.fileType = fileType
        
        // 设置文件夹
        file.fileFolder = fileTypeFolders[fileType] ?? "others"
        
        // 根据文件类型生成对应的文件名和URL
        let (fileName, fileExtension) = generateFileNameAndExtension(for: fileType)
        file.fileName = "\(fileName).\(fileExtension)"
        file.fileExtension = fileExtension
        
        if transferType == .send {
            // 发送模式: 不生成真实文件、不保存相册，只生成虚拟文件对象
            let folderName = file.fileFolder ?? "others"
            file.fileUrl = "/Documents/TestFiles/\(folderName)/\(file.fileName!)"
            file.fileSize = generateFileSize(for: fileType)
            file.identifier = "id_\(Int.random(in: 1000...9999))"
        } else {
            // 接收模式: 生成真实文件并保存到对应文件夹和相册
            let fileURL = createTestFile(fileType: fileType, fileName: file.fileName!)
            if let fileURL = fileURL {
                // Convert absolute path to relative path (relative to NSHomeDirectory())
                let absolutePath = fileURL.path
                let relativePath = absolutePath.replacingOccurrences(of: NSHomeDirectory(), with: "")
                file.fileUrl = relativePath
                
                // 获取实际文件大小
                do {
                    let attributes = try FileManager.default.attributesOfItem(atPath: fileURL.path)
                    file.fileSize = (attributes[.size] as? NSNumber)?.int64Value ?? 0
                } catch {
                    file.fileSize = generateFileSize(for: fileType)
                }
                
                // 为图片文件保存到系统相册并获取localIdentifier
                if fileType == .photoAndVideo && ["jpg", "jpeg", "png", "heic"].contains(fileExtension) {
                    let localIdentifier = try await saveImageToPhotoLibrary(fileURL: fileURL)
                    file.identifier = localIdentifier
                } else {
                    file.identifier = "id_\(Int.random(in: 1000...9999))"
                }
            } else {
                // 如果文件创建失败，使用模拟数据
                let folderName = file.fileFolder ?? "others"
                file.fileUrl = "/Documents/TestFiles/\(folderName)/\(file.fileName!)"
                file.fileSize = generateFileSize(for: fileType)
                file.identifier = "id_\(Int.random(in: 1000...9999))"
            }
        }
        // 随机状态（大部分成功，少量失败）
        file.status = Bool.random() ? .success : .failure
        file.transferType = transferType
        file.recordId = recordId
        return file
    }
    
    // MARK: - 根据文件类型生成文件名和后缀
    private static func generateFileNameAndExtension(for fileType: MIFileType) -> (String, String) {
        let extensions = fileTypeExtensions[fileType] ?? ["dat"]
        let fileExtension = extensions.randomElement()!
        
        let fileName: String
        switch fileType {
        case .photoAndVideo:
            let baseName = photoFileNames.randomElement()!
            if ["mp4", "mov", "avi", "mkv"].contains(fileExtension) {
                fileName = "\(baseName)_video"
            } else {
                fileName = "\(baseName)_photo"
            }
            
        case .file:
            let baseName = documentFileNames.randomElement()!
            fileName = "\(baseName)_document"
            
        case .contacts:
            let baseName = contactFileNames.randomElement()!
            fileName = "\(baseName)_contact"
            
        case .location:
            let baseName = locationFileNames.randomElement()!
            fileName = "\(baseName)_location"
        }
        
        return (fileName, fileExtension)
    }
    
    // MARK: - 根据文件类型生成合理的文件大小
    private static func generateFileSize(for fileType: MIFileType) -> Int64 {
        switch fileType {
        case .photoAndVideo:
            // 照片: 1MB - 10MB, 视频: 10MB - 500MB
            let isVideo = Bool.random()
            return isVideo ?
                Int64.random(in: 10*1024*1024...500*1024*1024) :
                Int64.random(in: 1024*1024...10*1024*1024)
            
        case .file:
            // 文档: 100KB - 50MB
            return Int64.random(in: 100*1024...50*1024*1024)
            
        case .contacts:
            // 通讯录: 1KB - 1MB
            return Int64.random(in: 1024...1024*1024)
            
        case .location:
            // 位置数据: 10KB - 100KB
            return Int64.random(in: 10*1024...100*1024)
        }
    }
    
    // MARK: - 创建真实的测试文件（保存到对应文件夹）
    private static func createTestFile(fileType: MIFileType, fileName: String) -> URL? {
        let folderURL = getFolderPath(for: fileType)
        let fileURL = folderURL.appendingPathComponent(fileName)
        
        switch fileType {
        case .photoAndVideo:
            return createImageFile(at: fileURL)
            
        case .file:
            return createDocumentFile(at: fileURL)
            
        case .contacts:
            return createContactFile(at: fileURL)
            
        case .location:
            return createLocationFile(at: fileURL)
        }
    }
    
    // MARK: - 创建图片文件
    private static func createImageFile(at url: URL) -> URL? {
        let size = NSSize(width: 800, height: 600)
        // 1. 创建图片上下文（macOS 绘图逻辑不变）
        let image = NSImage(size: size, flipped: false) { rect in
            guard let context = NSGraphicsContext.current?.cgContext else { return false }
            
            // 随机背景色
            let colors: [NSColor] = [.red, .blue, .green, .yellow, .purple, .orange, .systemPink, .cyan, .magenta, .brown]
            guard let bgColor = colors.randomElement() else { return false }
            context.setFillColor(bgColor.cgColor)
            context.fill(rect)
            
            // 绘制主文本
            let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.alignment = .center
            let textAttrs: [NSAttributedString.Key: Any] = [
                .foregroundColor: NSColor.white,
                .font: NSFont.boldSystemFont(ofSize: 24),
                .paragraphStyle: paragraphStyle,
                .strokeColor: NSColor.black,
                .strokeWidth: -2.0
            ]
            let text = "Test Photo\n\(formatDate(Date()))"
            let textRect = NSRect(x: 20, y: size.height/2 - 40, width: size.width - 40, height: 80)
            NSAttributedString(string: text, attributes: textAttrs).draw(in: textRect)
            
            // 绘制水印
            let watermarkAttrs: [NSAttributedString.Key: Any] = [
                .foregroundColor: NSColor.white.withAlphaComponent(0.3),
                .font: NSFont.systemFont(ofSize: 18),
                .paragraphStyle: paragraphStyle
            ]
            let watermark = "WCDB Test Data"
            let watermarkRect = NSRect(x: 20, y: size.height - 60, width: size.width - 40, height: 30)
            NSAttributedString(string: watermark, attributes: watermarkAttrs).draw(in: watermarkRect)
            
            return true
        }
        
        // 2. 处理图片格式（核心优化：支持更多格式 + 明确提示）
        guard let tiffData = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData) else {
            print("❌ 图片转换为位图失败")
            return nil
        }
        
        // 获取 URL 的扩展名（转小写，避免大小写问题，如 .PNG/.Jpg）
        let fileExt = url.pathExtension.lowercased()
        var imageType: NSBitmapImageRep.FileType?
        var properties: [NSBitmapImageRep.PropertyKey: Any] = [:]
        
        // 扩展支持的格式：png、jpg/jpeg、gif、tiff、bmp
        switch fileExt {
        case "png":
            imageType = .png
        case "jpg", "jpeg":
            imageType = .jpeg
            properties = [.compressionFactor: 0.8] // JPEG 压缩质量
        case "gif":
            imageType = .gif
        case "tiff", "tif":
            imageType = .tiff
        case "bmp":
            imageType = .bmp
        default:
            // 优化提示：明确告知当前 URL 的扩展名 + 支持的格式列表
            print("❌ 不支持的图片格式：\(fileExt)，仅支持 png/jpg/jpeg/gif/tiff/bmp")
            return nil
        }
        
        // 3. 生成对应格式的图片数据
        guard let imageData = bitmap.representation(using: imageType!, properties: properties) else {
            print("❌ 生成 \(fileExt.uppercased()) 格式数据失败")
            return nil
        }
        
        // 4. 写入文件
        do {
            try imageData.write(to: url)
            print("📸 创建测试图片: \(url.lastPathComponent) → \(url.deletingLastPathComponent().lastPathComponent)")
            return url
        } catch {
            print("❌ 保存图片失败: \(error.localizedDescription)")
            return nil
        }
    }
    
    // MARK: - 创建文档文件
    private static func createDocumentFile(at url: URL) -> URL? {
        let content = """
        Test Document
        Created: \(formatDate(Date()))
        File Type: \(url.pathExtension.uppercased())
        
        This is a test document file for WCDB testing purposes.
        It contains sample content to simulate real document files.
        
        Document Details:
        - File Name: \(url.lastPathComponent)
        - Created Date: \(formatDate(Date()))
        - Purpose: Testing file operations in WCDB database
        
        Lorem ipsum dolor sit amet, consectetur adipiscing elit. 
        Sed do eiusmod tempor incididunt ut labore et dolore magna aliqua.
        Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris.
        
        File Information:
        - Size: \(Int.random(in: 100...50000)) bytes
        - Type: \(url.pathExtension.uppercased())
        - Test ID: \(UUID().uuidString)
        """
        
        do {
            try content.write(to: url, atomically: true, encoding: .utf8)
            print("📄 创建测试文档: \(url.lastPathComponent) → \(url.deletingLastPathComponent().lastPathComponent)")
            return url
        } catch {
            print("❌ 保存文档失败: \(error)")
            return nil
        }
    }
    
    // MARK: - 创建通讯录文件
    private static func createContactFile(at url: URL) -> URL? {
        let names = ["John", "Jane", "Michael", "Sarah", "David", "Emily", "Robert", "Lisa"]
        let lastNames = ["Smith", "Johnson", "Williams", "Brown", "Jones", "Garcia", "Miller", "Davis"]
        let companies = ["Tech Corp", "Global Solutions", "Innovate Inc", "Future Tech", "Smart Systems"]
        
        var vCardContent = ""
        
        // 生成3-5个随机联系人
        let contactCount = Int.random(in: 3...5)
        for i in 0..<contactCount {
            let firstName = names.randomElement()!
            let lastName = lastNames.randomElement()!
            let company = companies.randomElement()!
            let phone = "\(Int.random(in: 100...999))-\(Int.random(in: 100...999))-\(Int.random(in: 1000...9999))"
            let email = "\(firstName.lowercased()).\(lastName.lowercased())@example.com"
            
            vCardContent += """
            BEGIN:VCARD
            VERSION:3.0
            FN:\(firstName) \(lastName)
            ORG:\(company)
            TITLE:\(["Software Developer", "Product Manager", "Designer", "Analyst", "Engineer"].randomElement()!)
            TEL;TYPE=WORK,VOICE:\(phone)
            EMAIL;TYPE=PREF,INTERNET:\(email)
            NOTE:Test contact \(i+1) for WCDB testing
            END:VCARD
            
            """
        }
        
        do {
            try vCardContent.write(to: url, atomically: true, encoding: .utf8)
            print("👤 创建测试通讯录: \(url.lastPathComponent) → \(url.deletingLastPathComponent().lastPathComponent)")
            return url
        } catch {
            print("❌ 保存通讯录失败: \(error)")
            return nil
        }
    }
    
    // MARK: - 创建位置文件
    private static func createLocationFile(at url: URL) -> URL? {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZ"
        let now = formatter.string(from: Date())
        let later1 = formatter.string(from: Date().addingTimeInterval(300))
        let later2 = formatter.string(from: Date().addingTimeInterval(600))
        let later3 = formatter.string(from: Date().addingTimeInterval(900))
        
        let gpxContent = """
        <?xml version="1.0" encoding="UTF-8"?>
        <gpx version="1.1" creator="WCDB Test Manager">
          <metadata>
            <name>Test Location Track</name>
            <desc>Generated test location data for WCDB testing purposes</desc>
            <author>
              <name>WCDB Test Suite</name>
            </author>
            <time>\(now)</time>
          </metadata>
          <trk>
            <name>Test Track \(Int.random(in: 1...100))</name>
            <desc>Automatically generated test track</desc>
            <trkseg>
              <trkpt lat="37.7749" lon="-122.4194">
                <ele>\(Double.random(in: 0...50))</ele>
                <time>\(now)</time>
                <name>Start Point</name>
              </trkpt>
              <trkpt lat="37.7849" lon="-122.4294">
                <ele>\(Double.random(in: 10...60))</ele>
                <time>\(later1)</time>
              </trkpt>
              <trkpt lat="37.7949" lon="-122.4394">
                <ele>\(Double.random(in: 20...70))</ele>
                <time>\(later2)</time>
              </trkpt>
              <trkpt lat="37.8049" lon="-122.4494">
                <ele>\(Double.random(in: 15...55))</ele>
                <time>\(later3)</time>
                <name>End Point</name>
              </trkpt>
            </trkseg>
          </trk>
        </gpx>
        """
        
        do {
            try gpxContent.write(to: url, atomically: true, encoding: .utf8)
            print("📍 创建测试位置文件: \(url.lastPathComponent) → \(url.deletingLastPathComponent().lastPathComponent)")
            return url
        } catch {
            print("❌ 保存位置文件失败: \(error)")
            return nil
        }
    }
    
    // MARK: - 日期格式化（兼容 iOS 13）
    private static func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    // MARK: - 保存图片到系统相册并获取localIdentifier (async/await 版本)
    private static func saveImageToPhotoLibrary(fileURL: URL) async throws -> String {
        return try await withCheckedThrowingContinuation { continuation in
            let status = PHPhotoLibrary.authorizationStatus()
            func handleSave() {
                Task {
                    let identifier = await actuallySaveImageToPhotoLibrary(fileURL: fileURL)
                    continuation.resume(returning: identifier)
                }
            }
            switch status {
            case .authorized, .limited:
                handleSave()
            case .notDetermined:
                PHPhotoLibrary.requestAuthorization { newStatus in
                    if newStatus == .authorized {
                        handleSave()
                    } else {
                        print("⚠️ 相册权限被拒绝，使用模拟localIdentifier")
                        let simulatedIdentifier = "simulated_\(UUID().uuidString)"
                        continuation.resume(returning: simulatedIdentifier)
                    }
                }
            case .denied, .restricted:
                print("⚠️ 相册权限不足，使用模拟localIdentifier")
                let simulatedIdentifier = "simulated_\(UUID().uuidString)"
                continuation.resume(returning: simulatedIdentifier)
                @unknown default:
                let simulatedIdentifier = "simulated_\(UUID().uuidString)"
                continuation.resume(returning: simulatedIdentifier)
            }
        }
    }

    // async 版本，返回 identifier
    private static func actuallySaveImageToPhotoLibrary(fileURL: URL) async -> String {
        await withCheckedContinuation { continuation in
            var localIdentifier: String = ""
            PHPhotoLibrary.shared().performChanges({
                if let creationRequest = PHAssetChangeRequest.creationRequestForAssetFromImage(atFileURL: fileURL) {
                    if let placeholder = creationRequest.placeholderForCreatedAsset {
                        localIdentifier = placeholder.localIdentifier
                    }
                }
            }) { success, error in
                if success && !localIdentifier.isEmpty {
                    print("✅ 图片已保存到系统相册，localIdentifier: \(localIdentifier)")
                    continuation.resume(returning: localIdentifier)
                } else {
                    print("❌ 保存图片到相册失败: \(error?.localizedDescription ?? "未知错误")")
                    let simulatedIdentifier = "failed_save_\(UUID().uuidString)"
                    continuation.resume(returning: simulatedIdentifier)
                }
            }
        }
    }
    
    // MARK: - 生成随机的传输记录（异步 async/await 版本）
    static func generateRandomRecord(transferType: MITransferType) async throws -> MITransferRecord? {
        let record = MITransferRecord()
        record.deviceIcon = "device_icon_\(Int.random(in: 1...10))"
        record.deviceId = WCDBMACTestConfig.testDeviceIds.randomElement()!
        record.deviceName = WCDBMACTestConfig.testDeviceNames.randomElement()!
        record.transferType = transferType
        record.transferTime = Date().addingTimeInterval(-Double.random(in: 0...30*24*3600)) // 30天内随机时间
        // 生成随机的文件列表 (1-3个文件)
        let fileCount = Int.random(in: 1...10)
        if fileCount == 0 {
            record.sendContent = []
            return record
        }
        print("🔄 开始生成 \(fileCount) 个测试文件...")
        var allFiles: [MITransferFile] = []
        var totalSize: Int64 = 0
        for i in 0..<fileCount {
            if let file = try await generateRandomFile(recordId: 0, transferType: transferType) {
                allFiles.append(file)
                totalSize += file.fileSize ?? 0
                print("✅ 生成文件 \(i+1)/\(fileCount): \(file.fileName ?? "未知") → 文件夹: \(file.fileFolder ?? "未知")")
            } else {
                print("❌ 文件 \(i+1)/\(fileCount) 生成失败")
            }
        }
        record.sendContent = allFiles
        print("🎉 记录生成完成，包含 \(allFiles.count) 个文件，总大小: \(totalSize.formattedFileSize())")
        return record
    }
}


class WCDBMACTestManager {
    
    static let shared = WCDBMACTestManager()
    private let dbManager = MIWCDBManager.shared
    
    private init() {}
    
    // MARK: - 测试文件管理
    
    /// 清理测试文件
    func cleanupTestFiles() {
        do {
            let fileManager = FileManager.default
            let testFiles = try fileManager.contentsOfDirectory(at: WCDBMACTestConfig.testFilesDirectory, includingPropertiesForKeys: nil)
            
            for file in testFiles {
                try fileManager.removeItem(at: file)
            }
            
            print("🧹 已清理测试文件目录")
        } catch {
            print("❌ 清理测试文件失败: \(error)")
        }
    }
    
    /// 检查测试文件是否存在
    func checkTestFilesExist() -> [String: [URL]] {
        do {
            let fileManager = FileManager.default
            let testFiles = try fileManager.contentsOfDirectory(at: WCDBMACTestConfig.testFilesDirectory, includingPropertiesForKeys: nil)
            
            var filesByFolder: [String: [URL]] = [:]
            
            print("📁 测试文件目录结构:")
            for folderURL in testFiles {
                let folderName = folderURL.lastPathComponent
                if folderURL.hasDirectoryPath {
                    let folderFiles = try fileManager.contentsOfDirectory(at: folderURL, includingPropertiesForKeys: nil)
                    filesByFolder[folderName] = folderFiles
                    
                    print("  📂 \(folderName) (\(folderFiles.count) 个文件):")
                    for file in folderFiles {
                        let attributes = try fileManager.attributesOfItem(atPath: file.path)
                        let fileSize = (attributes[.size] as? NSNumber)?.int64Value ?? 0
                        let fileType = file.pathExtension.uppercased()
                        print("    - \(file.lastPathComponent) (\(fileSize.formattedFileSize()), \(fileType))")
                    }
                }
            }
            
            return filesByFolder
        } catch {
            print("❌ 检查测试文件失败: \(error)")
            return [:]
        }
    }
    
    /// 检查系统相册权限
    func checkPhotoLibraryPermission() {
        let status = PHPhotoLibrary.authorizationStatus()
        switch status {
        case .authorized, .limited:
            print("✅ 相册权限: 已授权")
        case .denied:
            print("❌ 相册权限: 被拒绝")
        case .restricted:
            print("🚫 相册权限: 受限制")
        case .notDetermined:
            print("❓ 相册权限: 未决定")
        @unknown default:
            print("❓ 相册权限: 未知状态")
        }
    }
    
    // MARK: - 基础功能测试
    
    /// 测试插入单个记录（异步 async/await 版本）
    func testInsertSingleRecord() async -> Bool {
        print("=== 测试插入单个记录 ===")
        do {
            guard let record = try await WCDBMACTestConfig.generateRandomRecord(transferType: .send) else {
                print("❌ 生成测试记录失败")
                return false
            }
            let recordId = try await dbManager.insertRecordAsync(record)
            print("✅ 成功插入记录，ID: \(recordId)")
            print("记录详情:")
            print("  - 设备: \(record.deviceName ?? "未知设备")")
            print("  - 类型: \(record.transferType == .send ? "发送" : "接收")")
            print("  - 时间: \(self.formatDate(record.transferTime ?? Date()))")
            print("  - 文件数: \(record.sendContent.count)")
            // 打印文件详情
            for (index, file) in record.sendContent.enumerated() {
                print("  文件\(index+1): \(file.fileName ?? "未知")")
                print("    - 类型: \(self.fileTypeDescription(file.fileType))")
                print("    - 文件夹: \(file.fileFolder ?? "未知")")
                print("    - 路径: \(file.absoluteFileUrl ?? "无")")
                print("    - 大小: \(file.fileSize?.formattedFileSize() ?? "0")")
                print("    - 标识符: \(file.identifier ?? "无")")
                print("    - 状态: \(file.status == .success ? "成功" : "失败")")
            }
            return true
        } catch {
            print("❌ 插入记录失败: \(error)")
            return false
        }
    }
    
    /// 测试批量插入记录（async/await 版本）
    func testBatchInsertRecords() async -> Bool {
        print("=== 测试批量插入记录 ===")
        let recordCount = 30 // 减少记录数量以避免长时间等待
        var successfulInserts = 0
        print("🔄 开始生成 \(recordCount) 条测试记录...")
        for i in 0..<recordCount {
            let transferType: MITransferType = .receive
            do {
                guard let record = try await WCDBMACTestConfig.generateRandomRecord(transferType: transferType) else {
                    print("❌ 记录 \(i+1) 生成失败")
                    continue
                }
                let recordId = try await dbManager.insertRecordAsync(record)
                successfulInserts += 1
                print("✅ 插入记录 \(i+1) 成功，ID: \(recordId)")
            } catch {
                print("❌ 插入记录 \(i+1) 失败: \(error)")
            }
        }
        print("🎉 批量插入完成，成功: \(successfulInserts)/\(recordCount)")
        return successfulInserts > 0
    }
    
    // MARK: - 辅助方法
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    private func fileTypeDescription(_ fileType: MIFileType?) -> String {
        guard let fileType = fileType else { return "未知" }
        switch fileType {
        case .photoAndVideo: return "照片/视频"
        case .file: return "文件"
        case .contacts: return "通讯录"
        case .location: return "位置"
        }
    }
    
    // MARK: - 其他测试方法（保持原有实现）
    func testQueryAllRecords() {
        print("=== 测试查询所有记录 ===")
        
        do {
            // 查询所有发送记录
            let sendRecords = try dbManager.getAllRecords(transferType: .send)
            print("📤 发送记录数量: \(sendRecords.count)")
            
            // 查询所有接收记录
            let receiveRecords = try dbManager.getAllRecords(transferType: .receive)
            print("📥 接收记录数量: \(receiveRecords.count)")
            
            // 查询所有记录（发送+接收）
            let allRecords = try dbManager.getAllRecords(transferType: .all)
            print("📊 总记录数量: \(allRecords.count)")
            
            // 打印第一条记录的详细信息
            if let firstRecord = allRecords.first {
                print("第一条记录详情:")
                print("  - ID: \(firstRecord.id ?? -1)")
                print("  - 设备: \(firstRecord.deviceName ?? "未知")")
                print("  - 类型: \(firstRecord.transferType == .send ? "发送" : "接收")")
                print("  - 时间: \(formatDate(firstRecord.transferTime ?? Date()))")
                print("  - 文件数: \(firstRecord.sendContent.count)")
                
                // 打印文件详情
                for (index, file) in firstRecord.sendContent.enumerated() {
                    print("    文件\(index+1): \(file.fileName ?? "未知")")
                    print("      - 类型: \(fileTypeDescription(file.fileType))")
                    print("      - 文件夹: \(file.fileFolder ?? "未知")")
                    print("      - 大小: \(file.fileSize?.formattedFileSize() ?? "0")")
                    print("      - 标识符: \(file.identifier ?? "无")")
                }
            }
            
        } catch {
            print("❌ 查询记录失败: \(error)")
        }
    }
    
    // MARK: - 综合测试流程
    
    /// 运行完整的测试套件（async/await 版本）
    func runCompleteTestSuite() async {
        print("🚀 开始WCDB完整测试套件")
        print("========================================")
        // 0. 准备工作
        print("🔍 检查相册权限...")
        checkPhotoLibraryPermission()
        print("🔍 检查现有测试文件...")
        _ = checkTestFilesExist()
        // 1. 基础插入测试
        let singleSuccess = await testInsertSingleRecord()
        if singleSuccess {
            print("----------------------------------------")
            let batchSuccess = await testBatchInsertRecords()
            if batchSuccess {
                print("----------------------------------------")
                // 2. 查询测试
                self.testQueryAllRecords()
                // ... 其他测试 ...
            }
        }
    }

    /// 快速测试（基础功能，async/await 版本）
    func runQuickTest() async {
        print("⚡ 运行快速测试")
        _ = await testInsertSingleRecord()
        self.testQueryAllRecords()
    }
}
