//
//  MIMACScanView.swift
//  MutualInfectionMac
//
//  Created by apple on 2025/10/8.
//

import Cocoa
import Lottie


/**发送水波纹动画**/
class MIMACScanView: NSView {
    lazy var waveView : LottieAnimationView = {
        let waveView = LottieAnimationView(name: "send")
        waveView.loopMode = .loop // 循环播放
        waveView.contentMode = .scaleAspectFill
        waveView.translatesAutoresizingMaskIntoConstraints = false
        
        waveView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        waveView.setContentCompressionResistancePriority(.defaultLow, for: .vertical)
        waveView.setContentHuggingPriority(.defaultLow, for: .horizontal)
        waveView.setContentHuggingPriority(.defaultLow, for: .vertical)
        return waveView
    }()
    // 文件图标缩略图
    lazy var thumbnailImageView: NSImageView = {
        let imageView = NSImageView()
//        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
//        imageView.layer.cornerRadius = 20
        imageView.image = NSImage.log
        return imageView
    }()
    
    
    lazy var findLb : NSTextField = {
        let findLb =  NSTextField(labelWithString: "正在搜索设备…".localized)
        findLb.font = .mi.pingFangSCRegular(size: 13)
        findLb.textColor = .mi.hex("#000000",alpha: 0.6)
        findLb.translatesAutoresizingMaskIntoConstraints = false
        findLb.alignment = .center
        return findLb
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        self.addSubview(waveView)
        waveView.snp.makeConstraints { make in
//            make.height.equalTo(screenHeight)
//            make.leading.trailing.top.bottom.equalToSuperview()
            make.edges.equalToSuperview()
            
//                make.center.equalToSuperview()
//            make.width.equalToSuperview()//动画有问题，设置高度，会窗口异常
        }
        //客户不要了
//        self.addSubview(thumbnailImageView)
//        // 缩略图约束
//        thumbnailImageView.snp.makeConstraints { make in
//            make.center.equalTo(waveView)
//            make.width.height.equalTo(100)
//        }
        self.addSubview(findLb)
        findLb.snp.makeConstraints { make in
            make.center.equalTo(waveView)
//            make.centerY.equalTo(thumbnailImageView.snp.bottom).offset(30)
        }
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
    
    func startAction(){
        waveView.play()
        
    }
    func stopAction(){
        waveView.stop()
    }
}

extension MainWindowController{
    
    func setScanView(){
        scanView =  MIMACScanView(frame: .zero)
        scanView?.wantsLayer = true
        scanView?.layer?.backgroundColor = NSColor.clear.cgColor
        view.addSubview(scanView ?? NSView())
        
//        scanView?.isHidden = false
        scanView?.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        self.scanView?.startAction()
    }
    
    /**显示扫描动画**/
    func showScanView(isShow:Bool = false){
        if isShow {
            self.nearbyUsersView.isHidden = true
            self.nearbyUsersView.titleLable.isHidden = true
            self.scanView?.isHidden = false
            self.scanView?.startAction()
        }else{
            self.nearbyUsersView.isHidden = false
            self.nearbyUsersView.titleLable.isHidden = false
            self.nearbyUsersView.updateUserInfos(self.deviceInfos)
            self.scanView?.isHidden = true
            self.scanView?.stopAction()
        }
    }
}
