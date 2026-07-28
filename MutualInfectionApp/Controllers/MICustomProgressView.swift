//
//  MICustomProgressView.swift
//  MutualInfectionApp
//
//  Created by delegate on 2025/10/22.
//
/*
 使用实例：
 
 private lazy var customProgressView: MICustomProgressView = {
     let progressView = MICustomProgressView()
     
     return progressView
 }()
 
 view.addSubview(customProgressView)
 customProgressView.snp.makeConstraints { make in
     make.bottom.equalTo(0)
     make.leading.equalToSuperview()
     make.trailing.equalToSuperview()
 }
 
 customProgressView.set(bgImageView: [
     UIColor.blue.cgColor,    // 起始色
     UIColor.green.cgColor])
 
 */
import UIKit

class MICustomProgressView: UIView {
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        
        setupUI()
        
    }
    private func setupUI() {
        addSubview(bgImageView)
        [titleLabel, percentLabel, progressView].forEach { subView in
            bgImageView.addSubview(subView)
        }
        bgImageView.snp.makeConstraints { make in
            make.leading.equalTo(20)
            make.top.equalTo(10)
            make.bottom.equalTo(-10)
            make.trailing.equalTo(-20)
        }
        percentLabel.snp.makeConstraints { make in
            make.trailing.equalTo(-10)
            make.top.equalTo(10)
            make.height.equalTo(21)
        }
        titleLabel.snp.makeConstraints { make in
            make.top.equalTo(10)
            make.leading.equalTo(10)
            make.height.equalTo(21)
            make.trailing.lessThanOrEqualTo(-10)
        }
        progressView.snp.makeConstraints { make in
            make.top.equalTo(titleLabel.snp.bottom).offset(10)
            make.leading.equalTo(10)
            make.trailing.equalTo(-10)
            make.height.equalTo(5)
            make.bottom.equalTo(-10)
        }
    }
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    public func set(bgImageView img: String) {
        bgImageView.image = UIImage(named: img)
    }
    public func set(fileType: String) {
        DispatchQueue.main.async {
            self.titleLabel.text = "正在导入“\(fileType)”，请勿退出应用".localized
        }
    }
    public func setProgress(_ progressValue: Float) {
        DispatchQueue.main.async {
            self.progressView.progress = progressValue
            self.percentLabel.text = String(format: "%.f%%", progressValue * 100)
            let currentProgress = CGFloat(progressValue)
            if #available(iOS 16.2, *) {
                ShareAPI.shared().log(1, "[UI] [MIReceiveFilesView] updateActivity 正在导入 performAsyncTask  currentProgress -\(currentProgress)")
                LiveActivityManager.shared.updateActivity(delay: 1, alert: false, progressValue: currentProgress,status: StatusLive.importFile,stateInfo:"正在导入".localized,statusInfo: "")
            }
        }
    }
    public func set(bgImageView layerColors: [CGColor], startPoint: CGPoint = CGPoint(x: 0, y: 0), endPoint: CGPoint = CGPoint(x: 1, y: 1) ) {
        DispatchQueue.main.asyncAfter(deadline: .now()+0.05) {
            let gradientLayer = CAGradientLayer()
            gradientLayer.colors = layerColors
            gradientLayer.startPoint = startPoint
            gradientLayer.endPoint =  endPoint
            gradientLayer.frame = self.bgImageView.bounds
            self.bgImageView.layer.insertSublayer(gradientLayer, at: 0)
        }
    }
    //=================================================================
    //                            lazy
    //=================================================================
    // MARK: - lazy
    private lazy var bgImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.backgroundColor = .clear
        imageView.layer.cornerRadius = 10
        imageView.layer.masksToBounds = true
        return imageView
    }()
    private lazy var titleLabel: UILabel = {
        let label = UILabel()
        label.text = "正在导入xxx，请勿退出应用"
        label.textColor = "#336FFF".color
        label.font = SFCompact(weight: .regular, size: 16)
        return label
    }()
    private lazy var percentLabel: UILabel = {
        let label = UILabel()
        label.text = "0%"
        label.textColor = "#336FFF".color
        label.font = SFCompact(weight: .regular, size: 16)
        label.textAlignment = .right
        return label
    }()
    private lazy var progressView: UIProgressView = {
        let progress = UIProgressView()
        progress.progress = 0
        // 进度条走过的颜色
        progress.progressTintColor =  UIColor(red: 134 / 255.0, green: 182 / 255.0, blue: 255 / 255.0, alpha: 1.0)
        // 进度条为走的颜色
        progress.trackTintColor = UIColor.white
        return progress
    }()
}
