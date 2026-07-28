//
//  MIFeedBackTableViewSectionHeaderView.swift
//  MutualInfectionApp
//
//  Created by Niko on 2025/9/6.
//

import UIKit
import SnapKit

class MIFeedBackTableViewSectionHeaderView: UITableViewHeaderFooterView {

    var titleLabel = UILabel()
        .withTextColor(.black.withAlpha(0.9))
        .withNumberOfLines(0)
        .withFont(pingFangSC(weight: .medium,size: 16))
    
    var arrowButton = UIButton()
    var showClick : ClickBlockVoid?

    var subContentView = UIView()
    
    var maskedCorners: CACornerMask = [] {
        didSet {
            self.subContentView.layer.maskedCorners = maskedCorners
        }
    }
    
    override init(reuseIdentifier: String?) {
        super.init(reuseIdentifier: reuseIdentifier)
    
        initViews()
    }
    
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    
    func initViews() {
        self.addSubview(subContentView)
        self.subContentView.backgroundColor = .white
        self.subContentView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        self.subContentView.addSubview(titleLabel)
        titleLabel.snp.makeConstraints { make in
            make.leading.equalTo(16)
            //make.top.equalTo(15)
            make.centerY.equalToSuperview()
        }
        
        let upImage = UIImage(systemName: "chevron.up")?.withTintColor("9c9c9c".color, renderingMode: .alwaysOriginal)
        let downImage = UIImage(systemName: "chevron.down")?.withTintColor("9c9c9c".color, renderingMode: .alwaysOriginal)
        arrowButton.setImage(upImage, for: .normal)
        arrowButton.setImage(downImage, for: .selected)
        self.subContentView.addSubview(arrowButton)
        arrowButton.addClickClosure { sender in
            self.showClick?()
        }
        arrowButton.snp.makeConstraints { make in
            make.trailing.equalToSuperview().offset(-10)
            make.centerY.equalTo(titleLabel)
            make.size.equalTo(CGSize(width: 44, height: 44))
        }

        
        self.subContentView.layer.cornerRadius = 20
        self.subContentView.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
    }
}

class MIFeedBackTableViewSectionFooterView: UITableViewHeaderFooterView {

    var subContentView = UIView()
    
    override init(reuseIdentifier: String?) {
        super.init(reuseIdentifier: reuseIdentifier)
    
        initViews()
    }
    
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    
    func initViews() {
        self.addSubview(subContentView)
        self.subContentView.backgroundColor = .white
        self.subContentView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        self.subContentView.layer.cornerRadius = 20
        self.subContentView.layer.maskedCorners = [.layerMinXMaxYCorner, .layerMaxXMaxYCorner]
    }
}
