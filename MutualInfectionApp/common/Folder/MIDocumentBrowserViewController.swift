//
//  MIDocumentBrowserViewController.swift
//  MutualInfectionApp
//
//  Created by delegate on 2025/9/20.
//

import UIKit
import MobileCoreServices

class MIDocumentBrowserViewController: UIDocumentBrowserViewController {
    var allItemSuccessHandler: (([FileItem], MIDocumentBrowserViewController) -> Void)?
    var cancelHanfler: ((MIDocumentBrowserViewController) -> Void)?
    var autoDismiss: Bool = true
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(true, animated: false)
    }
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        navigationController?.setNavigationBarHidden(false, animated: false)
    }
    // 存储选中的顶层项目
    private var selectedTopLevelItems: [FileItem] = []
    // 存储所有项目（包括顶层和文件夹内的内容）
    private var allCollectedItems: [FileItem] = []
    
    // 支持的文件类型
    private let supportedContentTypes: [String]
    // 初始化方法
    init(supportedContentTypes: [String] = [kUTTypeItem as String]) {
        self.supportedContentTypes = supportedContentTypes
        super.init(forOpeningFilesWithContentTypes: supportedContentTypes)
        commonInit()
    }
    
    required init?(coder: NSCoder) {
        self.supportedContentTypes = [kUTTypeItem as String]
        super.init(coder: coder)
        commonInit()
    }

    // 通用初始化设置
    private func commonInit() {
        delegate = self
        allowsPickingMultipleItems = true
        browserUserInterfaceStyle = .light
        view.tintColor = .systemBlue
        allowsDocumentCreation = false
        setupNavigationBarButtons()
    }
    
    // 设置导航栏按钮
    private func setupNavigationBarButtons() {
        
        let cancelButton = UIBarButtonItem(
            barButtonSystemItem: .cancel,
            target: self,
            action: #selector(cancelSelection)
        )
        
        additionalLeadingNavigationBarButtonItems = [cancelButton]
    }
    
    // 取消选择
    @objc private func cancelSelection() {
        selectedTopLevelItems.removeAll()
        allCollectedItems.removeAll()
        cancelHanfler?(self)
        dismiss(animated: true, completion: nil)
    }
    deinit {
        cancelSelection()
    }
    
}
extension MIDocumentBrowserViewController: UIDocumentBrowserViewControllerDelegate {
    func documentBrowser(_ controller: UIDocumentBrowserViewController, didPickDocumentsAt documentURLs: [URL]) {
        selectedTopLevelItems.removeAll()
        
        // 为每个URL获取属性并存储
        for url in documentURLs {
            if let item = getFileProperties(for: url) {
                selectedTopLevelItems.append(item)
            }
        }
        processSelectedItems()
        
        if autoDismiss {
            dismiss(animated: true)
        }
    }
}

extension MIDocumentBrowserViewController {
    
    // 处理选中的项目
    func processSelectedItems() {
        guard !selectedTopLevelItems.isEmpty else {
            print("未选择文件/文件夹")
            return
        }
        
        // 生成详细信息（在后台处理文件夹内容统计，避免UI卡顿）
        DispatchQueue.global().async {
            // 清空之前收集的内容
            self.allCollectedItems.removeAll()
            // 递归收集所有项目
            for item in self.selectedTopLevelItems {
                self.collectAllItems(from: item)
            }
            // 回到主线程显示结果
            DispatchQueue.main.async {
                
                self.allItemSuccessHandler?(self.allCollectedItems, self)
                
                // 生成详细信息
                var details = "共收集到 \(self.allCollectedItems.count) 个项目：\n\n"
                for (index, item) in self.allCollectedItems.enumerated() {
                    details += "\(index + 1). \(item.type == .folder ? "📁" : "📄") \(item.name)\n"
                    details += "   路径: \(item.url.path)\n"
                    details += "   创建日期: \(item.creationDateDescription)\n\n"
                }
                print("已选择\(self.selectedTopLevelItems.count)个项目，详情:\(details)")
            }
        }
    }
    
    // 递归收集所有项目（包括文件夹内的内容）
    func collectAllItems(from item: FileItem) {
        // 检查是否已添加，避免循环引用
        guard !allCollectedItems.contains(item) else {
            return
        }
        
        // 将当前项目添加到总列表
        allCollectedItems.append(item)
        
        // 如果是文件夹，递归处理其内容
        guard item.type == .folder else { return }
        
        // 对文件夹启用安全访问
        let hasAccess = item.url.startAccessingSecurityScopedResource()
        defer {
            if hasAccess {
                item.url.stopAccessingSecurityScopedResource()
            }
        }
        
        do {
            // 获取文件夹内容（排除隐藏文件）
            let contents = try FileManager.default.contentsOfDirectory(
                at: item.url,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: [.skipsHiddenFiles, .skipsPackageDescendants]
            )
            
            for contentURL in contents {
                // 将子项目转换为FileItem并递归处理
                if let subItem = getFileProperties(for: contentURL) {
                    collectAllItems(from: subItem)
                }
            }
        } catch {
            print("无法访问文件夹 \(item.name): \(error.localizedDescription)")
        }
    }
    
    // 获取文件属性，改进了安全访问处理
    private func getFileProperties(for url: URL) -> FileItem? {
        // 定义需要获取的资源属性
        let resourceKeys: Set<URLResourceKey> = [
            .isDirectoryKey,
            .fileSizeKey,
            .creationDateKey,
            .contentModificationDateKey,
            .typeIdentifierKey
            
        ]
        
        // 检查是否需要访问安全范围的资源
        let hasAccess = url.startAccessingSecurityScopedResource()
        defer {
            if hasAccess {
                url.stopAccessingSecurityScopedResource()
            }
        }
        
        do {
            // 获取资源属性
            let resourceValues = try url.resourceValues(forKeys: resourceKeys)
            
            // 判断是否为文件夹
            let isDirectory = resourceValues.isDirectory ?? false
            let type = isDirectory ? FileType.folder : .file
            
            // 获取文件大小（文件夹大小可能为0或不相关）
            let fileSize: UInt64
            if isDirectory {
                fileSize = 0
            } else {
                fileSize = UInt64(resourceValues.fileSize ?? 0)
            }
            
            // 创建FileItem并返回
            return FileItem(
                url: url,
                name: url.lastPathComponent,
                type: type,
                fileSize: fileSize,
                creationDate: resourceValues.creationDate,
                modificationDate: resourceValues.contentModificationDate,
                parentPath: url.deletingLastPathComponent().path,
                systemFileNumber: resourceValues.documentIdentifier
            )
        } catch {
            print("获取文件属性失败: \(error.localizedDescription)")
            return nil
        }
    }
}
