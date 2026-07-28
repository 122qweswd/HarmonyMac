//
//  MIMACNearbyUsersCell.swift
//  MutualInfection
//
//  Created by apple on 2025/10/16.
//


import AppKit
import SnapKit
import Lottie

class MINSClickGestureRecognizer: NSClickGestureRecognizer {
    override func shouldRequireFailure(of otherGestureRecognizer: NSGestureRecognizer) -> Bool {
        return true;
    }
}

class MIMACNearbyUsersCell: NSCollectionViewItem {

    // 添加点击回调
    var onDeviceTapped: ((MIDevice) -> Void)?
    var hadClick = false
    var onDragFileToDevice: ((MIDevice,[URL]) -> Void)?
    
    
    var userInfo: MIDevice?{
        didSet{

            self.currentDeviceStatus = userInfo?.deviceStatus ?? .normal
            deviceNameLabel.stringValue = userInfo?.name ?? ""
            // 延迟调整，等待布局更新
//            DispatchQueue.main.async {
//                self.adjustFontSizeIfNeeded()
//            }
            self.updateProgress(progress: userInfo?.progress ?? 0)
        }
    }
    
    func updateProgress(progress:CGFloat = 0) {
//        print("updateProgress:\(progress)")
        
        if progress <= 0.0 {
            circularProgress.isHidden = true
            return
        }
        
        circularProgress.isHidden = false
        // 更新进度条
        circularProgress.setProgress(progress)
        
//        if progress >= 1.0 {
//            // 进度条完成后，自动将状态改为已完成
////            self.userInfo?.deviceStatus = .completed
////            self.currentDeviceStatus = .completed
//            
//            let userInfo: MIDevice? = self.userInfo
////            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0){
//                if self.userInfo != nil,
//                   userInfo?.hwId == self.userInfo?.hwId {
//                    self.circularProgress.isHidden = true
//                    self.userInfo?.progress = 0
//                    self.circularProgress.setProgress(self.userInfo?.progress ?? 0)
//                    
////                    self.deviceImageView.image = MIDeviceHeaderWCDBManager.sharedManager().getDeviceHeader(self.userInfo?.hwId ?? "",self.userInfo?.isShowIcon ?? false,deviceTye: self.userInfo?.deviceType ?? 1)
//                }
////            }
//        }
   }
    
    var currentDeviceStatus: DeviceStatus = .normal{
        didSet{
            
            if Thread.isMainThread{
                changeStatus()
            }else{
                DispatchQueue.main.async{
                    self.changeStatus()
                }
            }
            
        }
    }
    private func showbgViewHideWithImg(){
        // waitingBGView图只要动画时用，头像换新图
        // 默认设为隐藏，后续根据逻辑反转
//            waitingBGView.isHidden = true
//            
//            // 1. 先判断userInfo是否存在，不存在直接返回
//            guard let userInfo = self.userInfo else { return }
//            
//            // 2. 拿到调用getDeviceHeader时的三个核心参数（和你设置image的参数完全一致）
//        let hwId = userInfo.hwId
//        let isShowIcon = userInfo.isShowIcon
//        let deviceType = userInfo.deviceType
//            
//            // 3. 复现getDeviceHeader的核心逻辑：判断是否返回默认设备图（iPhone/Pad/Mac）
//            var isDefaultDeviceImage = false
//            if !isShowIcon {
//                // 条件1：isShowIcon为false → 一定返回默认图
//                isDefaultDeviceImage = true
//            } else {
//                // 条件2：isShowIcon为true → 查数据库，无图则返回默认图
//                do {
//                    let dbManager = MIDeviceHeaderWCDBManager.sharedManager()
//                    let deviceHeaderImage: DeviceHeaderImage? = try dbManager.database?.getObject(
//                        fromTable: dbManager.tableName,
//                        where: DeviceHeaderImage.CodingKeys.hwId.rawValue == hwId
//                    )
//                    // 数据库无数据 或 headerImage为空 → 返回默认图
//                    isDefaultDeviceImage = (deviceHeaderImage?.headerImage == nil)
//                } catch {
//                    // 数据库查询失败 → 返回默认图
//                    isDefaultDeviceImage = true
//                }
//            }
//            
//            // 4. 根据是否是默认图，设置waitingBGView的隐藏状态
//            waitingBGView.isHidden = !isDefaultDeviceImage
        
            
    }
    private func changeStatus(){
        
        self.waitingView.isHidden = true
        self.waitingBGView.isHidden = true
        self.deviceImageView.isHidden = false
        self.stopAction()
        Gloable.isNotSendingStatus = true
        NotificationCenter.default.post(name: NSNotification.Name("GetIsSendingStatus"), object: nil)
        if  self.currentDeviceStatus == .completed && self.userInfo?.progress == 0{
            self.statusLabel.stringValue = "已发送".localized
            self.statusLabel.textColor =  .mi.hex("#0A59F7")
            self.deviceImageView.image = NSImage.iconFinish
            showbgViewHideWithImg()
//                    self.deviceImageView.image = MIDeviceHeaderWCDBManager.sharedManager().getDeviceHeader(self.userInfo?.hwId ?? "",self.userInfo?.isShowIcon ?? false, deviceTye: self.userInfo?.deviceType ?? 1)
//                    return
        }
        switch self.currentDeviceStatus {
        
        case .normal:      // 在线，未选择 - 正常设备状态
            if userInfo?.fristSendEnd != true {
                self.statusLabel.stringValue = ""
            }
//            self.statusLabel.textColor =  .mi.hex("#0A59F7")
            self.deviceImageView.image = MIDeviceHeaderWCDBManager.sharedManager().getDeviceHeader(self.userInfo?.hwId ?? "",self.userInfo?.isShowIcon ?? false, deviceTye: self.userInfo?.deviceType ?? 1)
            showbgViewHideWithImg()
        case .connecting,.connected:  // 连接中状态 - 正在建立连接
            Gloable.isNotSendingStatus = false
            NotificationCenter.default.post(name: NSNotification.Name("GetIsSendingStatus"), object: nil)
            self.waitingView.isHidden = false
            self.waitingBGView.isHidden = false
            self.deviceImageView.isHidden = true
            self.startAction()
            self.statusLabel.stringValue = "连接中".localized
            self.statusLabel.textColor =  .mi.hex("#0A59F7")
            self.deviceImageView.image = MIDeviceHeaderWCDBManager.sharedManager().getDeviceHeader(self.userInfo?.hwId ?? "",self.userInfo?.isShowIcon ?? false, deviceTye: self.userInfo?.deviceType ?? 1)
            showbgViewHideWithImg()
        case .waiting:     // 等待中状态 - 等待用户确认或网络连接
            Gloable.isNotSendingStatus = false
            NotificationCenter.default.post(name: NSNotification.Name("GetIsSendingStatus"), object: nil)
            self.statusLabel.stringValue = "等待中".localized
            self.statusLabel.textColor =  .mi.hex("#0A59F7")
            self.deviceImageView.image = MIDeviceHeaderWCDBManager.sharedManager().getDeviceHeader(self.userInfo?.hwId ?? "",self.userInfo?.isShowIcon ?? false, deviceTye: self.userInfo?.deviceType ?? 1)
            showbgViewHideWithImg()
        case .sending:     // 发送中状态 - 保持动画不变
            Gloable.isNotSendingStatus = false
            NotificationCenter.default.post(name: NSNotification.Name("GetIsSendingStatus"), object: nil)
            self.statusLabel.stringValue = "发送中".localized
            self.statusLabel.textColor =  .mi.hex("#0A59F7")
            self.deviceImageView.image = MIDeviceHeaderWCDBManager.sharedManager().getDeviceHeader(self.userInfo?.hwId ?? "",self.userInfo?.isShowIcon ?? false, deviceTye: self.userInfo?.deviceType ?? 1)
            showbgViewHideWithImg()
        case .completed:   // 发送完成 - 保持白色对钩不变
            self.statusLabel.stringValue = "已发送".localized
            self.statusLabel.textColor =  .mi.hex("#0A59F7")
            self.deviceImageView.image = NSImage(named: "icon_finish")
            showbgViewHideWithImg()
            
            
            
            self.circularProgress.isHidden = true
            self.userInfo?.progress = 0
            self.circularProgress.setProgress(self.userInfo?.progress ?? 0)
            DispatchQueue.main.asyncAfter(deadline: .now()+2.0){
                if self.currentDeviceStatus == .completed {
                    self.currentDeviceStatus = .normal
                    self.userInfo?.deviceStatus = .normal
                }
            }
//                    self.deviceImageView.image = MIDeviceHeaderWCDBManager.sharedManager().getDeviceHeader(self.userInfo?.hwId ?? "",self.userInfo?.isShowIcon ?? false, deviceTye: self.userInfo?.deviceType ?? 1)
        case .cancelled:   // 取消发送 - 用户取消或发送失败
            self.deviceImageView.image = MIDeviceHeaderWCDBManager.sharedManager().getDeviceHeader(self.userInfo?.hwId ?? "",self.userInfo?.isShowIcon ?? false, deviceTye: self.userInfo?.deviceType ?? 1)
            showbgViewHideWithImg()
            // 更新第二行文字
            self.statusLabel.stringValue = "发送取消".localized
            self.statusLabel.textColor = .mi.hex("#E02020")
        case .needreceive:  //待接收
            Gloable.isNotSendingStatus = false
            NotificationCenter.default.post(name: NSNotification.Name("GetIsSendingStatus"), object: nil)
            self.waitingView.isHidden = false
            self.waitingBGView.isHidden = false
            self.deviceImageView.isHidden = true
            self.startAction()
            self.deviceImageView.image = MIDeviceHeaderWCDBManager.sharedManager().getDeviceHeader(self.userInfo?.hwId ?? "",self.userInfo?.isShowIcon ?? false, deviceTye: self.userInfo?.deviceType ?? 1)
            showbgViewHideWithImg()
            self.statusLabel.stringValue = "待接收".localized
            self.statusLabel.textColor =  .mi.hex("#0A59F7")
        case .disconnected: //连接断开
            self.deviceImageView.image = MIDeviceHeaderWCDBManager.sharedManager().getDeviceHeader(self.userInfo?.hwId ?? "",self.userInfo?.isShowIcon ?? false, deviceTye: self.userInfo?.deviceType ?? 1)
            showbgViewHideWithImg()
            self.statusLabel.stringValue = "连接断开".localized
            self.statusLabel.textColor = .mi.hex("#E02020")
        case .didReject: //对方拒绝
            self.deviceImageView.image = MIDeviceHeaderWCDBManager.sharedManager().getDeviceHeader(self.userInfo?.hwId ?? "",self.userInfo?.isShowIcon ?? false, deviceTye: self.userInfo?.deviceType ?? 1)
            showbgViewHideWithImg()
            self.statusLabel.stringValue = "已拒绝".localized
            self.statusLabel.textColor = .mi.hex("#E02020")
        case .peerBusy: //对方忙
            self.deviceImageView.image = MIDeviceHeaderWCDBManager.sharedManager().getDeviceHeader(self.userInfo?.hwId ?? "",self.userInfo?.isShowIcon ?? false, deviceTye: self.userInfo?.deviceType ?? 1)
            showbgViewHideWithImg()
            self.statusLabel.stringValue = "对方忙".localized
            self.statusLabel.textColor = .mi.hex("#E02020")
        case .selfBusy: //已方忙
            self.deviceImageView.image = MIDeviceHeaderWCDBManager.sharedManager().getDeviceHeader(self.userInfo?.hwId ?? "",self.userInfo?.isShowIcon ?? false, deviceTye: self.userInfo?.deviceType ?? 1)
            showbgViewHideWithImg()
            self.statusLabel.stringValue = "已方忙".localized
            self.statusLabel.textColor = .mi.hex("#E02020")
        case .error:
            self.deviceImageView.image = MIDeviceHeaderWCDBManager.sharedManager().getDeviceHeader(self.userInfo?.hwId ?? "",self.userInfo?.isShowIcon ?? false, deviceTye: self.userInfo?.deviceType ?? 1)
            showbgViewHideWithImg()
            self.statusLabel.stringValue = "发送失败".localized
            self.statusLabel.textColor = .mi.hex("#E02020")
        case .timeout:
            self.deviceImageView.image = MIDeviceHeaderWCDBManager.sharedManager().getDeviceHeader(self.userInfo?.hwId ?? "",self.userInfo?.isShowIcon ?? false, deviceTye: self.userInfo?.deviceType ?? 1)
            showbgViewHideWithImg()
            self.statusLabel.stringValue = "请求超时".localized
            self.statusLabel.textColor = .mi.hex("#E02020")
        case .nospace:
            self.deviceImageView.image = MIDeviceHeaderWCDBManager.sharedManager().getDeviceHeader(self.userInfo?.hwId ?? "",self.userInfo?.isShowIcon ?? false, deviceTye: self.userInfo?.deviceType ?? 1)
            showbgViewHideWithImg()
            self.statusLabel.stringValue = "内存不足".localized
            self.statusLabel.textColor = .mi.hex("#E02020")
        }
    }
    
    // 添加进度条相关属性
    private lazy var circularProgress: CircularProgressView = {
        let progress = CircularProgressView()
        progress.translatesAutoresizingMaskIntoConstraints = false
        progress.isHidden = true
        return progress
    }()
    
    private lazy var deviceImageView: MICustomImageView = {
        let imageView = MICustomImageView()

        imageView.wantsLayer = true
        imageView.imageScaling = .scaleAxesIndependently
        imageView.layer?.cornerRadius = 32
        imageView.clipsToBounds = true
        imageView.layer?.backgroundColor = .clear
        /// 拖拽结束回调
        imageView.dragOperationBlock = { [weak self] fileURLs in
            guard  let userInfo = self?.userInfo else { return  }
            print("要发送的文件路径 - \(fileURLs)")
            self?.onDragFileToDevice?(userInfo,fileURLs)
            
        }

        return imageView
    }()
    
    private lazy var deviceImageShadowView: ShadowView = {
        let view = ShadowView()
        view.wantsLayer = true
        // 自定义阴影参数（肉眼绝对可见）
        view.shadowColor = .black
        view.shadowOffset = CGSize(width: 0, height: -1) // 下偏移
        view.shadowRadius = 2           
        view.shadowOpacity = 0.2
        view.fillColor = NSColor.white.withAlphaComponent(0.2)
        view.cornerRadius = 32
        
        return view
    }()
    private lazy var deviceNameLabel: NSTextField = {
        let label = NSTextField()
        label.isBordered = false
        label.translatesAutoresizingMaskIntoConstraints = false
        label.alignment = .center
        label.font = .mi.pingFangSCRegular(size: 12)
        label.textColor = .mi.hex("#000000", alpha: 1)
        label.backgroundColor = .clear
        label.isEditable = false
        label.isSelectable = false
        label.lineBreakMode = .byCharWrapping
        label.maximumNumberOfLines = 2
        
        label.cell?.wraps = true
        label.cell?.isScrollable = false // 必须设为false才能换行
        label.cell?.truncatesLastVisibleLine = true
        return label
    }()
    lazy var waitingBGView: NSImageView = {
        let bgview = NSImageView(image: NSImage.imgCellBg)
        bgview.wantsLayer = true
        bgview.imageScaling = .scaleAxesIndependently
        bgview.isHidden = true
        return bgview
    }()
    lazy var waitingView : LottieAnimationView = {
        let waitingView = LottieAnimationView(name: "waiting")
        waitingView.isHidden = true
        waitingView.loopMode = .loop
        waitingView.contentMode = .scaleAspectFit
//        waitingView.backgroundColor = "#ffffff".color.withAlpha(1)
//        waitingView.layer?.cornerRadius = 18
//        waitingView.clipsToBounds = true
        waitingView.translatesAutoresizingMaskIntoConstraints = false
        
        waitingView.wantsLayer = true
        guard let layer = waitingView.layer else {
            return waitingView
        }
//        let bgcolor:NSColor = .mi.hex("#ffffff", alpha: 1)
//                layer.backgroundColor = bgcolor.cgColor
//        
//                // 3. 设置圆角
//                layer.cornerRadius = 18
//        
//                // 4. 开启裁剪（超出圆角的内容会被裁剪）
//                layer.masksToBounds = true  // NSView 中用 masksToBounds 替代 clipsToBounds
        
        return waitingView
    }()
    
    private lazy var statusLabel: NSTextField = {
        let label = NSTextField()
        label.isBordered = false
        label.translatesAutoresizingMaskIntoConstraints = false
        label.alignment = .center
        label.font = .mi.pingFangSCRegular(size: 12)
        label.textColor = .mi.hex("#0A59F7", alpha: 1)
        label.backgroundColor = .clear
        label.isEditable = false
        label.isSelectable = false
        label.isHidden = false
        label.maximumNumberOfLines = 1
        label.lineBreakMode = .byTruncatingTail
        return label
    }()
    private func adjustFontSizeIfNeeded() {
        
        guard let font = deviceNameLabel.font else { return }
        
        let text = deviceNameLabel.stringValue
        let labelWidth = deviceNameLabel.bounds.width - 8 // 留一些边距
        let minFontSize: CGFloat = 5.0
        let maxFontSize: CGFloat = 12.0
        
        if text.isEmpty || labelWidth <= 0 { return }
        
        // 从最大字号开始测试
        var currentFontSize = maxFontSize
        var fittingFontSize = maxFontSize
        
        while currentFontSize >= minFontSize {
            let testFont = NSFont(descriptor: font.fontDescriptor, size: currentFontSize) ?? font
            let textSize = text.size(withAttributes: [.font: testFont])
            
            if textSize.width <= labelWidth {
                fittingFontSize = currentFontSize
                break
            }
            
            currentFontSize -= 0.5
        }
        
        deviceNameLabel.font = NSFont(descriptor: font.fontDescriptor, size: fittingFontSize) ?? font
    }
    
    override func loadView() {
         view = NSView()
        setupUI()
        setupConstraints()
        self.setupTapGesture()
     }
    // MARK: - Initialization
    override init(nibName nibNameOrNil: NSNib.Name?, bundle nibBundleOrNil: Bundle?) {
        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
        setupUI()
        setupConstraints()
        self.setupTapGesture()
    }
    
    // 必须实现的Nib/storyboard初始化方法
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupUI()
        setupConstraints()
        self.setupTapGesture()
    }
    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
    }
    
    func startAction(){
        waitingView.play()
        
    }
    func stopAction(){
        waitingView.stop()
    }
    
    // MARK: - UI Setup
    private func setupUI() {
        
        self.view.wantsLayer = true
        self.view.layer?.backgroundColor = .clear
        

        self.view.addSubview(waitingBGView)
        self.view.addSubview(deviceImageShadowView)
        self.view.addSubview(deviceImageView)
        self.view.addSubview(circularProgress)
        self.view.addSubview(deviceNameLabel)
        self.view.addSubview(statusLabel)
        self.view.addSubview(waitingView)
    }
    
    // MARK: - Constraints
    private func setupConstraints() {
        
        deviceImageView.snp.makeConstraints() {
            $0.top.equalToSuperview().offset(6)
            $0.centerX.equalToSuperview()
            $0.width.height.equalTo(64)
        }
        
        deviceImageShadowView.snp.makeConstraints() {
            $0.center.equalTo(deviceImageView)
            $0.width.height.equalTo(66)
        }
        
        circularProgress.snp.makeConstraints() {
            $0.center.equalTo(deviceImageView)
            $0.width.height.equalTo(64+13)
        }
        
        deviceNameLabel.snp.makeConstraints() {
            $0.top.equalTo(deviceImageView.snp.bottom).offset(8)
//            $0.leading.equalToSuperview().offset(8)
//            $0.trailing.equalToSuperview().offset(-8)
            $0.centerX.equalTo(deviceImageView)
            $0.width.equalTo(84)
//            $0.height.equalTo(15)
        }
        
        statusLabel.snp.makeConstraints() {
            $0.top.equalTo(deviceNameLabel.snp.bottom).offset(0)
            $0.width.equalTo(deviceNameLabel.snp.width)
            $0.centerX.equalTo(deviceNameLabel)
//            $0.height.equalTo(13)
        }
        
        waitingView.snp.makeConstraints() {
//            $0.top.equalToSuperview().offset(4)
            $0.center.equalTo(deviceImageView.snp.center)
            $0.width.height.equalTo(36)
        }
        waitingBGView.snp.makeConstraints {
//            $0.top.equalToSuperview().offset(4)
            $0.center.equalTo(deviceImageView)
            $0.width.height.equalTo(64)
        }
        
    }
    
    
    // MARK: - 添加点击手势
    private func setupTapGesture() {
        let tap = NSClickGestureRecognizer(target: self, action: #selector(deviceTapped))
        self.view.addGestureRecognizer(tap)
    }
    
    @objc private func deviceTapped() {
        if hadClick {
            return
        }
        hadClick = true
        guard let userInfo = userInfo else {
            self.hadClick = false
            return
        }
        onDeviceTapped?(userInfo)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5){
            self.hadClick = false
        }
        
    }

    /// 阴影添加
    func configShadow(views: [NSView?], shadowRadius: Float) {
        for view in views {
            view?.layer?.shadowColor = NSColor.mi.hex("#000000", alpha: 0.4).cgColor
            view?.layer?.shadowOffset = CGSize(width: 0, height: 1)
            view?.layer?.shadowOpacity = 1
            view?.layer?.shadowRadius = CGFloat(shadowRadius)
        }
    }

}

// 自定义阴影视图，手动绘制阴影
class ShadowView: NSView {
    
    // 阴影参数（可自定义）
    var shadowColor: NSColor = .red
    var shadowOffset: CGSize = CGSize(width: 0, height: 8)
    var shadowRadius: CGFloat = 15
    var shadowOpacity: CGFloat = 1.0
    var fillColor: NSColor = NSColor.red.withAlphaComponent(0.5)
    var cornerRadius: CGFloat = 32
    var drawSize: CGSize = CGSize(width: 64, height: 64) {
            didSet { setNeedsDisplay(bounds) } // 属性变化触发重绘
        }
    
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        
        // 1. 获取绘图上下文
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        
        // 2. 设置阴影（核心：纯代码绘制阴影）
        context.setShadow(
            offset: shadowOffset,
            blur: shadowRadius,
            color: shadowColor.cgColor.copy(alpha: shadowOpacity)
        )
        
        // 3. 绘制带圆角的矩形（目标视图）
        let rect = NSRect(
            x: (bounds.width - drawSize.width)/2,  // 居中
            y: (bounds.height - drawSize.height)/2, // 居中
            width: drawSize.width,
            height: drawSize.height
        )
        
        // 4. 添加圆角路径
        let path = CGPath(
            roundedRect: rect,
            cornerWidth: cornerRadius,
            cornerHeight: cornerRadius,
            transform: nil
        )
        
        // 5. 设置填充色并绘制
        fillColor.setFill()
        context.addPath(path)
        context.fillPath()
    }
    
    // 强制重绘
    override var needsDisplay: Bool {
        get { return true }
        set {}
    }
//    
//    // 如果需要响应设备像素缩放，可以这样处理
//    override var wantsUpdateLayer: Bool {
//        return true
//    }
//    
//    override func updateLayer() {
//        // 确保在高分辨率屏幕上正确渲染
//        self.layer?.contentsScale = NSScreen.main?.backingScaleFactor ?? 1.0
//    }
}
