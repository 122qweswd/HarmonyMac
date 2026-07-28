//
//  MIMACDownloadFolderManager.swift
//  MutualInfectionMac
//
//  Created by TS on 2025/11/1.
//

import Foundation
import Cocoa


//MARK: 下载文件夹的访问扩展
class MIMACDownloadFolderManager {
    // 弹窗回调
    typealias AlertCompletion = (Bool) -> Void
    
    /// 打开对应的文件夹并选中该文件
    func openFileFolder(_ filePath: String) {
        let resolvedFilePath = resolveSystemDirectoryPath(filePath)
        
        /// 创建文件URL（处理路径无效的情况）
        let fileURL = URL(fileURLWithPath: resolvedFilePath)
        /// 验证是否为文件路径（非目录）
        guard !fileURL.hasDirectoryPath else {
            print("❌ 路径是目录，不是文件：\(resolvedFilePath)")
            return
        }
        
        /// 检查文件是否存在
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            print("❌ 文件不存在：\(fileURL.path)")
            return
        }
        
        /// 检查文件夹权限
        let folderURL = fileURL.deletingLastPathComponent()
        do {
            try FileManager.default.attributesOfItem(atPath: folderURL.path)
        } catch {
            print("❌ 无权限访问文件夹：\(folderURL.path)，错误：\(error.localizedDescription)")
            return
        }
        
        /// 打开文件夹并选中文件
        NSWorkspace.shared.activateFileViewerSelecting([fileURL])
        print("✅ 尝试打开文件夹：\(folderURL.path)，选中文件：\(fileURL.lastPathComponent)")
    }

    /// 解析系统目录路径
    private func resolveSystemDirectoryPath(_ originalPath: String) -> String {
        let systemDirMappings: [(rootPrefix: String, userDir: FileManager.SearchPathDirectory)] = [
            ("/Downloads/", .downloadsDirectory),
            ("/Documents/", .documentDirectory),
            ("/Desktop/", .desktopDirectory),
            ("/Library/Application Support/", .applicationSupportDirectory),
            ("/Library/Caches/", .cachesDirectory)
        ]
        
        for (rootPrefix, userDir) in systemDirMappings {
            if originalPath.hasPrefix(rootPrefix) {
                let relativePath = String(originalPath.dropFirst(rootPrefix.count))
                if let userDirURL = FileManager.default.urls(for: userDir, in: .userDomainMask).first {
                    return userDirURL.appendingPathComponent(relativePath).path
                }
            }
        }
        return originalPath
    }
    
    /// 检查下载分类权限的方法
    func checkDownloadsFolderPermission() -> Bool {
        guard let downloadsURL = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first else {
            return false
        }
        
        return FileManager.default.isReadableFile(atPath: downloadsURL.path)
    }
    
    /// 检查文档分类权限的方法
    func checkDocumentsFolderPermission() -> Bool {
        guard let downloadsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return false
        }
        
        return FileManager.default.isReadableFile(atPath: downloadsURL.path)
    }
    
    /// 打开下载文件夹
    func openDownloadsFolder() {
        // 获取用户的下载文件夹路径
        guard let downloadsURL = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first else {
            print("❌ 无法获取下载文件夹路径")
            showErrorAlert(type: "下载")
            return
        }
        
        // 检查是否有权限访问下载文件夹
        guard FileManager.default.isReadableFile(atPath: downloadsURL.path) else {
            print("❌ 无权限访问下载文件夹：\(downloadsURL.path)")
            showErrorAlert(type: "下载")
            return
        }
        
        // 检查文件夹是否存在
        guard FileManager.default.fileExists(atPath: downloadsURL.path) else {
            print("❌ 下载文件夹不存在：\(downloadsURL.path)")
            showErrorAlert(type: "下载")
            return
        }
        
        // 尝试查找已打开的下载文件夹窗口
        if activateExistingDownloadsFolder(downloadsURL: downloadsURL) {
            print("✅ 已激活已打开的下载文件夹窗口")
            return
        }
        
        // 未找到已打开的窗口，打开新的下载文件夹
        do {
            try NSWorkspace.shared.open(downloadsURL)
            print("✅ 成功打开下载文件夹：\(downloadsURL.path)")
        } catch {
            print("❌ 打开下载文件夹失败：\(error.localizedDescription)")
            showErrorAlert(type: "下载")
        }
    }
    
    /// 尝试激活已打开的下载文件夹窗口
    /// - Parameter downloadsURL: 下载文件夹URL
    /// - Returns: 是否成功激活
    private func activateExistingDownloadsFolder(downloadsURL: URL) -> Bool {
        // 获取所有正在运行的应用程序
        let runningApps = NSWorkspace.shared.runningApplications
        
        // 查找Finder应用程序
        if let finderApp = runningApps.first(where: { $0.bundleIdentifier == "com.apple.finder" }) {
            // 构建AppleScript命令，检查并激活包含下载文件夹的窗口
            let script = """
            tell application "Finder"
                set downloadFolderPath to "\(downloadsURL.path.replacingOccurrences(of: "\"", with: "\\\""))"
                repeat with window in windows
                    try
                        if target of window as alias is downloadFolderPath as alias then
                            set index of window to 1
                            activate
                            return true
                        end if
                    on error
                        -- 忽略错误，继续检查下一个窗口
                    end try
                end repeat
            end tell
            return false
            """
            
            // 执行AppleScript
            if let scriptObject = NSAppleScript(source: script) {
                var error: NSDictionary?
                scriptObject.executeAndReturnError(&error)
                
                if let error = error {
                    print("❌ AppleScript执行错误：\(error)")
                    return false
                }
                
                // 检查脚本返回值
                let result = scriptObject.executeAndReturnError(nil)
                return result.booleanValue
            }
        }
        
        return false
    }
    

    /// 检测路径中指定文件是否存在（支持含系统目录标识的路径，如 /Downloads/... 或 /Documents/...）
    /// - Parameter path: 路径（如 "/Downloads/TestFiles/image/photo.png" 或 "/Documents/file.txt"）
    /// - Returns: 文件是否存在
    func checkSystemPathExists(_ path: String) -> Bool {
        // 定义系统目录的标识和对应的 SearchPathDirectory
        let directoryMappings: [(prefix: String, directory: FileManager.SearchPathDirectory)] = [
            ("/Downloads/", .downloadsDirectory),
            ("/Documents/", .documentDirectory),
            ("/Desktop/", .desktopDirectory),
            ("/Library/Application Support/", .applicationSupportDirectory),
            ("/Library/Caches/", .cachesDirectory)
        ]
        
        // 遍历匹配路径前缀，提取相对路径和对应的基础目录
        for (prefix, directory) in directoryMappings {
            if path.hasPrefix(prefix) {
                // 提取相对路径（去除前缀部分）
                let relativePath = String(path.dropFirst(prefix.count))
                // 获取基础目录URL
                guard let baseURL = FileManager.default.urls(for: directory, in: .userDomainMask).first else {
                    continue
                }
                // 拼接路径并检测
                let fileURL = baseURL.appendingPathComponent(relativePath)
                return FileManager.default.fileExists(atPath: fileURL.path)
            }
        }
        
        // 若未匹配任何系统目录前缀，尝试直接作为绝对路径检测
        return FileManager.default.fileExists(atPath: path)
    }
    
    /// 没有下载文件夹权限时的提示弹窗
    func showErrorAlert(type: String) {
        let alert = NSAlert()
        alert.messageText = "无法打开\(type)文件夹"
        alert.informativeText = "请手动打开\(type)文件夹，或检查应用的权限设置。"
        alert.addButton(withTitle: "确定")
        alert.runModal()
    }
    
    /// 没有找到对应的文件资源的提示弹窗
    func showFileNoFindAlert(completion: @escaping AlertCompletion) {
        let alert = NSAlert()
        alert.messageText = "该文件已被移动或删除，是否删除该项记录？".localized
        alert.informativeText = "删除后将无法恢复此记录。".localized // 可选的详细说明
        alert.alertStyle = .warning // 设置警告样式
        
        // 添加按钮
        alert.addButton(withTitle: "删除".localized)
        alert.addButton(withTitle: "ignore".localized)
        
        // 在主线程异步显示弹窗
        DispatchQueue.main.async {
            let response = alert.runModal()
            
            // 根据按钮点击调用回调
            switch response {
            case .alertFirstButtonReturn:  // 删除按钮
                completion(true)
            case .alertSecondButtonReturn: // 忽略按钮
                completion(false)
            default:
                completion(false) // 默认处理为取消
            }
        }
    }
    
    //MARK: 删除原文件

    /// 删除指定路径的文件（优化路径解析和验证）
    /// - Parameter filePath: 文件路径（支持系统目录路径如 /Downloads/... 或完整绝对路径）
    /// - Returns: 是否删除成功，及错误信息
    func deleteFile(at filePath: String) -> (success: Bool, error: Error?) {
        // 1. 先解析路径（处理 /Downloads/... 等系统目录路径，转换为实际用户目录路径）
        let resolvedPath = resolveSystemDirectoryPath(filePath)
        
        // 2. 验证路径格式（确保是合法的文件路径）
        let fileURL = URL(fileURLWithPath: resolvedPath)
        guard !fileURL.hasDirectoryPath else {
            let error = NSError(domain: "FileError", code: -3, userInfo: [NSLocalizedDescriptionKey: "路径是目录，不是文件"])
            return (false, error)
        }
        
        // 3. 再次检查文件是否存在（使用 URL 验证，避免字符串路径误差）
        let fileExists = FileManager.default.fileExists(atPath: fileURL.path)
        guard fileExists else {
            let error = NSError(domain: "FileError", code: -1, userInfo: [
                NSLocalizedDescriptionKey: "文件不存在",
                "实际检查路径": fileURL.path // 附加实际检查的路径，方便调试
            ])
            return (false, error)
        }
        
        // 4. 检查父文件夹可写权限
        let folderURL = fileURL.deletingLastPathComponent()
        guard FileManager.default.isWritableFile(atPath: folderURL.path) else {
            let error = NSError(domain: "PermissionError", code: -2, userInfo: [
                NSLocalizedDescriptionKey: "无删除权限（文件夹不可写）",
                "文件夹路径": folderURL.path
            ])
            return (false, error)
        }
        
        // 5. 执行删除（优先放入废纸篓，更符合用户习惯）
        do {
            // 方案A：放入废纸篓（推荐，可恢复）
            try FileManager.default.trashItem(at: fileURL, resultingItemURL: nil)
            print("✅ 已将文件放入废纸篓：\(fileURL.path)")
            
            // 方案B：永久删除（谨慎使用）
            // try FileManager.default.removeItem(at: fileURL)
            // print("✅ 永久删除文件：\(fileURL.path)")
            
            return (true, nil)
        } catch {
            print("❌ 删除失败，路径：\(fileURL.path)，错误：\(error.localizedDescription)")
            return (false, error)
        }
    }
    
    
    /// 删除记录的提示弹窗
    func deleteRecordTipAlert(message: String, infoMessage: String = "", completion: @escaping AlertCompletion) {
        let alert = NSAlert()
        alert.messageText = message
        if infoMessage.isEmpty {
            alert.informativeText = infoMessage // 可选的详细说明
        }
        
        alert.alertStyle = .warning // 设置警告样式
        
        // 添加按钮
        alert.addButton(withTitle: "确定".localized)
        alert.addButton(withTitle: "取消".localized)
        
        // 在主线程异步显示弹窗
        DispatchQueue.main.async {
            let response = alert.runModal()
            
            // 根据按钮点击调用回调
            switch response {
            case .alertFirstButtonReturn:  // 第一个按钮
                completion(true)
            case .alertSecondButtonReturn: // 第二个按钮
                completion(false)
            default:
                completion(false) // 默认处理为取消
            }
        }
    }
    
    func Alert(message: String, infoMessage: String = "",oneBtnTit:String,twoBtnTit:String, completion: @escaping (_ index:Int)->Void) {
        let alert = NSAlert()
        alert.messageText = message
        if infoMessage.isEmpty {
            alert.informativeText = infoMessage // 可选的详细说明
        }
        
        alert.alertStyle = .warning // 设置警告样式
        
        // 添加按钮
        alert.addButton(withTitle: oneBtnTit.localized)
        alert.addButton(withTitle: twoBtnTit.localized)
        
        // 在主线程异步显示弹窗
        DispatchQueue.main.async {
            let response = alert.runModal()
            
            // 根据按钮点击调用回调
            switch response {
            case .alertFirstButtonReturn:  // 第一个按钮
                completion(1)
            case .alertSecondButtonReturn: // 第二个按钮
                completion(2)
            default:
                break // 默认处理
            }
        }
    }

}



class MACNavigationManager {
    static let shared = MACNavigationManager()
    private var viewControllerStack: [NSViewController] = [] // 页面栈
    weak var window: NSWindow? // 关联窗口
    
    private var anchorFrames: [NSRect] = []
    
    // 初始化根页面
    func setRootViewController(_ vc: NSViewController) {
        viewControllerStack.removeAll()
        viewControllerStack.append(vc)
        anchorFrames.removeAll()
        anchorFrames.append(NSRect.zero)
        window?.contentViewController = vc
    }
    
    /// 推入新页面Push动画
    func pushViewController(_ vc: NSViewController, animated: Bool = true) {
        guard animated else {
            /// 非动画模式直接切换
            viewControllerStack.append(vc)
            window?.contentViewController = vc
            return
        }
        
        // 保存当前页面（即将被覆盖的页面）
        guard let currentVC = window?.contentViewController else { return }
        
        // 将新页面添加到窗口层级（初始状态：透明度0 + 右移50pt）
        vc.view.alphaValue = 0
        vc.view.frame.origin.x = window?.contentView?.bounds.width ?? 50 // 右移一个窗口宽度
        window?.contentView?.addSubview(vc.view) // 先添加到视图层级
        
        
        // 执行动画
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.3 // 动画时长
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut) // 缓动效果
            
            // 当前页面：透明度降低 + 左移
            currentVC.view.animator().alphaValue = 0.5
            currentVC.view.animator().frame.origin.x = -50
            
            // 新页面：透明度恢复 + 移到原位
            vc.view.animator().alphaValue = 1
            vc.view.animator().frame.origin.x = 0
        }, completionHandler: {
            // 动画结束后更新状态
            self.viewControllerStack.append(vc)
            self.window?.contentViewController = vc // 正式切换控制器
            currentVC.view.removeFromSuperview() // 移除旧页面视图
        })
    }
    
    /// 推出新页面(放射性动画)
    func pushFromAnchor(_ vc: NSViewController, anchorView: NSView, animated: Bool = true) {
        guard animated else {
            viewControllerStack.append(vc)
            window?.contentViewController = vc
            return
        }
        
        // 获取当前页面和窗口信息
        guard let currentVC = window?.contentViewController,
              let window = window,
              let contentView = window.contentView else { return }
        
        // 计算锚点（按钮）在窗口中的绝对位置和大小
        let anchorFrame = anchorView.convert(anchorView.bounds, to: contentView)
        assert(self.anchorFrames.count == self.viewControllerStack.count, "锚点数据与页面栈不同步")
        self.anchorFrames.append(anchorFrame)
        
        // anchorFrame 包含：按钮在窗口中的x、y坐标，以及宽高
        
        // 初始化新页面的初始状态（与按钮重合）
        vc.view.frame = anchorFrame // 初始大小和位置与按钮一致
        vc.view.alphaValue = 1
        vc.view.wantsLayer = true // 开启图层支持动画
        contentView.addSubview(vc.view) // 先添加到视图层级
        
        // 记录目标状态（铺满窗口）
        let targetFrame = contentView.bounds // 窗口内容区域的大小
        
        // 执行扩展动画
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.4 // 动画时长
            context.timingFunction = CAMediaTimingFunction(name: .easeOut) // 先快后慢，更自然
            
            // 旧页面：逐渐淡出
            currentVC.view.animator().alphaValue = 0
            
            // 新页面：从按钮位置放大到铺满窗口
            // 关键：通过animator()代理让frame变化产生动画
            vc.view.animator().frame = targetFrame
        }, completionHandler: {
            // 动画结束后清理
            self.viewControllerStack.append(vc)
            window.contentViewController = vc // 正式切换控制器
            currentVC.view.removeFromSuperview() // 移除旧页面
            
        })
    }
    
    
    /// 返回上一页
//    func popViewController(animated: Bool = true) {
//        // 基本的安全检查
//        guard viewControllerStack.count > 1,
//              let window = self.window,
//              let contentView = window.contentView else {
//            // 如果条件不满足，至少保持状态一致性
//            if viewControllerStack.count > 1 {
//                _ = viewControllerStack.popLast()
//                _ = anchorFrames.popLast()
//            }
//            return
//        }
//        
//        // 同步检查
//        guard anchorFrames.count == viewControllerStack.count else {
//            print("锚点数据异常，强制重置")
//            anchorFrames.removeAll()
//            viewControllerStack.removeLast()
//            window.contentViewController = viewControllerStack.last
//            return
//        }
//        
//        // 安全地获取控制器
//        let currentVC = viewControllerStack.removeLast()
//        guard let previousVC = viewControllerStack.last else {
//            // 状态回滚
//            viewControllerStack.append(currentVC)
//            return
//        }
//        
//        guard let targetAnchorFrame = anchorFrames.popLast() else {
//            // 状态回滚
//            viewControllerStack.append(currentVC)
//            anchorFrames.append(.zero)
//            return
//        }
//        
//        // 如果不需要动画，直接切换
//        guard animated else {
//            window.contentViewController = previousVC
//            return
//        }
//        
//        // 确保视图有效
//        let previousView: NSView
//        let currentView: NSView
//        
//        // 加载previousVC的视图
//        if #available(macOS 14.0, *) {
//            previousVC.loadViewIfNeeded()
//        } else {
//            // 确保视图已创建
//            let _ = previousVC.view
//        }
//        
//        // 获取视图引用（NSViewController.view是非可选的）
//        previousView = previousVC.view
//        currentView = currentVC.view
//        
//        // 移除旧关联（避免重复添加）
//        currentView.removeFromSuperview()
//        
//        // 检查contentView是否仍然有效
//        guard let contentView = window.contentView else {
//            window.contentViewController = previousVC
//            return
//        }
//        
//        // 重新添加视图到contentView
//        contentView.addSubview(previousView)
//        contentView.addSubview(currentView)
//        
//        // 初始化上一页面状态
//        previousView.frame = contentView.bounds
//        previousView.alphaValue = 0
//        previousView.wantsLayer = true
//        previousView.translatesAutoresizingMaskIntoConstraints = false
//        
//        // 初始化当前页面状态
//        currentView.frame = contentView.bounds
//        currentView.alphaValue = 1
//        currentView.wantsLayer = true
//        currentView.translatesAutoresizingMaskIntoConstraints = false
//        
//        // 执行动画
//        NSAnimationContext.runAnimationGroup({ [weak self] context in
//            guard let self = self else { return }
//            context.duration = 0.4
//            context.timingFunction = CAMediaTimingFunction(name: .easeIn)
//            
//            previousView.animator().alphaValue = 1
//            currentView.animator().frame = targetAnchorFrame
//            currentView.animator().alphaValue = 0
//        }, completionHandler: { [weak self] in
//            guard let self = self else { return }
//            currentView.removeFromSuperview()
//            window.contentViewController = previousVC
//            
//            // 修复：确保previousVC的视图正确布局
//            previousView.frame = contentView.bounds
//            
//            // 确保视图控制器的生命周期方法被正确调用
//            previousVC.viewDidAppear()
//            
//            // 强制刷新显示
//            previousView.needsLayout = true
//            previousView.layoutSubtreeIfNeeded()
//            previousView.displayIfNeeded()
//        })
//        
//    }
    
    
    func popViewController(animated: Bool = true) {
        guard viewControllerStack.count > 1 else { return }
        let currentVC = viewControllerStack.removeLast()
        let previousVC = viewControllerStack.last!
        
        guard animated, let window = window, let contentView = window.contentView else {
            window?.contentViewController = previousVC
            return
        }
        anchorFrames.removeLast()
        // 反向动画：从窗口缩小到上一个页面的按钮位置（如需实现可参考push逻辑）
        previousVC.view.frame = contentView.bounds
        previousVC.view.alphaValue = 0
        previousVC.view.wantsLayer = true
        contentView.addSubview(previousVC.view)
        
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.4
            context.timingFunction = CAMediaTimingFunction(name: .easeIn)
            currentVC.view.animator().alphaValue = 0
            previousVC.view.animator().alphaValue = 1
        }, completionHandler: {
            window.contentViewController = previousVC
            currentVC.view.removeFromSuperview()
        })
    }
    
    
}

