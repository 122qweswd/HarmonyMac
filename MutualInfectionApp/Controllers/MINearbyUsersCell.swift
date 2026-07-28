//
//  MINearbyUsersCell.swift
//  MutualInfectionApp
//
//  Created by apple on 2025/9/1.
//

import UIKit
import SnapKit
import Lottie

class MINearbyUsersCell: UICollectionViewCell {
    
    // 添加点击回调
    var onDeviceTapped: ((MIDevice) -> Void)?
    
    
    var userInfo: MIDevice?{
        didSet{
            print("=========1\(userInfo?.deviceStatus)")
           
//            deviceNameLabel.text = userInfo?.name
            let limitText = userInfo?.name.truncateToBytes(24)
            deviceNameLabel.text = limitText
            print(deviceNameLabel.text ?? "")
            self.updateProgress(progress: userInfo?.progress ?? 0)
        }
    }
    
    func updateProgress(progress:CGFloat = 0) {
        
        self.progressLayer.isHidden = self.currentDeviceStatus == .completed
        
        if progress < 1 {
            self.currentDeviceStatus = userInfo?.deviceStatus ?? .normal
        }
        
        print("============updateProgress\(self.userInfo?.progress)====\(self.currentDeviceStatus)")
        
        
//        if progress == 0 {
//            self.progressLayer.isHidden = true
//            UIView.animate(withDuration: 0 , delay: 0, options: [.curveLinear]) {
//                self.progressLayer.strokeEnd = progress
//            }completion: { success in
////                DispatchQueue.main.asyncAfter(deadline: .now()+2.0){
////                    self.progressLayer.isHidden = false
////                }
//            }
//            return
//        }
        
        
       // 更新进度条
        UIView.animate(withDuration: 1.0, delay: 1, options: [.curveLinear]) {
            self.progressLayer.strokeEnd = progress
        }completion: { success in
            // 当进度达到100%时，停止动画
            if progress >= 1 {
                // 进度条完成后，自动将状态改为已完成
                self.userInfo?.deviceStatus = .completed
                self.currentDeviceStatus = .completed
                self.updateCirclePath()
                
                UIView.animate(withDuration: 1.0, delay: 0, options: [.curveLinear]) {
                    self.progressLayer.isHidden = true
                }completion: { success in
                    DispatchQueue.main.asyncAfter(deadline: .now()+2.0){
                       
                        UIView.animate(withDuration: 0 , delay: 0, options: [.curveLinear]) {
                            self.progressLayer.strokeEnd = 0
                            self.userInfo?.progress = 0
                            self.deviceImageView.image = MIDeviceHeaderWCDBManager.sharedManager().getDeviceHeader(self.userInfo?.hwId ?? "",self.userInfo?.isShowIcon ?? false,deviceTye: self.userInfo?.deviceType ?? 1)
                        }completion: { success in
                            DispatchQueue.main.asyncAfter(deadline: .now()+1.0){
                                self.progressLayer.isHidden = false
                            }
                        }
                        
                    }
                }
                
                
                
                
            }
        }
   }
    
    
    
    var currentDeviceStatus: DeviceStatus = .normal{
        didSet{
            
            DispatchQueue.main.async {
                
                
                print("============currentDeviceStatus\(self.userInfo?.progress)====\(self.currentDeviceStatus)")
                self.waitingView.isHidden = true
                self.deviceImageView.isHidden = false
                self.stopAction()
                if  self.currentDeviceStatus == .completed && self.userInfo?.progress == 0{
                    self.statusLabel.text = "已发送".localized
                    self.statusLabel.textColor =  "#0A59F7".color
                    self.deviceImageView.image = MIDeviceHeaderWCDBManager.sharedManager().getDeviceHeader(self.userInfo?.hwId ?? "",self.userInfo?.isShowIcon ?? false,deviceTye: self.userInfo?.deviceType ?? 1)
                    return
                }
                switch self.currentDeviceStatus {
                
                case .normal:      // 在线，未选择 - 正常设备状态
                    self.statusLabel.text = ""
                    self.statusLabel.textColor =  "#0A59F7".color
                    self.deviceImageView.image = MIDeviceHeaderWCDBManager.sharedManager().getDeviceHeader(self.userInfo?.hwId ?? "",self.userInfo?.isShowIcon ?? false, deviceTye: self.userInfo?.deviceType ?? 1)
                    //正在连接对方热点...
                case .connecting,.connected:  // 连接中状态 - 正在建立连接
                    self.deviceImageView.isHidden = true
                    self.waitingView.isHidden = false
                    self.startAction()
                    self.statusLabel.text = "连接中".localized
                    self.statusLabel.textColor =  "#0A59F7".color
                    self.deviceImageView.image = MIDeviceHeaderWCDBManager.sharedManager().getDeviceHeader(self.userInfo?.hwId ?? "",self.userInfo?.isShowIcon ?? false, deviceTye: self.userInfo?.deviceType ?? 1)
                case .waiting:     // 等待中状态 - 等待用户确认或网络连接
                    self.statusLabel.text = "等待中".localized
                    self.statusLabel.textColor =  "#0A59F7".color
                    self.deviceImageView.image = MIDeviceHeaderWCDBManager.sharedManager().getDeviceHeader(self.userInfo?.hwId ?? "",self.userInfo?.isShowIcon ?? false, deviceTye: self.userInfo?.deviceType ?? 1)
                case .sending:     // 发送中状态 - 保持动画不变
                    self.statusLabel.text = "发送中".localized
                    self.statusLabel.textColor =  "#0A59F7".color
                    self.deviceImageView.image = MIDeviceHeaderWCDBManager.sharedManager().getDeviceHeader(self.userInfo?.hwId ?? "",self.userInfo?.isShowIcon ?? false, deviceTye: self.userInfo?.deviceType ?? 1)
                case .completed:   // 发送完成 - 保持白色对钩不变
                    self.statusLabel.text = "已发送".localized
                    self.statusLabel.textColor =  "#0A59F7".color
                    self.deviceImageView.image = UIImage.iconFinish
                case .cancelled:   // 取消发送 - 用户取消或发送失败
                    self.deviceImageView.image = MIDeviceHeaderWCDBManager.sharedManager().getDeviceHeader(self.userInfo?.hwId ?? "",self.userInfo?.isShowIcon ?? false, deviceTye: self.userInfo?.deviceType ?? 1)
                    // 更新第二行文字
                    self.statusLabel.text = "发送取消".localized
                    self.statusLabel.textColor = "#E02020".color
                case .needreceive:  //待接收
                    self.deviceImageView.isHidden = true
                    self.waitingView.isHidden = false
                    self.startAction()
                    self.deviceImageView.image = MIDeviceHeaderWCDBManager.sharedManager().getDeviceHeader(self.userInfo?.hwId ?? "",self.userInfo?.isShowIcon ?? false, deviceTye: self.userInfo?.deviceType ?? 1)
                    self.statusLabel.text = "待接收".localized
                    self.statusLabel.textColor =  "#0A59F7".color
                case .disconnected: //连接断开
                    self.deviceImageView.image = MIDeviceHeaderWCDBManager.sharedManager().getDeviceHeader(self.userInfo?.hwId ?? "",self.userInfo?.isShowIcon ?? false, deviceTye: self.userInfo?.deviceType ?? 1)
                    self.statusLabel.text = "连接断开".localized
                    self.statusLabel.textColor = "#E02020".color
                case .didReject: //对方拒绝
                    self.deviceImageView.image = MIDeviceHeaderWCDBManager.sharedManager().getDeviceHeader(self.userInfo?.hwId ?? "",self.userInfo?.isShowIcon ?? false, deviceTye: self.userInfo?.deviceType ?? 1)
                    self.statusLabel.text = "已拒绝".localized
                    self.statusLabel.textColor = "#E02020".color
                case .peerBusy: //对方忙
                    self.deviceImageView.image = MIDeviceHeaderWCDBManager.sharedManager().getDeviceHeader(self.userInfo?.hwId ?? "",self.userInfo?.isShowIcon ?? false, deviceTye: self.userInfo?.deviceType ?? 1)
                    self.statusLabel.text = "对方忙".localized
                    self.statusLabel.textColor = "#E02020".color
                case .selfBusy: //已方忙
                    self.deviceImageView.image = MIDeviceHeaderWCDBManager.sharedManager().getDeviceHeader(self.userInfo?.hwId ?? "",self.userInfo?.isShowIcon ?? false, deviceTye: self.userInfo?.deviceType ?? 1)
                    self.statusLabel.text = "已方忙".localized
                    self.statusLabel.textColor = "#E02020".color
                case .error:
                    self.deviceImageView.image = MIDeviceHeaderWCDBManager.sharedManager().getDeviceHeader(self.userInfo?.hwId ?? "",self.userInfo?.isShowIcon ?? false, deviceTye: self.userInfo?.deviceType ?? 1)
                    self.statusLabel.text = "分享失败".localized
                    self.statusLabel.textColor = "#E02020".color
                case .timeout:
                    self.deviceImageView.image = MIDeviceHeaderWCDBManager.sharedManager().getDeviceHeader(self.userInfo?.hwId ?? "",self.userInfo?.isShowIcon ?? false, deviceTye: self.userInfo?.deviceType ?? 1)
                    self.statusLabel.text = "请求超时".localized
                    self.statusLabel.textColor = "#E02020".color
                case .nospace:
                    self.deviceImageView.image = MIDeviceHeaderWCDBManager.sharedManager().getDeviceHeader(self.userInfo?.hwId ?? "",self.userInfo?.isShowIcon ?? false, deviceTye: self.userInfo?.deviceType ?? 1)
                    self.statusLabel.text = "内存不足".localized
                    self.statusLabel.textColor = "#E02020".color
                }
            }
            
        }
    }
    
    // 添加进度条相关属性
    private let progressLayer = CAShapeLayer()
    private lazy var deviceImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        imageView.layer.cornerRadius = 32
        imageView.clipsToBounds = true
        return imageView
    }()
    
    private lazy var deviceImageShadowView: UIView = {
        let view = UIView()
        view.layer.cornerRadius = 33
        view.layer.borderColor = UIColor.white.withAlpha(0.1).cgColor
        view.layer.borderWidth = 1
        configShadow(views: [view], shadowRadius: 2)
        return view
    }()
    
    private lazy var deviceNameLabel: UILabel = {
        let label = UILabel()
        label.textAlignment = .center
        label.font = SFCompact(weight: .medium,size: 12)
        label.textColor = "#000000".color
        // 设置最多显示两行
        label.numberOfLines = 2
        label.lineBreakMode = .byTruncatingTail
        return label
    }()
    
    private lazy var statusLabel: UILabel = {
        let label = UILabel()
        label.textAlignment = .center
        label.font = SFCompact(weight: .regular,size: 11)
        label.textColor = "#0A59F7".color
        label.isHidden = false
        label.numberOfLines = 1
        return label
    }()
    
    lazy var waitingView : LottieAnimationView = {
        let waitingView = LottieAnimationView(name: "waiting")
        waitingView.loopMode = .loop
        waitingView.contentMode = .scaleAspectFit
        waitingView.backgroundColor = "#ffffff".color.withAlpha(1)
        waitingView.layer.cornerRadius = 32
        waitingView.clipsToBounds = true
        waitingView.translatesAutoresizingMaskIntoConstraints = false
        return waitingView
    }()
    
    // MARK: - Initialization
    override init(frame: CGRect) {
        super.init(frame: frame)
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
    
    // MARK: - UI Setup
    private func setupUI() {
        self.addSubview(deviceImageShadowView)
        self.addSubview(deviceImageView)
        //self.addSubview(userNameLabel)
        self.addSubview(deviceNameLabel)
        self.addSubview(statusLabel)
        self.addSubview(waitingView)
        // 设置进度条图层
        setupProgressLayer()
    
    }
    
    // MARK: - Constraints
    private func setupConstraints() {
        
        deviceImageView.snp.makeConstraints() {
            $0.top.equalToSuperview().offset(4)
            $0.centerX.equalToSuperview()
            $0.width.height.equalTo(64)
        }
        
        deviceImageShadowView.snp.makeConstraints() {
            $0.center.equalTo(deviceImageView)
            $0.width.height.equalTo(66)
        }
        
        deviceNameLabel.snp.makeConstraints() {
            $0.top.equalTo(deviceImageView.snp.bottom).offset(phoneToPad(8))
            $0.width.equalToSuperview()
//            $0.height.equalTo(phoneToPad(15))
        }
        
        statusLabel.snp.makeConstraints() {
            $0.top.equalTo(deviceNameLabel.snp.bottom).offset(phoneToPad(2))
            $0.width.equalToSuperview()
            $0.height.equalTo(phoneToPad(13))
        }
        
        waitingView.snp.makeConstraints() {
            $0.top.equalToSuperview().offset(4)
            $0.centerX.equalToSuperview()
            $0.width.height.equalTo(64)
        }
        
       
     
        
    }
    override func layoutIfNeeded() {
        super.layoutIfNeeded()
    
    }
    
    func startAction(){
        waitingView.play()
        
    }
    func stopAction(){
        waitingView.stop()
    }
    
    // MARK: - 进度条相关方法
    private func setupProgressLayer() {
        progressLayer.fillColor = UIColor.clear.cgColor
        progressLayer.strokeColor = UIColor(red: 134/255.0, green: 182/255.0, blue: 255/255.0, alpha: 1.0).cgColor
        progressLayer.lineWidth = 4
        progressLayer.strokeEnd = 0
        progressLayer.lineCap = .round
        
        // 将进度条添加到contentView的layer上，确保显示在设备图片的后面
        contentView.layer.addSublayer(progressLayer)
        contentView.layer.insertSublayer(progressLayer, below: deviceImageView.layer)
    }
    // MARK: - 布局
    override func layoutSubviews() {
        super.layoutSubviews()
        updateCirclePath() // 更新圆环路径
    }
    
    /// 更新圆环路径
    private func updateCirclePath() {
        // 计算圆环中心和半径
        let center = deviceImageView.center
        let radius = min(deviceImageView.bounds.width, deviceImageView.bounds.height) / 2 + 2
        
        // 创建圆环路径（从12点方向开始，顺时针绘制）
        let startAngle = -CGFloat.pi / 2
        let endAngle = startAngle + 2 * CGFloat.pi
        
        let path = UIBezierPath(arcCenter: center,
                                radius: radius,
                                startAngle: startAngle,
                                endAngle: endAngle,
                                clockwise: true)
        
        progressLayer.path = path.cgPath
    }
    
    
    // MARK: - 添加点击手势
    private func setupTapGesture() {
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(deviceTapped))
        self.addGestureRecognizer(tapGesture)
        self.isUserInteractionEnabled = true
    }
    @objc private func deviceTapped() {
        guard let userInfo = userInfo else { return }
        onDeviceTapped?(userInfo)

    }

}


