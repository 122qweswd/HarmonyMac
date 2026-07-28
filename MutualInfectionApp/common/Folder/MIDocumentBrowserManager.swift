//
//  MIDocumentBrowserManager.swift
//  MutualInfectionApp
//
//  Created by delegate on 2025/9/20.
//

import UIKit

class MIDocumentBrowserManager: NSObject {
    /// 点击完成后回调
    public typealias CompletionHandler = (_ result: [FileItem]?, _ documentVC: MIDocumentBrowserViewController?) -> Void
    
    // 完成回调
    private var completionHandler: CompletionHandler?
    
    
    private var fileModelArr = [FileItem]()
    
    static let share = MIDocumentBrowserManager()
    
    private override init() { super.init() }
    
    func openDocumentPicker(autoDismiss: Bool = true, completionHandler: @escaping CompletionHandler) {
        self.completionHandler = completionHandler
        let topVC = UIViewController.topViewController
        let documentPicker = MIDocumentBrowserViewController()
        documentPicker.autoDismiss = autoDismiss
        documentPicker.allItemSuccessHandler = { items, controller in
            self.completionHandler?(items, controller)
        }
        documentPicker.cancelHanfler = {controller in
            self.completionHandler?(nil, controller)
        }
        let navi = MIBaseNavigationViewController(rootViewController: documentPicker)
        topVC?.present(navi, animated: true)
    }
    
    /// 打开系统文件管理
    func openFileURLScheme(completion: (Int) -> Void) {
        if let url = URL(string: "shareddocuments://") {
            if UIApplication.shared.canOpenURL(url) {
                UIApplication.shared.open(url, options: [:], completionHandler: nil)
                completion(1)
            }else {
                completion(0)
            }
        }else {
            completion(0)
        }
    }
    /// 删除应用在「文件管理」中显示的文件（Documents目录下）
    /// - Parameter fileName: 要删除的文件名（含扩展名）
    func deleteFileInFileManager(fileName: String) {
        let fileManager = FileManager.default
        guard let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
            print("无法获取Documents目录")
            return
        }
        let targetFileURL = documentsURL.appendingPathComponent(fileName)
        
        guard fileManager.fileExists(atPath: targetFileURL.path) else {
            print("文件不存在：\(fileName)")
            return
        }
        do {
            try fileManager.removeItem(at: targetFileURL)
            print("文件已删除：\(fileName)（在文件管理中同步生效）")
        } catch {
            print("删除失败：\(error.localizedDescription)")
        }
    }
    /// 删除应用在「文件管理」中显示的文件（Documents目录下）
    /// - Parameter fileURL: 要删除的文件URL
    func deleteFileInFileManager(fileURL: URL) {
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: fileURL.path) else {
            print("文件不存在：\(fileURL)")
            return
        }
        do {
            try fileManager.removeItem(at: fileURL)
            print("文件已删除：\(fileURL)（在文件管理中同步生效）")
        } catch {
            print("删除失败：\(error.localizedDescription)")
        }
    }
}
