//
//  FileSender.swift
//  MutualInfection
//
//  Created by 1234 on 2025/9/22.
//
//文件选择发送框
//import Cocoa
//
//class FileSender: NSObject {
//    func selectAndSendFile() {
//        let panel = NSOpenPanel()
//        panel.allowsMultipleSelection = false
//        panel.canChooseDirectories = false
//        panel.title = "选择要发送的文件"
//        panel.prompt = "发送"  // 修改主按钮文字
//        panel.allowedFileTypes = ["pdf", "jpg", "png", "txt"] // 可自定义文件类型
//        panel.begin { response in
//            if response == .OK, let url = panel.url {
//                self.shareFile(at: url)
//            }
//        }
//    }
//    
//    private func shareFile(at url: URL) {
//        
//        var isKeyWindow =  NSWindow()
//        for window in NSApplication.shared.windows {
//          if window.isKeyWindow {  // 这是判断当前活跃窗口的方法之一
//              isKeyWindow = window
//            }
//        }
//        
//        let sharingService = NSSharingServicePicker(items: [url])
//        sharingService.show(relativeTo: .zero, of:isKeyWindow.contentView ?? NSView(), preferredEdge: .minY)
//    }
//}
