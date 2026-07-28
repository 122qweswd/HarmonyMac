//
//  MIPermissionsCell.swift
//  MutualInfectionApp
//
//  Created by  mind on 2025/9/9.
//

import UIKit


enum CornerType {
    case top
    case center
    case bottom
}


class MIPermissionsCell: UITableViewCell {
    
    var titleLabel = UILabel()
        .withFont(pingFangSC(weight: .medium, size: 16))
        .withTextColor(.black.withAlpha(0.9))
        .withNumberOfLines(0)
    
    var descLabel = UILabel()
        .withFont(pingFangSC(weight: .medium, size: 12))
        .withTextColor(.black.withAlpha(0.6))
        .withNumberOfLines(1)
    
    var rightArrowButton = UIButton()
    
    var subContentView = UIView()
    
    var lineView = UIView()
    
    var cornerType: CornerType = .center {
        didSet {
//            contextLabel.snp.updateConstraints { make in
//                make.bottom.equalTo(isLast ? -20 : -10)
//            }
//
            
            switch cornerType {
            case .top:
                self.subContentView.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
                self.subContentView.layer.cornerRadius = 20
            case .center:
              
                self.subContentView.layer.cornerRadius = 0
            case .bottom:
                self.subContentView.layer.maskedCorners = [.layerMinXMaxYCorner, .layerMaxXMaxYCorner]
                self.subContentView.layer.cornerRadius = 20
            }
           
        }
    }
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)

        
        self.backgroundColor = .clear
        
        self.subContentView.backgroundColor = .white
        self.subContentView.clipsToBounds = true
        self.subContentView.layer.maskedCorners = [.layerMinXMaxYCorner, .layerMaxXMaxYCorner]
        self.contentView.addSubview(self.subContentView)
        subContentView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        self.subContentView.addSubview(titleLabel)
        titleLabel.snp.makeConstraints { make in
            make.leading.equalTo(16)
            make.trailing.equalTo(-16)
            make.top.equalTo(9)
            make.bottom.equalTo(-31)
        }
        
        self.subContentView.addSubview(descLabel)
        descLabel.snp.makeConstraints { make in
            make.leading.equalTo(16)
            make.trailing.equalTo(-32)
            make.top.equalTo(titleLabel.snp.bottom).offset(2)
        }
        
        let rightImage = UIImage(systemName: "chevron.right")?.withTintColor("9c9c9c".color, renderingMode: .alwaysOriginal)
        rightArrowButton.setImage(rightImage, for: .normal)
        rightArrowButton.isUserInteractionEnabled = false
        self.subContentView.addSubview(rightArrowButton)
        rightArrowButton.snp.makeConstraints { make in
            make.trailing.equalTo(-16)
            make.centerY.equalToSuperview()
            make.width.equalTo(16)
            make.height.equalTo(60)
        }
        
        self.lineView.backgroundColor = .black.withAlpha(0.2)
        self.subContentView.addSubview(self.lineView)
        self.lineView.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(16)
            make.trailing.equalToSuperview().offset(-16)
            make.top.equalToSuperview()
            make.height.equalTo(phoneToPad(0.5))
        }
    }
    
    
    
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    
    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
//        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }

}

