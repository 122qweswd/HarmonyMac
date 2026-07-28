import UIKit

class AlertManager {}
// MARK: -  alert
extension AlertManager {
    /// 显示一个系统原生 确定+取消按钮样式 AlertCenter
    /// - Parameters:
    ///   - title: 标题 （可选）
    ///   - message: 内容 （可选）
    ///   - autoDismiss: 点击操作按钮后是否自动关闭弹窗(主要是26版本使用)
    ///   - cancelTitle: 左按钮文案（默认"Cancel"）（可选）
    ///   - leftAction: 左按钮点击后的闭包动作（可选）
    ///   - confirmTitle: 右按钮文案（默认"OK"）
    ///   - rightAction: 右按钮点击后的闭包动作（可选）
    @discardableResult
    static func showAlert(
        title: String? = "",
        message: String? = "",
        autoDismiss: Bool = true,
        cancelTitle: String? = LocalizedStrings.cancel,
        cancelAction: (() -> Void)? = nil,
        confirmTitle: String? = LocalizedStrings.confirm,
        confirmAction: (() -> Void)? = nil) -> UIViewController {
            
            /// 判断是不是iOS26
            if #available(iOS 26.0, *) {
                
                var actions: [iOS26AlertAction] = []
                
                // 添加左侧取消按钮
                if let cancelTitle = cancelTitle {
                    actions.append(iOS26AlertAction(title: cancelTitle, style: .cancel, handler: cancelAction))
                }
                
                // 添加右按钮动作
                if let confirmTitle = confirmTitle {
                    actions.append(iOS26AlertAction(title: confirmTitle, style: .default, handler: confirmAction))
                }
                
                assert(!actions.isEmpty, "操作按钮不能为空")
                
                let alert = iOS26AlertController(
                    title: title,
                    message: message,
                    actions: actions,
                    autoDismiss: autoDismiss,
                    blurStyle: .systemThinMaterial
                )
                alert.present(from: MIGetTopViewController() ?? UIViewController())
                return alert
            } else if UIDevice.current.userInterfaceIdiom == .pad {
                var actions: [iOS26AlertAction] = []
                
                // 添加左侧取消按钮
                if let cancelTitle = cancelTitle {
                    actions.append(iOS26AlertAction(title: cancelTitle, style: .cancel, handler: cancelAction))
                }
                
                // 添加右按钮动作
                if let confirmTitle = confirmTitle {
                    actions.append(iOS26AlertAction(title: confirmTitle, style: .default, handler: confirmAction))
                }
                
                assert(!actions.isEmpty, "操作按钮不能为空")
                
                let alert = iOS26AlertController(
                    title: title,
                    message: message,
                    actions: actions,
                    autoDismiss: autoDismiss,
                    blurStyle: .systemThinMaterial
                )
                alert.present(from: MIGetTopViewController() ?? UIViewController())
                return alert
            } else {
                let alert = CustomAlertController(title: title, message: message, preferredStyle: .alert)
                
                // 添加左侧取消按钮
                if let cancelTitle = cancelTitle {
                    let leftAlertAction = UIAlertAction(title: cancelTitle, style: .default) { _ in
                        cancelAction?()
                    }
                    alert.addAction(leftAlertAction)
                }
                
                // 添加右按钮动作
                if let confirmTitle = confirmTitle {
                    let rightAlertAction = UIAlertAction(title: confirmTitle, style: .default) { _ in
                        confirmAction?()
                    }
                    alert.boldButtonTitles.insert(confirmTitle)
                    alert.addAction(rightAlertAction)
                }
                   
                MIGetTopViewController()?.present(alert, animated: true, completion: nil)
                return alert
            }
        }
    
    
    /// 显示一个系统原生 左右双操作按钮样式 AlertCenter
    /// leftButtonTitle 和 rightButtonTitle，至少添加一个
    /// - Parameters:
    ///   - title: 标题（可选）
    ///   - message: 内容（可选）
    ///   - autoDismiss: 点击操作按钮后是否自动关闭弹窗(主要是26版本使用)
    ///   - leftButtonTitle: 左按钮文案（可选）
    ///   - leftAction: 左按钮点击后的闭包动作（可选）
    ///   - rightButtonTitle: 右按钮文案（可选）
    ///   - rightAction: 右按钮点击后的闭包动作（可选）
    static func showAlert(title: String? = "",
                          message: String? = "",
                          autoDismiss: Bool = true,
                          leftButtonTitle: String? = nil,
                          leftAction: (() -> Void)? = nil,
                          rightButtonTitle: String? = nil,
                          rightAction: (() -> Void)? = nil) {
        
        if #available(iOS 26.0, *) {
            
            var actions: [iOS26AlertAction] = []
            
            // 添加左侧取消按钮
            if let leftButtonTitle = leftButtonTitle {
                actions.append(iOS26AlertAction(title: leftButtonTitle, style: .default, handler: leftAction))
            }
            
            // 添加右按钮动作
            if let rightButtonTitle = rightButtonTitle {
                actions.append(iOS26AlertAction(title: rightButtonTitle, style: .default, handler: rightAction))
            }
            
            assert(!actions.isEmpty, "操作按钮不能为空")
            
            let alert = iOS26AlertController(
                title: title,
                message: message,
                actions: actions,
                autoDismiss: autoDismiss,
                blurStyle: .systemThinMaterial
            )
            alert.present(from: MIGetTopViewController() ?? UIViewController())
        } else {
            let alert = CustomAlertController(title: title, message: message, preferredStyle: .alert)
            
            // 添加左侧取消按钮
            if let leftButtonTitle = leftButtonTitle {
                let leftAlertAction = UIAlertAction(title: leftButtonTitle, style: .default) { _ in
                    leftAction?()
                }
                alert.addAction(leftAlertAction)
            }
            
            // 添加右按钮动作
            if let rightButtonTitle = rightButtonTitle {
                let rightAlertAction = UIAlertAction(title: rightButtonTitle, style: .default) { _ in
                    rightAction?()
                }
                alert.boldButtonTitles.insert(rightButtonTitle)
                alert.addAction(rightAlertAction)
            }
            // 强制使用亮色模式
            if #available(iOS 13.0, *) {
                alert.overrideUserInterfaceStyle = .light
            }
            MIGetTopViewController()?.present(alert, animated: true, completion: nil)
        }
    }
}

// MARK: -  actionSheet
extension AlertManager {
    static func showAlertSheet(title: String? = nil, message: String? = nil, operationOptionList: [OperationOption], actionIndexCallBack: @escaping (_ index: Int, _ option: OperationOption)->Void,sender:UIView = UIView()) {
        
        let alert = UIAlertController(title: title, message: message, preferredStyle: .actionSheet)
        if UIDevice.current.userInterfaceIdiom == .pad {
            if let popoverController = alert.popoverPresentationController {
                popoverController.sourceView = MIGetTopViewController()?.view ?? UIView()
                popoverController.sourceRect = CGRect(x: 0, y: ksUIScreenH-100, width: ksUIScreenW, height: 100)
            }
        }
        for (index, option) in operationOptionList.enumerated() {
            let optionAction = UIAlertAction(title: option.rawValue, style: option == .deleteRecordAndFile || option == .deleteRecord ? .destructive : .default) { _ in
                actionIndexCallBack(index, option)
            }
            alert.addAction(optionAction)
        }
        
        let cancel = UIAlertAction(title: LocalizedStrings.cancel, style: .cancel)
        alert.addAction(cancel)
        
        // 强制使用亮色模式
        if #available(iOS 13.0, *) {
            alert.overrideUserInterfaceStyle = .light
        }
        MIGetTopViewController()?.present(alert, animated: true, completion: nil)
    }
}

// MARK: -  dismiss AlertView
extension AlertManager {
    
    /// 关闭所有弹窗
    static func dismissAllAlertView() {
        checkDismissAllAlertView()
    }
    
    /// 判断是否关闭弹窗
    static func checkDismissAllAlertView() {
        if let vc = MIGetTopViewController(),
           checkControllerIsAlertViewController(vc) == true {
            vc.dismiss(animated: false)
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) {
                self.checkDismissAllAlertView()
            }
        }
    }
    
    /// 判断控制器是否弹窗
    static func checkControllerIsAlertViewController(_ controller: UIViewController) -> Bool {
        /// 判断是不是iOS26
        if #available(iOS 26.0, *) {
            if controller.isKind(of: iOS26AlertController.self){
                return true
            }
        }
        
        if controller.isKind(of: UIAlertController.self) {
            return true
        }
        
        /// 互传记录 - 分享弹窗
        if controller.isKind(of: UIActivityViewController.self) {
            return true
        }
        
        return false
    }
}

enum OperationOption: String, CaseIterable {
    case view = "查看"
    case openWith = "打开方式"
    case deleteRecordAndFile = "删除记录及文件"
    case deleteRecord = "删除记录"
    
    var rawValue: String {
        switch self {
            case .view:
                return LocalizedStrings.view
            case .openWith:
                return LocalizedStrings.openWith
            case .deleteRecordAndFile:
                return LocalizedStrings.deleteRecordAndFile
            case .deleteRecord:
                return LocalizedStrings.deleteRecord
        }
    }
}

class CustomAlertController: UIAlertController {
    // 标记需要加粗的按钮标题
    var boldButtonTitles: Set<String> = []
    
    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        
        if self.view.subviews.count > 0 {
            // 延迟执行以确保视图层次完全构建
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self.findAndModifyButtonLabels()
            }
        }
    }
    
    // 查找所有UILabel并检查文本内容
    private func findAndModifyButtonLabels() {
        func findLabels(in view: UIView) {
            for subview in view.subviews {
                // 检查是否是UILabel
                if let label = subview as? UILabel,
                   let text = label.text,
                   boldButtonTitles.contains(text) {
                    // 设置粗体字体
                    label.font = UIFont.boldSystemFont(ofSize: label.font.pointSize)
                }
                // 递归查找子视图
                findLabels(in: subview)
            }
        }
        findLabels(in: self.view)
    }
}
