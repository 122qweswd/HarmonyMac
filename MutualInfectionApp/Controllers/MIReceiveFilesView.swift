//
//  MIReceiveFilesView.swift
//  MutualInfectionApp
//
//  Created by apple on 2025/9/2.
//  文件接收页面

import Lottie
import PhotosUI

class MIReceiveFilesView: MIBaseViewController {
    
    var imageCount = 0
    var videoCount = 0
    var fileCount = 0
    var isInDidRecvAllFiles: Bool = false
    var recvThumb: UIImage?
    var allFiles: [String]?
    // 缩略图接收是否成功
    var recvBase64IsScuccess = false
    
    // 取消接收弹框
    var cancelAlert: UIViewController?
    let ICON_CENTER_OFFSET: Int = -23
    var progressPath: UIBezierPath?
    // 文件接收类型：0-媒体 3-文件  4-文件夹
    var senderType: String = ""
    // 记录大文件
    var allFilesList: [AnyHashable: Any] = [:]
    // 记录小文件
    var allSmallFIlesList: [String] = []
    var manger: ShareAPI?
    var udid: String?
    var hwid: String?
    var meta: [AnyHashable: Any]? = [:] {
        didSet {
            if let senderName = meta?["senderName"] as? String {
                self.senderInfoLabel.text = "来自".localized + " " + senderName
            }
        }
    }

    // 接收文件成功个数
    var fileSuccesCount: Int = 0
    // 接收文件失败个数
    var fileErrCount: Int = 0
    // 文件是否接收完毕
    var isFinish: Bool = false
    // 是否连接中
    var isConnect: Bool = true
    // 水波纹
    var waveView: LottieAnimationView?
    var backAction: ClickBlockVoid?
    var dissClick: ClickBlockVoid?
    // 进度圆环
    private lazy var progressCircleView: CircleProgressView = {
        let view = CircleProgressView()
        view.backgroundColor = .clear
        return view
    }()

    // 多文件堆叠图标
    private lazy var filesImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        imageView.image = UIImage.iconOverlap
        imageView.clipsToBounds = true
        imageView.layer.cornerRadius = 20
        imageView.isHidden = true
        return imageView
    }()

    // 多图片堆叠图标
    private lazy var mediaImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFill
        imageView.image = UIImage.bgImages
        imageView.clipsToBounds = true
        imageView.layer.cornerRadius = 20
        imageView.isHidden = true
        return imageView
    }()

    // 文件图标缩略图
    private lazy var thumbnailImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        imageView.layer.cornerRadius = 20
//        imageView.image = UIImage.scanCenterIcon
        return imageView
    }()

    // 发送者信息标签
    private lazy var senderInfoLabel: UILabel = {
        let label = UILabel()
        label.font = SFCompact(weight: .regular, size: 17)
        label.textColor = "#000000E5".color
        label.textAlignment = .center
        label.isHidden = true
        return label
    }()

    // 文件信息标签
    private lazy var fileInfoLabel: UILabel = {
        let label = UILabel()
        label.font = SFCompact(weight: .regular, size: 13)
        label.textColor = "#000000A5".color
        label.textAlignment = .center
        label.isHidden = true
        return label
    }()
    
    // 导入中进度
    private lazy var importingLabel: UILabel = {
        let label = UILabel()
        label.font = SFCompact(weight: .regular, size: 13)
        label.textColor = "＃336FFF".color
        label.text = "请不要退出当前页面".localized
        label.textAlignment = .center
        label.isHidden = true
        return label
    }()

    // 接收 error 展示
    private lazy var errorMessageLabel: UILabel = {
        let label = UILabel()
        label.font = SFCompact(weight: .regular, size: 13)
        label.textColor = .red
        label.text = "接收取消".localized
        label.textAlignment = .center
        label.isHidden = true
        return label
    }()

    // 连接提示
    private lazy var connectLabel: UILabel = {
        let label = UILabel()
        label.font = SFCompact(weight: .regular, size: 13)
        label.textColor = "#000000A5".color
        label.text = "正在连接对方热点".localized
        label.textAlignment = .left
        return label
    }()

    lazy var bottomView: UIStackView = {
        let view = UIStackView(arrangedSubviews: [cancelButton, histroyButton, JumpDetailsBtn])
        view.axis = .horizontal
        view.spacing = 8
        view.alignment = .center
        return view
    }()

    private lazy var JumpDetailsBtn: UIButton = {
        let button = UIButton(type: .custom)
        button.titleLabel?.font = SFCompact(weight: .regular, size: 16)
        button.setBackgroundImage(UIImage.bgButton, for: .normal)
        button.setTitleColor("#336FFF".color, for: .normal)
        button.layer.cornerRadius = 42.0 / 2.0
        button.addTarget(self, action: #selector(self.JumpDetailsTapped), for: .touchUpInside)
        button.isHidden = true
        return button
    }()

    // 底部按钮
    private lazy var cancelButton: UIButton = {
        let button = UIButton(type: .custom)
        button.titleLabel?.font = SFCompact(weight: .regular, size: 16)
        button.setBackgroundImage(UIImage.bgButton, for: .normal)
        button.setTitle("取消接收".localized, for: .normal)
        button.setTitleColor("#336FFF".color, for: .normal)
        button.layer.cornerRadius = 42.0 / 2.0
        button.addTarget(self, action: #selector(self.cancelButtonTapped), for: .touchUpInside)
        return button
    }()
    
    private lazy var histroyButton: UIButton = {
        let button = UIButton(type: .custom)
        button.titleLabel?.font = SFCompact(weight: .regular, size: 16)
        button.setBackgroundImage(UIImage.bgButton, for: .normal)
        button.setTitle("查看历史记录".localized, for: .normal)
        button.setTitleColor("#336FFF".color, for: .normal)
        button.layer.cornerRadius = 42.0 / 2.0
        button.addTarget(self, action: #selector(self.cancelButtonTapped), for: .touchUpInside)
        button.isHidden = true
        return button
    }()
    
    // 落盘
    var directoryType: String?
    var lastFileUrl: String?
    
    // 接收文件总大小
    var totalBytes: Int?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.navigationView?.leftButtonView?.isHidden = true
        self.navigationView?.lineView.isHidden = true
        self.startNotifier()
        self.setupUI()
        self.manger?.log(1, "[UI] [MIReceiveFilesView] viewDidLoad")
        self.navigationView?.backButtonClickBlock = { [weak self] in
            
            self?.connectLabel.stopAnimation()
            
            //落盘中设置弹窗
            if SaveFileHandler.shared.isSaveFileing ?? false {
                let _ = AlertManager.showAlert(title: "文件还在导入中".localized, message: "可在互传记录中查看导入进度".localized,cancelTitle: nil, confirmTitle: "确定".localized) {
                    self?.navigationController?.popViewController(animated: true)
                    self?.backAction?()
                }
            } else {
                self?.navigationController?.popViewController(animated: true)
                self?.backAction?()
            }
        }
        
        NotificationCenter.default.addObserver(self, selector: #selector(self.cancelAction(_:)), name: NSNotification.Name(cancelUseSend), object: nil)
        
        self.manger?.log(1, "[UI] [MIRecvFilesView] viewDidLoad isInDidRecvAllFiles:  \(self.isInDidRecvAllFiles)")
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            if self.isInDidRecvAllFiles {
                self.manger?.log(1, "[UI] [MIRecvFilesView] isInDidRecvAllFiles]")
                self.initView(files: self.allFiles ?? [])
            }
        }
    }
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        UIApplication.shared.isIdleTimerDisabled = true
        
        self.manger?.log(1,"didMetaRecv push receivePage ===8push sviewWillAppear")

    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        UIApplication.shared.isIdleTimerDisabled = false
        self.dissClick?()
    }
    @objc func cancelAction(_ noti: Notification? = nil) {
        // TODO: 停止的时候  触发灵动岛停止。告诉。manager  我要强行停止
        self.cancelRecv()
    }
    
    func cancelRecv() {
        if self.isFinish {
            return
        }
        
        self.cancelAlert?.dismiss(animated: true)
        isRecvTask = false
        self.cancelRecvPage()
        // 取消删除落盘数据
        SaveFileHandler.shared.removeAllFiles()
        if #available(iOS 16.2, *) {
            self.manger?.log(1, "[UI] [MIReceiveFilesView] endActivity cancelRecv")
            LiveActivityManager.shared.endActivity(dismissTimeInterval: 2)
        }
    }
    
    func removeAllFiles() {
        SaveFileHandler.shared.removeAllFiles()
    }
    
    // 对端取消发送，退出页面
    func exitRecvPage(title: String) {
        isRecvTask = false
        AlertManager.showAlert(title: title, cancelTitle: nil, confirmTitle: "知道了".localized) { [weak self] in
            guard let self = self else { return }
            connectLabel.stopAnimation()
            navigationController?.popViewController(animated: true)
            backAction?()
        }
        if #available(iOS 16.2, *) {
            self.manger?.log(1, "[UI] [MIReceiveFilesView] updateActivity exitRecvPage 对方已取消发送")
            LiveActivityManager.shared.updateActivity(delay: 0, alert: false, progressValue: 0, status: StatusLive.cancelReceive, stateInfo: "对方已取消发送".localized, statusInfo: "")
            self.manger?.log(1, "[UI] [MIReceiveFilesView] endActivity exitRecvPage")
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0){
                LiveActivityManager.shared.endActivity(dismissTimeInterval: 2)
            }
        }
        
        // 取消删除落盘数据
        SaveFileHandler.shared.removeAllFiles()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        self.navigationController?.interactivePopGestureRecognizer?.isEnabled = false
        // 强制更新标签显示
        self.setupLabelsVisibility()
        self.manger?.setTransDelegate(self)
        self.manger?.log(1, "[UI] [MIReceiveFilesView] viewDidAppear]")
    }
    
    deinit {
        
    }
    
    private func startNotifier() {
        // 退出到后台
        NotificationCenter.default.addObserver(self, selector: #selector(self.willResionActive), name: UIApplication.willResignActiveNotification, object: nil)

        // 重回app 监听
        NotificationCenter.default.addObserver(self, selector: #selector(self.didBecome), name: UIApplication.didBecomeActiveNotification, object: nil)
    }
    
    // 重写方法，显示自定义导航栏
    override func mi_preferredNavigationBarHidden() -> Bool {
        return false
    }
    
    @objc func willResionActive() {
        self.waveView?.pause()
    }

    @objc func didBecome() {
        if self.isConnect {
            self.manger?.log(1, "[UI] [MIReceiveFilesView] didBecome")
            self.waveView?.play()
        }
    }
    
    // 设置标签可见性
    private func setupLabelsVisibility() {
        self.senderInfoLabel.textColor = UIColor(white: 0, alpha: 0.9)
        self.fileInfoLabel.textColor = UIColor(white: 0, alpha: 0.65)
        self.connectLabel.textColor = UIColor(white: 0, alpha: 0.65)
        
        // 确保标签不透明
        self.senderInfoLabel.isOpaque = true
        self.fileInfoLabel.isOpaque = true
        self.connectLabel.isOpaque = true
        
        // 强制布局更新
        self.senderInfoLabel.setNeedsDisplay()
        self.fileInfoLabel.setNeedsDisplay()
        self.connectLabel.setNeedsDisplay()
        
        // 确保视图层次结构正确
        if let senderSuperview = senderInfoLabel.superview {
            senderSuperview.bringSubviewToFront(self.senderInfoLabel)
        }
        if let fileSuperview = fileInfoLabel.superview {
            fileSuperview.bringSubviewToFront(self.fileInfoLabel)
        }
        if let fileSuperview = connectLabel.superview {
            fileSuperview.bringSubviewToFront(self.connectLabel)
        }
    }
    
    private func setupUI() {
        self.navigationView?.title = "连接中".localized
        
        // 设置背景图
        let backgroundImage = UIImageView()
        backgroundImage.image = UIImage.bkGround
        backgroundImage.contentMode = .scaleAspectFill
        self.view.addSubview(backgroundImage)
        backgroundImage.snp.makeConstraints {
            $0.edges.equalToSuperview()
        }
        
        self.waveView = LottieAnimationView(name: "receive")
        if let radarView = waveView {
            // 设置动画属性
            radarView.loopMode = .loop
            if UIDevice.current.userInterfaceIdiom == .pad {
                radarView.contentMode = .scaleAspectFill
            }else{
                radarView.contentMode = .scaleAspectFit
            }
            radarView.translatesAutoresizingMaskIntoConstraints = false
            
            // 将动画视图添加到进度圆环视图下方
            view.insertSubview(radarView, belowSubview: self.progressCircleView)
            
            if !self.isInDidRecvAllFiles {
                // 开始播放动画
                radarView.play()
            }
        }
        
        self.view.clipsToBounds = true
        self.view.addSubview(self.waveView!)
        
        self.view.addSubview(self.progressCircleView)
        self.view.addSubview(self.filesImageView)
        self.view.addSubview(self.mediaImageView)
        self.view.addSubview(self.thumbnailImageView)
        
        self.view.addSubview(self.senderInfoLabel)
        self.view.addSubview(self.fileInfoLabel)
        self.view.addSubview(self.errorMessageLabel)
        self.view.addSubview(self.importingLabel)
        self.view.addSubview(self.connectLabel)
        
        self.view.addSubview(self.bottomView)
        
        // 在所有视图添加完成后，确保waveView在正确的层次上并启动动画
        DispatchQueue.main.async {
            if let waveView = self.waveView {
                if !self.isInDidRecvAllFiles {
                    // 启动waveView动画
                    waveView.isHidden = false
                    waveView.play()
                }
                self.view.bringSubviewToFront(self.thumbnailImageView)
            }
        }
        
        // waveView约束
        self.waveView?.snp.makeConstraints { make in
            make.center.equalTo(self.thumbnailImageView)
            make.leading.equalTo(0)
            make.trailing.equalTo(0)
        }
        
        // 进度圆环视图约束
        self.progressCircleView.snp.makeConstraints { make in
            make.center.equalTo(self.thumbnailImageView)
            make.width.height.equalTo(186)
        }
        
        // 多文件堆叠图标约束
        self.filesImageView.snp.makeConstraints { make in
            make.center.equalTo(self.thumbnailImageView)
            make.width.height.equalTo(110)
        }
        
        // 多图片堆叠图标约束
        self.mediaImageView.snp.makeConstraints { make in
            make.centerX.equalTo(self.progressCircleView)
            make.centerY.equalTo(self.progressCircleView.snp.centerY).offset(self.ICON_CENTER_OFFSET)
            make.width.height.equalTo(70)
        }
        
        // 缩略图约束
        self.thumbnailImageView.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.centerY.equalToSuperview().offset(self.ICON_CENTER_OFFSET)
            if UIDevice.current.userInterfaceIdiom == .pad {
                make.width.height.equalTo(120)
            } else {
                make.width.height.equalTo(100)
            }
        }
        
        // 发送者信息标签约束
        self.senderInfoLabel.snp.makeConstraints { make in
            make.top.equalTo(self.progressCircleView.snp.bottom).offset(20)
            make.centerX.equalToSuperview()
            make.leading.trailing.equalToSuperview().inset(20)
        }
        
        // 文件信息标签约束
        self.fileInfoLabel.snp.makeConstraints { make in
            make.top.equalTo(self.senderInfoLabel.snp.bottom).offset(5)
            make.centerX.equalToSuperview()
        }
        
        // error 信息约束
        self.errorMessageLabel.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.centerY.equalTo(self.thumbnailImageView)
        }
        
        //导入中 约束
        self.importingLabel.snp.makeConstraints {make in
            make.centerX.equalToSuperview()
            make.top.equalTo(self.fileInfoLabel.snp.bottom).offset(5)
        }
        
        // 连接中信息约束
        self.connectLabel.snp.makeConstraints { make in
            make.width.equalTo(("正在连接对方热点".localized + "...").widthWithConstrainedHeight(height:99, font: SFCompact(weight: .regular, size: 13)))
            make.centerX.equalToSuperview()
            make.centerY.equalTo(self.thumbnailImageView)
        }
        
        self.cancelButton.snp.makeConstraints { make in
            if UIDevice.current.userInterfaceIdiom == .pad {
                make.size.equalTo(CGSizeMake(334, 46))
            }else {
                make.size.equalTo(CGSizeMake(186, 46))
            }
        }
        
        self.histroyButton.snp.makeConstraints { make in
            make.size.equalTo(CGSizeMake(186, 46))
        }
        
        self.JumpDetailsBtn.snp.makeConstraints { make in
            make.size.equalTo(CGSizeMake(186, 46))
        }
        
        // 取消接收按钮约束
        self.bottomView.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.bottom.equalToSuperview().offset(-22 - MISafeAreaBottom)
        }
    }
    
    // 开始进度动画
    private func startProgressAnimation(progress: CGFloat = 0) {
        DispatchQueue.main.async {
            self.manger?.log(1, "[UI] [MIReceiveFilesView] startProgressAnimation progress: \(progress)")
            // 禁用动画，防止进度条反复跳闪
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            self.progressCircleView.progress = progress
            CATransaction.setCompletionBlock{
                if progress >= 1.0 {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2){
                        self.finishPage()
                    }
                }
            }
            CATransaction.commit()
            if progress >= 1.0 {
                DispatchQueue.main.asyncAfter(deadline: .now() + 5){
                    if #available(iOS 16.2, *) {
                        self.manger?.log(1, "[UI] [MIReceiveFilesView] endActivity startProgressAnimation")
                        LiveActivityManager.shared.endActivity(dismissTimeInterval: 2)
                    }
                }
            }
        }
    }
    
    // 查看文件、照片详情
    @objc private func JumpDetailsTapped() {
        if self.senderType == "0" {
            if SaveFileHandler.shared.allFilesPosition == "file" {
                MIDocumentBrowserManager.share.openFileURLScheme(completion: { _ in })
            } else {
                MIImagePickerManager.shared.openPhotoURLScheme(completion: { _ in })
            }
        } else {
            MIDocumentBrowserManager.share.openFileURLScheme(completion: { _ in })
        }
    }
    
    // 底部按钮点击事件
    @objc private func cancelButtonTapped() {
        if self.isFinish {
            // 查看历史记录
            routeTransferHistoryListController()
            
        } else {
            // 文件接收取消
            self.showIsCancelAlert()
        }
    }
    
    // 取消二次确认弹窗
    private func showIsCancelAlert() {
        if self.isFinish {
            return
        }
        self.cancelAlert = AlertManager.showAlert(title: "确定要取消接收吗？".localized, autoDismiss: false, cancelTitle: "取消接收".localized, cancelAction: {
            self.manger?.cancelReceiveShare(self.udid ?? "")
        }, confirmTitle: "继续接收".localized) {
            self.cancelAlert?.dismiss(animated: true)
        }
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
    }
    
    // 取消接收页面
    func cancelRecvPage() {
        self.normalPage()
        self.navigationView?.title = "接收取消".localized
        self.isConnect = false
        self.navigationView?.leftButtonView?.isHidden = false
        self.navigationView?.backButtonHidden = false
        self.navigationView?.lineView.isHidden = false
        self.errorMessageLabel.isHidden = false
        self.cancelButton.isHidden = true
        self.connectLabel.isHidden = true
        self.connectLabel.stopAnimation()
        self.waveView?.stop()
    }
    
    // 恢复初始页面
    func normalPage() {
        self.imageCount = 0
        self.videoCount = 0
        self.fileCount = 0
        self.isFinish = false
        self.fileInfoLabel.text = ""
        self.manger?.log(1, "[UI] [MIReceiveFilesView] normalPage]")
        self.waveView?.play()
        self.navigationView?.title = "连接中".localized
        self.isConnect = true
        self.cancelButton.setTitle("取消接收".localized, for: .normal)
        self.cancelButton.isHidden = false
        self.histroyButton.isHidden = true
        self.JumpDetailsBtn.isHidden = true
        self.navigationView?.leftButtonView?.isHidden = true
        self.navigationView?.backButtonHidden = true
        self.navigationView?.lineView.isHidden = true
        self.thumbnailImageView.image = nil
        self.thumbnailImageView.layer.cornerRadius = 20
        self.senderInfoLabel.isHidden = true
        self.fileInfoLabel.isHidden = true
        self.progressCircleView.isHidden = true
        self.progressCircleView.progress = 0
        self.filesImageView.isHidden = true
        self.mediaImageView.isHidden = true
        self.errorMessageLabel.isHidden = true
        self.importingLabel.isHidden = true
        self.connectLabel.isHidden = false
        
        connectLabel.textAlignment = .left
        connectLabel.text = "正在连接对方热点".localized
        connectLabel.startAnimation(baseText: "正在连接对方热点")
    }
    
    // 文件接收完成页面
    private func finishPage() {
        self.isFinish = true
        self.cancelAlert?.dismiss(animated: true)
        self.navigationView?.title = "接收完成".localized
        self.isConnect = false
        self.progressCircleView.isHidden = true
        self.errorMessageLabel.isHidden = true
        
        self.navigationView?.leftButtonView?.isHidden = false
        self.navigationView?.backButtonHidden = false
        self.navigationView?.lineView.isHidden = false
        
        // 使用NSAttributedString实现不同部分文本颜色差异化
        let itemCount =  (self.meta?["itemCount"] as? String) ?? "0"
        let fileCount = (self.meta?["fileCount"] as? String) ?? "0"
        let completed = "\(self.senderType == "4" ? fileCount : itemCount) " + "个文件接收完成".localized
        let completedText = NSMutableAttributedString(string: completed)
        completedText.addAttribute(.foregroundColor, value: "#000000".color, range: NSRange(location: 0, length: completed.count))
        
        if self.fileErrCount > 0 {
            let fail = "\(fileErrCount) " + "个文件接收失败".localized
            let failedText = NSMutableAttributedString(string: fail)
            failedText.addAttribute(.foregroundColor, value: UIColor.red, range: NSRange(location: 0, length: fail.count))
            completedText.append(NSMutableAttributedString(string: "，"))
            completedText.append(failedText)
        }
        self.senderInfoLabel.attributedText = completedText
    }
    
    // 获取接收文件类型名称
    func getRecvFileTypeText() {
        var typeText = "文件"
        self.manger?.log(1, "[UI] [MIReceiveFilesView] getRecvFileTypeText senderType: \(self.senderType) allFilesPosition: \(SaveFileHandler.shared.allFilesPosition)")
        if self.senderType == "0" {
            if SaveFileHandler.shared.allFilesPosition == "file" {
                typeText = "文件"
            } else {
                typeText = "照片"
            }
        }
        self.JumpDetailsBtn.setTitle("前往\"\(typeText)\"查看".localized, for: .normal)
    }
}

// 落盘逻辑
extension MIReceiveFilesView {
    
    // 开始落盘创建空文件和句柄
    func startSaveFile(_ fileName: String) -> String? {
        //媒体文件（存图库）
        if self.senderType == "0", SaveFileHandler.shared.allFilesPosition == "library" {
            self.directoryType = SaveFileHandler.shared.getFileTypeByFileName(fileName)
            if self.directoryType == "library_image" || self.directoryType == "library_video" {
                self.lastFileUrl = SaveFileHandler.shared.saveTempFileStart(fileName, self.directoryType!)
            } else if self.directoryType == "library_live_photo" {
                self.lastFileUrl = SaveFileHandler.shared.saveTempFileStart(fileName, "library_live_photo")
            } else if self.directoryType == "is_live_or_image" {
                self.lastFileUrl = SaveFileHandler.shared.saveTempFileStart(fileName, "is_live_or_image")
            } else {
                // 过滤其他匹配的媒体文件
                self.directoryType = "image"
                SaveFileHandler.shared.allFilesPosition = "file"
                self.lastFileUrl = SaveFileHandler.shared.saveFileStart(fileName, self.directoryType!)
            }
        } else if self.senderType == "0" {
            //媒体文件（存文管）
            self.directoryType = "image"
            self.lastFileUrl = SaveFileHandler.shared.saveFileStart(fileName, self.directoryType!)
        } else if self.senderType == "3" || self.senderType == "4" {
            //文件夹和文件（文管下，需要区分混合模式，图片文件夹，音乐文件夹，通讯录文件夹，文件夹（普通文件）存在在ohters中）
            self.directoryType = SaveFileHandler.shared.getFileTypeByFileName(fileName)
            if let allType = SaveFileHandler.shared.allFilesType {
                self.lastFileUrl = SaveFileHandler.shared.saveFileStart(fileName, allType)
            } else {
                self.lastFileUrl = SaveFileHandler.shared.saveFileStart(fileName, self.directoryType!)
            }
        } else {
            self.directoryType = SaveFileHandler.shared.getFileTypeByFileName(fileName)
            self.lastFileUrl = SaveFileHandler.shared.saveFileStart(fileName, self.directoryType!)
        }
        return self.lastFileUrl
    }
    
    // 落盘结束
    func saveFileEnd(_ fileName: String, _ fileSize: Int64) {
        if self.directoryType == "is_live_or_image" {
            guard let manger = self.manger else { return }
            guard let lastFileUrl = self.lastFileUrl else { return }
            // jpg动态图片需要返回给底层拆分
            if manger.isLivePhoto(lastFileUrl) {
                self.directoryType = "library_live_photo"
                SaveFileHandler.shared.imageType = "library_live_photo"
                SaveFileHandler.shared.clearFileParamCache(fileName, fileSize)
            } else {
                // 保存到图库
                self.directoryType = "library_image"
                SaveFileHandler.shared.imageType = "library_image"
                SaveFileHandler.shared.clearFileParamCache(fileName, fileSize)
            }
        } else {
            SaveFileHandler.shared.clearFileParamCache(fileName, fileSize)
        }
        self.directoryType = nil
        self.lastFileUrl = nil
     }
    
    func setProgress(_ progressValue: Float) {
        DispatchQueue.main.async {
            let progressValueStr = String(Int(progressValue * 100))
            self.importingLabel.text = "正在导入至“照片”，请不要退出当前页面".localized + "(\(progressValueStr)%)"
        }
    }
    
    func performAsyncTask(_ file: String) async {
        self.manger?.log(1, "[SaveFile] [MIReceiveFilesView] 异步任务执行：\(Thread.current)")
        self.manger?.log(1, "[SaveFile] [MIReceiveFilesView] 接收结束开始落盘：\(file)")
        let availableMemory = MemoryChecker.availableMemory() / 1024 / 1024
        self.manger?.log(1, "[SaveFile] [MIReceiveFilesView] 可用内存：\(availableMemory)M")
        let freeSpace = StorageChecker.getFreeSpace()
        self.manger?.log(1, "[SaveFile] [MIReceiveFilesView] 剩余硬盘空间：\(StorageChecker.formattedFreeSpace(freeSpace))")
//        let totalSize = Int64(self.meta?["totalSize"] as! String) ?? 0
        // 媒体文件保存到图库落盘需要确保充足空间
        var isFreeSpace = true
        if self.senderType == "0" && SaveFileHandler.shared.allFilesPosition == "library" {
            //磁盘空间不足不能落盘
            isFreeSpace = SaveFileHandler.shared.checkSpace(freeSpace)
        }
        
        // 页面部分
        DispatchQueue.main.async {
            if self.senderType == "0", SaveFileHandler.shared.allFilesPosition == "library" {
                self.importingLabel.text = "正在导入至“照片”，请不要退出当前页面".localized + "(0%)"
                self.importingLabel.isHidden = false
                self.JumpDetailsBtn.isHidden = true
            } else {
                self.JumpDetailsBtn.isHidden = false
            }
            self.cancelButton.isHidden = true
            self.histroyButton.isHidden = false
        }
        
        // 图库落盘前先保存未导入的记录
        if self.senderType == "0", SaveFileHandler.shared.allFilesPosition == "library" {
            do {
                try self.saveRecordNoImporting(SaveFileHandler.shared.tempFilePaths, SaveFileHandler.shared.tempFileSizeDict ?? [String: Int64]())
                self.manger?.log(1, "[SaveFile] [MIReceiveFilesView] 未导入接收记录结束写入")
            } catch {
                self.manger?.log(3, "[SaveFile] [MIReceiveFilesView] 未导入接收记录出错：\(error)")
            }
        }
        
        //异步线程中使用全局的延迟
        DispatchQueue.global().asyncAfter(deadline: .now() + 0.5){
            // 落盘结束
            SaveFileHandler.shared.saveFileTaskEnd(customprogress: {[weak self] progress in
                self?.setProgress(progress)
            }) {[weak self] allFileList, fileList, localIdentifiers, tempFileSizeDict in
                do {
                    guard let self = self else { return }
                    self.manger?.log(1, "[SaveFile] [MIReceiveFilesView] 接收记录开始写入")
                    SaveFileHandler.shared.isSaveFileing = false
                    DispatchQueue.main.async {
                        //延迟退出，防止结束太快，接收接收流程未走完
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2){
                            self.importingLabel.isHidden = true
                            self.importingLabel.text = "正在导入至“照片”，请不要退出当前页面".localized + "(0%)"
                            self.cancelButton.isHidden = true
                            self.histroyButton.isHidden = false
                            self.JumpDetailsBtn.isHidden = false
                        }
                    }
                    // 非图库
                    if (fileList?.count ?? 0) > 0 {
                        // 存储日志
                        try self.saveRecord(allFileList, fileList, localIdentifiers, tempFileSizeDict)
                    } else {
                        if !isFreeSpace {
                            AlertManager.showAlert(title: "存储空间不足，导入失败，请清理空间后在接收记录中重新导入".localized, cancelTitle: nil, confirmTitle: "知道了".localized) {
                            }
                        }
                    }
                    self.manger?.log(1, "[SaveFile] [MIReceiveFilesView] 接收记录结束写入")
                } catch {
                    self?.manger?.log(3, "[SaveFile] [MIReceiveFilesView] 接收记录出错：\(error)")
                }
                self?.manger?.log(1, "[SaveFile] [MIReceiveFilesView] 落盘结束：\(file)")
            }
        }
    }
}

extension MIReceiveFilesView: TransDelegate {
    
    //A侧取消接收
    func didIsCancel(_ isCancel: Bool) {
        if isCancel {
            self.cancelRecv()
        }
    }
    
    //废弃
    func didReceiveCancel(_ udid: String) {
        self.exitRecvPage(title: "对方取消发送，接收失败".localized)
    }
    
    func didRecvStart(_ udid: String, file: String) -> String {
        var path = ""
        // 落盘逻辑开始
        if udid == self.udid {
            path = self.startSaveFile(file) ?? ""
        }
        self.manger?.log(1, "[filePath] \(path)")
        return path
    }
    
    //废弃
    func didRecvData(_ udid: String, data: Data, file: String) {}
    
    func imageFromBase64(base64: String) -> UIImage? {
        guard let data = Data(base64Encoded: base64, options: .ignoreUnknownCharacters) else {
            self.manger?.log(1, "[UI] [MIReceiveFilesView] Error: Invalid base64 string.")
            return nil
        }
        
        if let image = UIImage(data: data) {
            recvBase64IsScuccess = true
            return image
        }
        
        recvBase64IsScuccess = false
        self.manger?.log(1, "[UI] [MIReceiveFilesView] Failed to create image from data on all attempts")
        return nil
    }
    
    func didRecvThumb(_ data: String) {
        DispatchQueue.main.async {
            if let image = self.imageFromBase64(base64: data) {
                self.waveView?.stop()
                self.navigationView?.title = "接收中".localized
                self.isConnect = false
                self.connectLabel.isHidden = true
                self.connectLabel.stopAnimation()
                
                self.recvThumb = image
                self.manger?.log(1, "[UI] [MIReceiveFilesView] 图像加载成功")
            } else {
                self.manger?.log(1, "[UI] [MIReceiveFilesView] 图像加载失败")
            }
        }
    }
    
    // 获取文件的时间信息
    func didRecvTime(_ timeInfo: String) {
        SaveFileHandler.shared.saveTimeInfo(timeInfo: timeInfo)
    }
    
    //注意：小文件传输不会触发 didUpdateProgress
    func didUpdateProgress(_ udid: String, percent: Double, stat: [AnyHashable: Any]) {
        DispatchQueue.main.async {
            let fileListStr = stat["fileList"] as? String ?? ""
            if fileListStr != "[]" && fileListStr != "" {
                self.allFilesList = stat
            }
            self.updateProgress(stat: stat)
        }
    }

    func initView(files: [String]) {
        self.allFilesList = [:]
        self.waveView?.stop()
        self.manger?.log(1, "[UI] [MIReceiveFilesView] waveView is nil:\(self.waveView == nil)")
        self.navigationView?.title = "接收中".localized
        self.isConnect = false
        self.connectLabel.isHidden = true
        self.connectLabel.stopAnimation()
        
        self.progressCircleView.isHidden = false
        self.fileInfoLabel.isHidden = false
        self.thumbnailImageView.image = self.recvThumb
        self.manger?.log(1, "[UI] [MIReceiveFilesView] thumbnailImageView updateConstraints")
        self.thumbnailImageView.contentMode = self.senderType == "3" ? .scaleAspectFit : .scaleAspectFill
        if self.senderType == "3" {
            self.filesImageView.isHidden = files.count <= 1
        } else if self.senderType == "0" {
            self.mediaImageView.isHidden = files.count <= 1
        }
        self.importingLabel.isHidden = false
        self.senderInfoLabel.isHidden = false
        self.allSmallFIlesList = files
    }
    
    func didRecvAllFiles(_ udid: String, files: [String], totalBytes: NSNumber) {
        //isRecvTask = true
        
        
        // TODO: Activity开始
        if #available(iOS 16.2, *) {
            
            self.manger?.log(1, "[UI] [MIReceiveFilesView] didRecvAllFiles  接收中...")
            LiveActivityManager.shared.updateActivity(delay: 0, alert: false, progressValue: 0, status: StatusLive.receive, stateInfo: "接收中...".localized, statusInfo: "")
        }
        
        DispatchQueue.main.async {
            self.manger?.log(1, "[UI] [MIReceiveFilesView] didRecvAllFiles")
            self.isInDidRecvAllFiles = true
            self.allFiles = files
            self.initView(files: files)
        }
    
        self.udid = udid
        self.totalBytes = Int(self.meta?["totalSize"] as? String ?? "0")
    }

    func didRecvEnd(_ udid: String, file: String, isFinished: Bool, fileSize: Int64) {
        // 全部结束
        if isFinished {
            
            self.isFinish = isFinished
       
            
            
            self.manger?.log(1, "[UI] [MIReceiveFilesView] didRecvEnd")
            isRecvTask = false
            DispatchQueue.main.async {
                self.getRecvFileTypeText()
                let fileListStr = self.allFilesList["fileList"] as? String ?? ""
                if fileListStr == "[]" || fileListStr == "" {
                    // 小文件传输完成
                    var files: [Any] = []
                    for file in self.allSmallFIlesList {
                        files.append(["filename": file, "status": "completed"])
                    }
                    do {
                        let jsonData = try JSONSerialization.data(withJSONObject: files, options: .prettyPrinted)
                        if let jsonString = String(data: jsonData, encoding: .utf8) {
                            let stat: [AnyHashable: Any] = [
                                "totalBytes": self.totalBytes,
                                "totalTransfer": self.totalBytes,
                                "fileList": jsonString
                            ]
                            self.startProgressAnimation(progress: 1)
                            self.showFileInfo(stat: stat, fileListStr: jsonString)
                        }
                    } catch {
                    }
                } else {
                    // 大文件传输完成
                    self.startProgressAnimation(progress: 1)
//                    self.showFileInfo(stat: self.allFilesList, fileListStr: fileListStr)
                }
            }
        }
        self.manger?.log(1, "文件接收结束：\(file),是否全部结束\(isFinished)")
        // 落盘结束
        if !isFinished, file != "" {
            self.saveFileEnd(file, fileSize)
        }
        if isFinished {
            Task {
                await self.performAsyncTask(file)
            }
        }
    }

    func didConnect(_ udid: String, status: String) {
        if status == "joinwifi" {
            connectLabel.textAlignment = .center
            connectLabel.text = "热点连接中...".localized
        }
    }
    
    func didSendProgress(_ udid: String, percent: Double) {}
    
    func didSendStart(_ udid: String, file: String) {}
    
    func didSendData(_ udid: String, data: Data, file: String) {}
    
    func didSendEnd(_ udid: String, file: String, isFinished: Bool) {}
    
    func didLivePhotoReady(_ imagePath: String, videoPath: String) {}
}

extension MIReceiveFilesView {
    // 更新进度
    func updateProgress(stat: [AnyHashable: Any]) {
        let totalTransfer = (stat["totalTransfer"] as? Double) ?? 0.0
        let totalBytes = Double(self.meta?["totalSize"] as? String ?? "0") ?? 1.0
        let fileListStr = stat["fileList"] as? String ?? ""
        self.manger?.log(1, "[UI] [MIReceiveFilesView] updateProgress totalTransfer: \(totalTransfer) totalBytes: \(totalBytes)")
        if totalBytes == 0 {
            return
        }
        let progress = totalTransfer / totalBytes
       
        self.startProgressAnimation(progress: progress)
        self.showFileInfo(stat: stat, fileListStr: fileListStr)
        if #available(iOS 16.2, *) {
            let formateNumber = Int(progress * 100)
            let numberProgress = CGFloat(formateNumber) / 100.0
            self.manger?.log(1, "[UI] [MIReceiveFilesView] updateActivity updateProgress 接收中...")
            LiveActivityManager.shared.updateActivity(delay: 0, alert: false, progressValue: numberProgress, status: StatusLive.receive, stateInfo: progress < 1 ? "接收中...".localized : "接收完成".localized, statusInfo: self.fileInfoLabel.text ?? "")
        }
    }
    
    func showFileIcon(fileExtension: String) {
        if self.recvBase64IsScuccess {
            return
        }
        var image: UIImage?
        switch fileExtension {
        case "7z":
            image = UIImage.icon7Z
        case "amr":
            image = UIImage.iconAmr
        case "ape":
            image = UIImage.iconApe
        case "bag":
            image = UIImage.iconBag
        case "caj":
            image = UIImage.iconCaj
        case "chm":
            image = UIImage.iconChm
        case "flac":
            image = UIImage.iconFlac
        case "fold":
            image = UIImage.iconFold
        case "html":
            image = UIImage.iconHtml
        case "jpeg", "png", "gif", "bmp", "tiff", "tif", "webp", "svg", "heic", "heif", "ico", "psd", "jpg":
            image = UIImage.iconImg
        case "kdh":
            image = UIImage.iconKdh
        case "link":
            image = UIImage.iconLink
        case "log":
            image = UIImage.iconLog
        case "m4a":
            image = UIImage.iconM4A
        case "mp3":
            image = UIImage.iconMp3
        case "nh":
            image = UIImage.iconNh
        case "overlap":
            image = UIImage.iconOverlap
        case "pdf":
            image = UIImage.iconPdf
        case "ppt":
            image = UIImage.iconPpt
        case "rar":
            image = UIImage.iconRar
        case "teb":
            image = UIImage.iconTeb
        case "vcf", "zcf", "text":
            image = UIImage.iconText
        case "txt":
            image = UIImage.iconTxt
        case "wav":
            image = UIImage.iconWav
        case "wma":
            image = UIImage.iconWma
        case "doc", "docx", "docm", "dot", "dotx", "dotm", "rtf":
            image = UIImage.iconWord
        case "xml":
            image = UIImage.iconXml
        case "zip":
            image = UIImage.iconZip
        default:
            image = UIImage.iconUnknown
        }
        
        let noChangeImageArr = ["vcf"]
        if !noChangeImageArr.contains(fileExtension) {
            self.thumbnailImageView.image = image
            return
        }
        self.thumbnailImageView.image = image
    }
    
    func showFileInfo(stat: [AnyHashable: Any], fileListStr: String) {
//        if fileListStr == "[]" || fileListStr == "" {
//            return
//        }
        let files = stat["fileList"] as? String ?? ""
        let fileList = getArrayFromJSONString(jsonString: files)
        let totalTransfer = stat["totalTransfer"] as? Int ?? 0
        
        self.manger?.log(1, "[UI] [MIReceiveFilesView] showFileInfo fileList count: \(fileList?.count ?? 0) totalTransfer: \(totalTransfer)")
        self.manger?.log(1, "[UI] [MIReceiveFilesView] showFileInfo files: \(files)")
        for item in fileList ?? [] {
            if let fileDict = item as? [String: Any]
            {
                let status = fileDict["status"] as! String
                let filename = fileDict["filename"] as! String
                let fileURL = URL(fileURLWithPath: filename)
                let fileExtension = "\(fileURL.pathExtension)".lowercased()
                
                if status == "inprogress" || status == "completed" {
                    self.showFileIcon(fileExtension: fileExtension)
                }
                switch fileExtension {
                case "jpg", "jpeg", "png", "gif", "bmp", "tiff", "tif", "raw", "psd", "webp", "heic", "heif", "avif", "dng", "svg":
                    imageCount += 1
                case "mp4", "mov", "avi", "mkv", "wmv", "webm", "flv", "mpeg", "mpg", "mts", "m2ts", "ts", "rmvb":
                    videoCount += 1
                default:
                    fileCount += 1
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
//        if imageCount > 0 || videoCount > 0 || fileCount > 0 {
            self.fileInfoLabel.text = "\(fileInfoText)\(fileSize)"
//        }
    }
}

extension MIReceiveFilesView: PHPickerViewControllerDelegate {
    @available(iOS 14, *)
    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        picker.dismiss(animated: true)
    }
}

extension MIReceiveFilesView {
    func getFileSize(atPath path: String) -> Int64 {
        guard FileManager.default.fileExists(atPath: path) else {
            self.manger?.log(3, "[SaveFile] [MIReceiveFilesView] 文件不存在\(path)")
            return 0
        }
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: path)
            return attributes[.size] as? Int64 ?? 0
        } catch {
            self.manger?.log(3, "[SaveFile] [MIReceiveFilesView] 获取文件大小失败：\(path)：\(error)")
            return 0
        }
    }
    
    func getFileName(_ path: String) -> String {
        let fileName = (path as NSString).lastPathComponent
        return fileName
    }
    
    // 插入未导入的记录
    func saveRecordNoImporting(_ tempFiles: [(String, String, String)]?, _ tempFileSizeDict: [String: Int64]) throws {
        // 保存记录
        let record = MITransferRecord()
        if let hwid = self.hwid {
            record.hwId = hwid
        } else {
            record.deviceIcon = "device_icon_\(Int.random(in: 1 ... 5))"
        }
        record.deviceId = self.udid
        record.deviceType = self.meta?["deviceType"] as? Int
        record.deviceName = self.meta?["senderName"] as? String
        record.transferType = .receive
        record.transferTime = Date()
        var files: [MITransferFile] = []
        for (_, _, path) in tempFiles ?? [] {
            let model = MITransferFile()
            model.fileSize = tempFileSizeDict[path]
            model.fileName = self.getFileName(path)
            var tempPath = path
            let tiemInfo = SaveFileHandler.shared.getTimeinfo(path)
            if path.contains("/temp/") {
               tempPath = (path.components(separatedBy: "/temp/")[1])
            }
            //时间信息临时保存到路径记录中（临时处理）
            model.fileUrl = "\(tiemInfo.0)|\(tiemInfo.1)|\(tiemInfo.2)/temp/\(tempPath)"
            model.fileFolder = "image"
            model.fileExtension = (path as NSString).pathExtension
            model.status = .inProgress
            model.fileType = .photoAndVideo
            files.append(model)
        }
        
        record.sendContent = files
        if !record.sendContent.isEmpty {
            Task {
                do {
                    try await MIWCDBManager.shared.insertRecordAsync(record)
                } catch {}
            }
        }
    }
    
    func saveRecord(_ allFilePaths: [String]?, _ filePaths: [String]?, _ localIdentifiers: [String: String], _ tempFileSizeDict: [String: Int64]) throws {
        // 保存记录
        let record = MITransferRecord()
        if let hwid = self.hwid {
            record.hwId = hwid
        } else {
            record.deviceIcon = "device_icon_\(Int.random(in: 1 ... 5))"
        }
        record.deviceId = self.udid
        record.deviceName = self.meta?["senderName"] as? String
        record.transferType = .receive
        record.deviceType = self.meta?["deviceType"] as? Int
        record.transferTime = Date()
      
        var files: [MITransferFile] = []
      
        //媒体场景，文件场景，文件夹场景通用一个逻辑（都有可能存在媒体文件落盘和文管文件落盘）
        if self.senderType == "0" || self.senderType == "3" || self.senderType == "4"  {
            //文管场景下可能存在媒体文件、媒体场景下可能存在文管文件（逻辑同样处理）
            for path in allFilePaths ?? [] {
                if let paths = filePaths, paths.contains(path) {
                    let model = MITransferFile()
                    model.fileSize = self.getFileSize(atPath: path)
                    model.fileName = self.getFileName(path)
                    let tempPath = (path.components(separatedBy: "Documents")[1])
                    model.fileUrl = "/Documents" + tempPath
                    //文件夹适配只保存others
                    if tempPath.contains("/others/") {
                        model.fileFolder = "others"
                    } else {
                        let url = URL(fileURLWithPath: path)
                        let preDirectory = url.deletingLastPathComponent()
                        let fileFolder = preDirectory.lastPathComponent
                        model.fileFolder = fileFolder
                    }
                    model.fileExtension = (path as NSString).pathExtension
                    model.fileType = .file
                    model.status = .success
                    files.append(model)
                }
                else if let localIdentifier = localIdentifiers[path], localIdentifier != "" {
                    let model = MITransferFile()
                    model.fileSize = tempFileSizeDict[path]
                    model.fileName = self.getFileName(path)
                    model.fileUrl = path
                    model.fileFolder = "image"
                    model.fileExtension = (path as NSString).pathExtension
                    model.identifier = localIdentifier
                    model.fileType = .photoAndVideo
                    model.status = .success
                    files.append(model)
                }
            }
        } else {
            // 通讯录数据组装
            let model = MITransferFile()
            for path in filePaths ?? [] {
                model.fileSize = self.getFileSize(atPath: path)
                model.fileName = self.getFileName(path)
                let tempPath = (path.components(separatedBy: "Documents")[1])
                model.fileUrl = "/Documents" + tempPath
                let url = URL(fileURLWithPath: path)
                let preDirectory = url.deletingLastPathComponent()
                let fileFolder = preDirectory.lastPathComponent
                model.fileFolder = fileFolder
                model.fileExtension = (path as NSString).pathExtension
                model.fileType = .contacts
                model.status = .success
                files.append(model)
            }
        }

        record.sendContent = files
        if !record.sendContent.isEmpty {
            Task {
                do {
                    try await MIWCDBManager.shared.insertRecordAsync(record)
                } catch {}
            }
        }
    }
}
