//
//  AboutController.swift
//  MutualInfection
//
//  Created by 1234 on 2025/9/25.
//

import Cocoa
import AppKit
import WebKit
class AboutController: NSViewController {
    override func loadView() {
        self.view=NSView(frame: NSRect(x: 0, y: 0, width: 560, height: 416))
    }
    override func viewDidLoad() {
        super.viewDidLoad()
        //self.view=NSView(frame: NSRect(x: 0, y: 0, width: 560, height: 416))
        setupUI()
    }
    override func viewDidAppear() {
        super.viewDidAppear()
        // 新增：默认选中第0行
        if !dataSourceArr.isEmpty {
            // 选中第0行
            tableView.selectRowIndexes(IndexSet(integer: 0), byExtendingSelection: false)
            // 手动触发选中事件（确保更新数据源和加载对应视图）
//            tableViewSelectionDidChange(Notification(name: NSTableView.selectionDidChangeNotification, object: tableView))
        }
    }
    private func setupUI() {
        [naviView, contentScrollView, webBgView].forEach {
            view.addSubview($0)
        }
        [closeButton, titleLabel].forEach {
            naviView.addSubview($0)
        }
        naviView.snp.makeConstraints { make in
            make.top.leading.trailing.equalToSuperview()
            make.height.equalTo(40)
        }
        closeButton.snp.makeConstraints { make in
            make.top.equalTo(12)
            make.leading.equalTo(12)
            make.width.height.equalTo(18)
        }
        titleLabel.snp.makeConstraints { make in
            make.top.equalTo(10)
            make.height.equalTo(40)
            make.centerX.equalToSuperview()
        }
        contentScrollView.snp.makeConstraints { make in
            make.leading.equalToSuperview()
            make.bottom.equalToSuperview()
            make.width.equalToSuperview().multipliedBy(0.31)
            make.top.equalTo(closeButton.snp.bottom).offset(11)
        }
        webBgView.snp.makeConstraints { make in
            make.top.equalTo(naviView.snp.bottom)
            make.leading.equalTo(contentScrollView.snp.trailing)
            make.trailing.bottom.equalToSuperview()
            make.bottom.equalToSuperview()
        }
        contentScrollView.documentView = tableView
        tableView.frame = contentScrollView.bounds
        tableView.autoresizingMask = [.width, .height]
        
        let checkView = CheckUpdateView()
        webBgView.addSubview(checkView)
         checkView.snp.makeConstraints { make in
             make.edges.equalToSuperview()
         }
        
    }
    //=================================================================
    //                           事件处理
    //=================================================================
    // MARK: - 事件处理
    @objc private func closeButtonAction() {
        self.view.window?.close()
    }
    //=================================================================
    //                            lazy
    //=================================================================
    // MARK: - lazy
    private lazy var naviView: NSView = {
        let headView = NSView()
        headView.wantsLayer = true
        headView.layer?.backgroundColor = NSColor.mi.hex("#F5F5F5", alpha: 0.8).cgColor
        return headView
    }()
    private lazy var closeButton: NSButton = {
        let closeButton = NSButton(title: "关闭".localized, target: nil, action:#selector(closeButtonAction))
        closeButton.setButtonType(.momentaryPushIn)
        closeButton.isBordered = false // 关键属性，禁用系统边框样式
        closeButton.wantsLayer = true // 启用图层支持
        closeButton.image = NSImage(named: "icon_close")
        closeButton.layer?.cornerRadius = 9
        closeButton.imageScaling = .scaleNone
        closeButton.translatesAutoresizingMaskIntoConstraints = false
        return closeButton
    }()
    private lazy var titleLabel: NSTextField = {
        let label = NSTextField(labelWithString: "关于".localized)
        label.font = .mi.pingFangSCSemibold(size: 13)
        label.textColor = .mi.hex("#000000")
        label.alignment = .center
        label.isEditable = false
        label.isSelectable = false
        return label
    }()
    private lazy var contentScrollView: NSScrollView = {
        let scrollView = NSScrollView(frame: .zero)
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder
        return scrollView
    }()
    private lazy var tableView: NSTableView = {
        let tableView = NSTableView(frame: .zero)
        tableView.delegate = self
        tableView.dataSource = self
        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("ColumnIdentifier"))
        tableView.addTableColumn(column)
        column.headerCell.stringValue = ""  // 清空标题文本
        tableView.headerView = nil
        tableView.allowsMultipleSelection = false  // 只允许单选
        tableView.backgroundColor = NSColor.mi.hex("#F5F5F5", alpha: 1)
        tableView.selectionHighlightStyle = .none
        return tableView
    }()
    private lazy var webBgView: NSView = {
        let bgView = NSView(frame: .zero)
        return bgView
    }()
    
    private lazy var dataSourceArr: Array<MILeftAboutModel> = {
        let arr = [
            MILeftAboutModel(title: "版本检测".localized, isSelected: false, agreement: "https://t6k99cki.html2web.com/"),
            MILeftAboutModel(title: "个人信息收集清单".localized, isSelected: false, agreement: "https://t6k99cki.html2web.com/"),
            MILeftAboutModel(title: "个人信息共享清单".localized, isSelected: false, agreement: "https://o3s0uolj.html2web.com/"),
            MILeftAboutModel(title: "鸿蒙星河互联隐私政策".localized, isSelected: false, agreement: "https://5kbpubrc.html2web.com/"),
            MILeftAboutModel(title: "鸿蒙星河互联用户服务协议".localized, isSelected: false, agreement: "https://hecu0ijg.html2web.com/")
        ]
        return arr
    }()
}
extension AboutController: NSTableViewDelegate, NSTableViewDataSource {
    func numberOfRows(in tableView: NSTableView) -> Int {
        dataSourceArr.count
    }
    // 实现委托协议
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let identifier = NSUserInterfaceItemIdentifier("MIAboutTableCellView")
        if let cell = tableView.makeView(withIdentifier: identifier, owner: self) as? MIAboutTableCellView {
            cell.leftAboutModel = dataSourceArr[row]
            return cell
        }
        let newCell = MIAboutTableCellView(identifier: identifier)
        newCell.leftAboutModel = dataSourceArr[row]
        return newCell
    }
    func tableView(_ tableView: NSTableView, heightOfRow row: Int) -> CGFloat {
        44
    }
    func tableView(_ tableView: NSTableView, sizeToFitWidthOfColumn column: Int) -> CGFloat {
        0
    }
    func tableViewSelectionDidChange(_ notification: Notification) {
        let selectedRow = tableView.selectedRow
        dataSourceArr = dataSourceArr.enumerated().map { index, model in
            var mutableModel = model
            mutableModel.isSelected = (index == selectedRow)
            return mutableModel
        }
        tableView.reloadData()
        
        webBgView.subviews.forEach {
            $0.removeFromSuperview()
        }
        
        if selectedRow == 0 {
            let checkView = CheckUpdateView()
            webBgView.addSubview(checkView)
             checkView.snp.makeConstraints { make in
                 make.edges.equalToSuperview()
             }
        }else {
            let webVC = MIWebBrowserViewController()
            self.view.window?.contentViewController?.addChild(webVC)
            webBgView.addSubview(webVC.view)
            webVC.view.snp.makeConstraints { make in
                make.edges.equalToSuperview()
                make.width.equalTo(webBgView.snp.width)
            }
//            let model = dataSourceArr[selectedRow]
            let model = dataSourceArr[selectedRow < 0 ? 0 : selectedRow]
            webVC.loadURLPage(urlStr: model.agreementURL)
        }
//        let webVC = MIWebBrowserViewController()
//        self.view.window?.contentViewController?.addChild(webVC)
//        webBgView.addSubview(webVC.view)
//        webVC.view.snp.makeConstraints { make in
//            make.edges.equalToSuperview()
//            make.width.equalTo(webBgView.snp.width)
//        }
//        let model = dataSourceArr[selectedRow < 0 ? 0 : selectedRow]
//        webVC.loadURLPage(urlStr: model.agreementURL)
    }

}

class CheckUpdateView: NSView {
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.backgroundColor = NSColor.mi.hex("#FFFFFF").cgColor
        
        setupUI()
        
    }
    private func setupUI() {
        [currentVersionLabel, checkUpdateButton].forEach {
            addSubview($0)
        }
        [btnTitleLabel, arrowImageView].forEach {
            checkUpdateButton.addSubview($0)
        }
        currentVersionLabel.snp.makeConstraints { make in
            make.top.equalTo(30)
            make.leading.equalTo(25)
            make.height.equalTo(20)
        }
        checkUpdateButton.snp.makeConstraints { make in
            make.leading.equalTo(25)
            make.trailing.equalTo(-25)
            make.top.equalTo(currentVersionLabel.snp.bottom).offset(6)
            make.height.equalTo(38)
        }
        
        btnTitleLabel.snp.makeConstraints { make in
            make.leading.equalTo(12)
            make.trailing.equalTo(-12)
            make.centerY.equalToSuperview()
        }
        
        arrowImageView.snp.makeConstraints { make in
            make.centerY.equalToSuperview()
            make.trailing.equalTo(10)
            make.width.equalTo(5)
            make.height.equalTo(11)
        }
    }
    private func getCurrentVersionNumber() -> String {
        guard let infoDict = Bundle.main.infoDictionary else {
            print("无法读取 Info.plist")
            return ""
        }
        let appVersion = infoDict["CFBundleShortVersionString"] as? String ?? "未知版本"
        let buildVersion = infoDict["CFBundleVersion"] as? String ?? "未知构建号"
        return appVersion
    }
    @objc private func checkUpdateButtonAction() {
         let updateChecker = AppUpdateChecker()
         updateChecker.checkForUpdates()
        
        AppVersionChecker().getLatestVersionFromAppStore(appID: "6753906811") { version in
            let currentVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
            ShareAPI.shared().log(1, "获取当前版本号=====\(currentVersion)")  
            ShareAPI.shared().log(1, "获取最新版本号=====\(version ?? "")")  
            if let version = version {
                let isNew = AppVersionChecker().chechVersion(nowVer: currentVersion, newVer: version)
                if isNew {
                    let alert = NSAlert()
                    alert.messageText = "发现新版本".localized
                    alert.informativeText = "\("当前版本".localized): \(currentVersion)\n\("最新版本:".localized) \(version)\n\n\("是否前往 App Store 更新？".localized)"
                    alert.alertStyle = .informational
                    alert.addButton(withTitle: "前往更新".localized)
                    alert.addButton(withTitle: "取消".localized)
                    
                    let response = alert.runModal()
                    if response == .alertFirstButtonReturn {
                        if let url = URL(string: "https://apps.apple.com/app/id=6753906811") {
                            NSWorkspace.shared.open(url)
                        }
                    }
                }else{
                    DispatchQueue.main.async {
                        //                    showSheetAlert(message: "未监测到线上版本")
                        showSheetAlert(messageText: "提示".localized, message: "已是最新版本".localized,window:self.window) {
                            
                        }
                    }
                }
            }
        }
        
//        fetchAppStoreVersion(bundleId: bundleId) { version in
//            
//            if let version = version {
//                DispatchQueue.main.async {
//                    self.compareVersion(appStoreVersion: version)
//                }
//            }else{
//                DispatchQueue.main.async {
////                    showSheetAlert(message: "未监测到线上版本")
//                    showSheetAlert(messageText: "提示".localized, message: "已是最新版本".localized,window:self.window) {
//                        
//                    }
//                }
//                
//            }
//            
//        }
    }
   
    func compareVersion(appStoreVersion: String) {
      
        
        if appStoreVersion == appVersion {
            showSheetAlert(message: "已是最新版本".localized)

        }else{
            showSheetAlert(
                message: "当前最新版本是:\(appStoreVersion)".localized,
                confirmTitle: "更新".localized,
                cancelTitle: "取消".localized,
                confirmCompletion: {
                    print("执行删除操作")
                    let urlString = "itms-apps://itunes.apple.com/app/id\(appID)"
                    if let url = URL(string: urlString) {
                        NSWorkspace.shared.open(url)
                    }
                },
                cancelCompletion: {
                    print("用户取消了删除")
                }
            )
     
        }
    }
    func fetchAppStoreVersion(bundleId: String, completion: @escaping (String?) -> Void) {
        
        let url = URL(string: "https://itunes.apple.com/lookup?bundleId=\(bundleId)")!

        let task = URLSession.shared.dataTask(with: url) { data, _, error in
            guard let data = data, error == nil else {
                completion(nil)
                return
            }
            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let results = json["results"] as? [[String: Any]],
                   let appStoreVersion = results.first?["version"] as? String {
                    completion(appStoreVersion)
                } else {
                    completion(nil)
                }
            } catch {
                completion(nil)
            }
        }
        task.resume()
    }
    lazy var currentVersionLabel: NSTextField = {
        
        let label = NSTextField(labelWithString: String(format: "当前版本：v%@".localized, getCurrentVersionNumber()))
        label.font = .mi.pingFangSCSemibold(size: 13)
        label.textColor = .mi.hex("#000000")
        label.alignment = .center
        label.isEditable = false
        label.isSelectable = false
        return label
    }()
    lazy var checkUpdateButton: NSButton = {
        let button = NSButton(title: "", target: self, action: #selector(checkUpdateButtonAction))
        button.title = ""
        button.wantsLayer = true
        button.layer?.backgroundColor = NSColor.clear.cgColor
        button.layer?.cornerRadius = 4
        button.layer?.masksToBounds = true
        button.layer?.borderColor = NSColor.mi.hex("#000000", alpha: 0.2).cgColor
        button.layer?.borderWidth = 1
        button.isBordered = false
        return button
    }()
    lazy var btnTitleLabel: NSTextField = {
        let label = NSTextField(labelWithString: "检查更新".localized)
        label.wantsLayer = true
        label.layer?.backgroundColor = NSColor.clear.cgColor
        label.textColor = NSColor.mi.hex("#000000", alpha: 0.9)
        label.font = NSFont.mi.pingFangSCSemibold(size: 13)
        label.isEditable = false
        label.isSelectable = false
        return label
    }()
    lazy var arrowImageView: NSImageView = {
        let imageView = NSImageView()
        imageView.image = NSImage(named: "")
        wantsLayer = true
        imageView.layer?.backgroundColor = NSColor.red.cgColor
        return imageView
    }()
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
