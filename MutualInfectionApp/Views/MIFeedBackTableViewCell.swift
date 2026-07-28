//
//  MIFeedBackTableViewCell.swift
//  MutualInfectionApp
//
//  Created by Niko on 2025/9/6.
//

import UIKit
import SnapKit

class MIFeedBackTableViewCell: UITableViewCell {
    
    var cellData: [Any?] = []
    var subTitles: [String] = []

    var contextLabel = UILabel()
        .withFont(pingFangSC(weight: .medium, size: 14))
        .withTextColor(.black.withAlpha(0.9))
        .withNumberOfLines(0)
        //.withDebugText("")
    
    var subContentView = UIView()
    
    var lineView = UIView()
    
    var ishsow : Bool = true
    var isLast: Bool = true {
        didSet {
            contextLabel.snp.updateConstraints { make in
                make.bottom.equalTo(isLast ? -20 : -10)
            }
            
            self.subContentView.layer.cornerRadius = isLast ? 20 : 0
        }
    }
    
    func updateCell(_ cellData: [Any?]) {
        
        lineView.isHidden = !ishsow
        if !ishsow {
            
            contextLabel.text = ""
           
            return
        }
        
        self.cellData = cellData
        guard let subArray = cellData[1] else { return }
        if let strArray = subArray as? [String]{
            let textStr = self.boldSubstrings(in: strArray.joined(separator: "\n"), substrings: [])
            contextLabel.attributedText = textStr
        } else {
            var subString: [String] = []
            if let anyArray = subArray as? [Any] {
                anyArray.forEach { item in
                    if let subStrArray = item as? [Any] {
                        subString.append(self.getSubItems(subStrArray))
                    }
                }
            }
            let textString = subString.joined(separator: "\n");
            if textString.contains("@image") {
                let textArray = textString.components(separatedBy: "@image")
                let textStr = self.getImageText(textArray)
                contextLabel.attributedText = textStr
            } else {
                let textStr = self.boldSubstrings(in: subString.joined(separator: "\n"), substrings: subTitles)
                contextLabel.attributedText = textStr
            }
        }
    }
    
    private func getImageText(_ textArray: [String]) -> NSAttributedString {
        let mutableString = NSMutableAttributedString(string: textArray[0])
        let imageAttachment1 = NSTextAttachment()
        
        // 计算保持宽高比的尺寸（宽度适应屏幕，左右各16pt边距）
        let screenWidth = UIScreen.main.bounds.width
        var targetWidth = screenWidth - 32 - 32 // 左右边距各16
        
        if UIDevice.current.userInterfaceIdiom == .pad {
             targetWidth = 600
        }else {
            targetWidth = screenWidth - 32 - 32
        }
        
        let image1 = UIImage.illustrationOne
        imageAttachment1.image = image1
        let aspectRatio1 = image1.size.height / image1.size.width
        let targetHeight1 = targetWidth * aspectRatio1
        
        imageAttachment1.bounds =  CGRect(
            x: 16, // 左边距
            y: 0,
            width: targetWidth,
            height: targetHeight1
        )
        
        let imageString = NSAttributedString(attachment: imageAttachment1)
        mutableString.append(imageString)
        mutableString.append(NSAttributedString(string: textArray[1]))
        let imageAttachment2 = NSTextAttachment()
        let image2 = UIImage.illustrationTwo
        imageAttachment2.image = image2
        let aspectRatio2 = image2.size.height / image2.size.width
        let targetHeight2 = targetWidth * aspectRatio2
        imageAttachment2.bounds =  CGRect(
            x: 16, // 左边距
            y: 0,
            width: targetWidth,
            height: targetHeight2
        )
        
        let imageString2 = NSAttributedString(attachment: imageAttachment2)
        mutableString.append(imageString2)
        let paragraphStyle = NSMutableParagraphStyle()
        let baseFont = SFCompact(weight: .regular,size: 14)
        //UIFont.systemFont(ofSize: 14)
        let boldFont = SFCompact(weight: .bold,size: 14)
        //UIFont.boldSystemFont(ofSize: 14)
        paragraphStyle.lineSpacing = 6 // 设置行间距
        let totalCount = textArray[0].count + textArray[1].count
        mutableString.addAttribute(.font, value: baseFont, range: NSRange(location: 0, length: totalCount))
        mutableString.addAttribute(
            .paragraphStyle,
            value: paragraphStyle,
            range: NSRange(location: 0, length: mutableString.length)
        )
        
        for substring in subTitles {
            var searchRange = NSRange(location: 0, length: totalCount)
            while searchRange.location < totalCount {
                let range = (textArray[0] + textArray[1] as NSString).range(of: substring, options: [], range: searchRange)
                if range.location == NSNotFound {
                    break
                }
                mutableString.addAttribute(.font, value: boldFont, range: range)
                searchRange.location = range.location + range.length
                searchRange.length = totalCount - searchRange.location
            }
        }
        
        for substring in ["首次使用需设为“所有人可见”。".localized] {
            var searchRange = NSRange(location: 0, length: totalCount)
            while searchRange.location < totalCount {
                let range = (textArray[0] + textArray[1] as NSString).range(of: substring, options: [], range: searchRange)
                if range.location == NSNotFound {
                    break
                }
                mutableString.addAttributes([
                    .foregroundColor: UIColor.red,
                    .font:SFCompact(weight: .regular, size: 14),
                ], range: range)
                searchRange.location = range.location + range.length
                searchRange.length = totalCount - searchRange.location
            }
        }
        
        return mutableString
    }
    
    private func boldSubstrings(in string: String, substrings: [String]) -> NSAttributedString {
        let attributedString = NSMutableAttributedString(string: string)
        let paragraphStyle = NSMutableParagraphStyle()
        let baseFont = SFCompact(weight: .regular,size: 14)
        //UIFont.systemFont(ofSize: 14)
        let boldFont = SFCompact(weight: .bold,size: 14)
        //UIFont.boldSystemFont(ofSize: 14)
        paragraphStyle.lineSpacing = 6 // 设置行间距
        attributedString.addAttribute(.font, value: baseFont, range: NSRange(location: 0, length: string.count))
        attributedString.addAttribute(
            .paragraphStyle,
            value: paragraphStyle,
            range: NSRange(location: 0, length: attributedString.length)
        )
        for substring in substrings {
            var searchRange = NSRange(location: 0, length: string.count)
            while searchRange.location < string.count {
                let range = (string as NSString).range(of: substring, options: [], range: searchRange)
                if range.location == NSNotFound {
                    break
                }
                attributedString.addAttribute(.font, value: boldFont, range: range)
                searchRange.location = range.location + range.length
                searchRange.length = string.count - searchRange.location
            }
        }
        
        return attributedString
    }

    
    private func getSubItems(_ subItems: [Any]) -> String {
        var subString: [String] = []
        if let title = subItems[0] as? String {
            //标题
            subString.append(title)
            self.subTitles.append(title)
        }
        //内容
        if let subContentArr = subItems[1] as? [String] {
            subContentArr.forEach { item in
                subString.append(item)
            }
        }
        return subString.joined(separator: "\n")
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
        
        self.subContentView.addSubview(contextLabel)
        contextLabel.snp.makeConstraints { make in
            make.leading.equalTo(16)
            make.trailing.equalTo(-16)
            make.top.equalTo(6)
            make.bottom.equalTo(-20)
        }
        
        self.lineView.backgroundColor = .black.withAlpha(0.2)
        self.subContentView.addSubview(self.lineView)
        self.lineView.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(16)
            make.trailing.equalToSuperview().offset(-16)
            make.top.equalToSuperview()
            make.height.equalTo(0.5)
        }
    }
    
    
    
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    
    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }

}
