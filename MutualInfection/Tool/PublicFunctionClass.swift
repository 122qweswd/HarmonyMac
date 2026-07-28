//
//  PublicFunctionClass.swift
//  MutualInfectionApp
//
//  Created by apple on 2025/9/16.
//

import Foundation



var isSendTask : Bool = false
var isRecvTask : Bool = false
var isSaveFileToAlbum: Bool = false

//所有设备信息
//var  allUserDeviceInfo  : [UserInfo] = []

// 格式化文件大小（字节 -> KB/MB/GB）
func formatFileSize(byteSize: Int64) -> String {
    
    if byteSize < 1000 {
        return "\(byteSize) B"
    }
    let formatter = ByteCountFormatter()
    formatter.allowedUnits = [.useBytes, .useKB, .useMB, .useGB, .useTB] // 包含字节单位
    formatter.countStyle = .decimal // 使用 1000 为进制
    formatter.includesUnit = true
    
//    formatter.allowedUnits = .useAll
    formatter.countStyle = .file
  
    formatter.zeroPadsFractionDigits = true
 
    return formatter.string(fromByteCount: byteSize)
    
}

let minNameCharacterCount = 2
let maxNameCharacterCount = 12

func isValidInput(_ input: String) -> Bool {
    // 获取字符串的 UTF-8 字节表示
    let charCount = input.count
    
    // 检查字节数是否在 2 到 12 之间（包含）
    guard charCount >= minNameCharacterCount && charCount <= maxNameCharacterCount else {
        return false
    }
    
    let allowedCharacterSet = CharacterSet(
        // 英文字母 (大小写)
        charactersIn: "a"..."z").union(CharacterSet(charactersIn: "A"..."Z"))
        // 数字
        .union(.decimalDigits)
        // 中文 (Unicode 范围: \u{4E00} - \u{9FFF})
        .union(CharacterSet(charactersIn: "\u{4E00}"..."\u{9FFF}"))
        // 空格
        .union(.whitespaces)
    
    return input.unicodeScalars.allSatisfy { allowedCharacterSet.contains($0) }
}

//通讯录文件写入
func writeVCDCardsToFile( cards: [String], filePath: String){
    let fileURL = URL(fileURLWithPath: filePath)
    let fileManager = FileManager.default

    let directoryURL = fileURL.deletingLastPathComponent()
    
   
    
    // 确保文件所在的目录存在
    if FileManager.default.fileExists(atPath: directoryURL.path) {
          try? FileManager.default.removeItem(at: fileURL)
      }
     
    try? fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true, attributes: nil)

    
  
    
    
    // 写入文件
    if let fileHandle = try? FileHandle(forWritingTo: fileURL) {
        
        for cardStr in cards {
            if let data = cardStr.data(using: .utf8) {
//                fileHandle.seek(toFileOffset: 0)
                fileHandle.seekToEndOfFile() // 移动到文件末尾
                fileHandle.write(data)
                fileHandle.write(Data([UInt8(ascii: "\n")])) // 添加换行符以便每个条目分开
            }
        }
    
        
        fileHandle.closeFile()
        
     
    } else {
        // 如果文件不存在，则创建文件并写入内容
        if fileManager.createFile(atPath: filePath, contents: nil, attributes: nil) {
            
            if let fileHandle = try? FileHandle(forWritingTo: fileURL) {
                
                for cardStr in cards {
                    if let data = cardStr.data(using: .utf8) {
        //                fileHandle.seek(toFileOffset: 0)
                        fileHandle.seekToEndOfFile() // 移动到文件末尾
                        fileHandle.write(data)
                        fileHandle.write(Data([UInt8(ascii: "\n")])) // 添加换行符以便每个条目分开
                    }
                }
            
                
                fileHandle.closeFile()
                
             
            }

         
        } else {
            print("Failed to create file")
          
        }
        
        
        
        
        
        
        

        
        
        
        
        
        
    }
    
    


 
}

func deleteVCDCardsToFile(filePath:String) -> Bool {
    let fileManager = FileManager.default
    
    do {
        // 尝试删除文件
        try fileManager.removeItem(atPath: filePath)
        return true
    } catch {
        // 打印错误信息
        return true
    }
}
//func createVCDCard(firstName: String, lastName: String, email: String, phone: String) -> String {
//    let vcfString = """
//    BEGIN:VCARD
//    VERSION:3.0
//    N:\(lastName);\(firstName);;;
//    FN:\(firstName) \(lastName)
//    EMAIL;TYPE=INTERNET,PREF: \(email)
//    TEL;TYPE=CELL:\(phone)
//    END:VCARD
//    """
//    return vcfString
//}

func getArrayFromJSONString(jsonString:String) ->NSArray?{

    guard let jsonData:Data = jsonString.data(using: .utf8) else{
        return nil
    }
    if let array = try? JSONSerialization.jsonObject(with: jsonData, options: .mutableContainers) as? NSArray {
        return array
    }
 
    return nil

}

func showFileInfo(stat: [AnyHashable: Any]) -> String {
    let files = stat["fileList"] as? String ?? ""
    let fileList = getArrayFromJSONString(jsonString: files)
    let totalTransfer = stat["totalTransfer"] as? Int ?? 0
    var imageCount = 0
    var videoCount = 0
    var fileCount = 0
    ShareAPI.shared().log(1, "[UI] [PublicFunctionClass] showFileInfo fileList: \(fileList?.count ?? 0)")

    for item in fileList ?? []{
        if let fileDict = item as? [String: Any]
        {
            let status = fileDict["status"] as! String
            let filename = fileDict["filename"] as! String
            let fileURL = URL(fileURLWithPath: filename)
            let fileExtension = "\(fileURL.pathExtension)".lowercased()
            
            if status == "inprogress" || status == "completed" {
                switch fileExtension {
                case "jpg", "jpeg", "png", "gif", "bmp", "tiff", "tif", "raw", "psd", "webp", "heic", "heif", "avif":
                    imageCount += 1
                case "mp4", "mov", "avi", "mkv", "wmv", "webm", "flv", "mpeg", "mpg", "mts", "m2ts", "ts", "rmvb":
                    videoCount += 1
                default:
                    fileCount += 1
                }
            }
        }
    }
    let fileSize = formatFileSize(byteSize: Int64(totalTransfer))
    var fileInfoText = ""
    if imageCount > 0 {
        fileInfoText = fileInfoText + "\(imageCount)"+"张图片，".localized
    }
    if videoCount > 0 {
        fileInfoText = fileInfoText + "\(videoCount)"+"个视频，".localized
    }
    if fileCount > 0 {
        fileInfoText = fileInfoText + "\(fileCount)"+"个文件，".localized
    }
    if imageCount > 0 || videoCount > 0 || fileCount > 0 {
        return "\(fileInfoText)\(fileSize)"
       
    }
    return ""
}

