//
//  MIWaveView.swift
//  MutualInfectionApp
//
//  Created by apple on 2025/9/29.
//

import UIKit
import Lottie

/**发送水波纹动画**/
class MIScanView: UIView {
    lazy var waveView : LottieAnimationView = {
        let waveView = LottieAnimationView(name: "send")
        waveView.loopMode = .loop // 循环播放
        if UIDevice.current.userInterfaceIdiom == .pad {
            waveView.contentMode = .scaleAspectFill
        }else{
            waveView.contentMode = .scaleAspectFit
        }
        waveView.translatesAutoresizingMaskIntoConstraints = false
        return waveView
    }()
    // 文件图标缩略图
    lazy var thumbnailImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        imageView.clipsToBounds = true
        imageView.layer.cornerRadius = 20
        imageView.image = UIImage.scanCenterIcon
        return imageView
    }()
    
    
    lazy var findLb : UILabel = {
        let findLb =  UILabel()
            .withText("正在搜索设备…".localized)
            .withFont(SFCompact(weight: .regular,size: 13))
            .withColorText("#000000")
            .withTextAlignment(.center)
            .withNumberOfLines(1)
        findLb.textColor = findLb.textColor.withAlpha(0.6)
        return findLb
    }()
        
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        self.addSubview(waveView)
        waveView.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.leading.trailing.equalToSuperview()
            make.centerY.equalToSuperview().offset(-MINavigationView.contentHeight())
        }
        
//        self.addSubview(thumbnailImageView)
        // 缩略图约束
//        thumbnailImageView.snp.makeConstraints { make in
//            make.center.equalTo(waveView)
//            if UIDevice.current.userInterfaceIdiom == .pad {
//                make.width.height.equalTo(60)
//            }else{
//                make.width.height.equalTo(40)
//            }
//        }
       
        self.addSubview(findLb)
        findLb.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.centerY.equalToSuperview().offset(-MINavigationView.contentHeight())
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

extension MIHuaweiShareViewController{
    
    func setScanView(){
        
        scanView =  MIScanView(frame: .zero)
        contentView.addSubview(scanView ?? UIView())
        scanView?.isHidden = false
        
        scanView?.backgroundColor = .clear
        scanView?.snp.makeConstraints { make in
            make.top.bottom.equalToSuperview()
            make.leading.trailing.equalToSuperview()
        }
    }
    
    /**显示扫描动画**/
    func showScanView(isShow:Bool = false){
        if isShow {
            self.nearbyUsersView.isHidden = true
            self.scanView?.isHidden = false
            self.scanView?.startAction()
        }else{
            self.nearbyUsersView.isHidden = false
            self.nearbyUsersView.updateUserInfos(self.deviceInfos)
            self.scanView?.isHidden = true
            self.scanView?.stopAction()
        }
    }
}
