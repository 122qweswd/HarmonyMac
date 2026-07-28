//
//  SaveFileHandler+Mac.swift
//  MutualInfection
//
//  Created by apple on 2025/11/21.
//

//#if os(macOS)
//#else
//#endif

extension SaveFileHandler {
    
    // 落盘开始获取文件夹和文件
    func saveMacFileStart(_ fileName: String, _ directoryType: String) -> String? {
        self.fileName = fileName
        // 文件夹适配
        let tempFileName = getMacLastDir(fileName, directoryType)
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
    
    //多文件夹多级适配
    func getMacLastDir(_ fileName: String,_ directoryType:String) -> String {
        if fileName.contains("/") {
            let dirArr = fileName.split(separator:"/")
            var preDir = directoryType
            for (index, dir) in dirArr.enumerated(){
                if index < (dirArr.count - 1) {
                    preDir = preDir + "/" + dir
                }
            }
            self.directory = FileSaver.getMacDownloadsDirectory(preDir)
            return String (dirArr [dirArr.count - 1])
        } else {
            self.directory = FileSaver.getMacDownloadsDirectory(directoryType)
            return fileName
        }
    }
    
    // 清理文件接收缓存
    func clearMacFileParamCache(_ fileName: String, _ fileSize: Int64) {
        if let curFileName = self.fileName,
           fileName == curFileName {
            if self.tempFileSizeDict == nil {
                self.tempFileSizeDict = [String: Int64]()
            }
            self.tempFileSizeDict?[self.fileURL ?? ""] = fileSize
            if self.tempFilePaths == nil {
                self.tempFilePaths = []
            }
            self.directory = nil
            self.fileURL = nil
            self.fileName = nil
            self.imageType = nil
        }
    }
    
}
