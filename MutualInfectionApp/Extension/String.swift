//
//  String.swift
//  MutualInfectionApp
//
//  Created by Niko on 2025/8/31.
//

import Foundation
import UIKit

let maxCharacterCount = 12
let maxChineseCount = 12
let maxEnglishCount = 12

extension String {
    var color: UIColor {
        if isEmpty {
            return .clear
        }
        return UIColor(hexString: self)
    }
    
    /// 获取文本宽度
    func widthWithConstrainedHeight(height: CGFloat, font: UIFont) -> CGFloat {
        let constraintRect = CGSize(width: CGFloat.greatestFiniteMagnitude, height: height)
        let boundingBox = self.boundingRect(with: constraintRect, options: .usesLineFragmentOrigin, attributes: [NSAttributedString.Key.font: font], context: nil)
        return ceil(boundingBox.width)
    }
    
    /// 获取文本高度
    func heightWithConstrainedWidth(width: CGFloat, font: UIFont) -> CGFloat {
        let constraintRect = CGSize(width: width, height: CGFloat.greatestFiniteMagnitude)
        let boundingBox = self.boundingRect(with: constraintRect, options: .usesLineFragmentOrigin, attributes: [NSAttributedString.Key.font: font], context: nil)
        return ceil(boundingBox.height)
    }
    
    static func validateInputText(_ text: String) -> String {
        var charCount = 0
        var lastValidIndex = text.startIndex
        
        for index in text.indices {
            charCount += 1
            
            if charCount > maxCharacterCount {
                break
            }

            lastValidIndex = text.index(after: index)
        }
        
        return String(text[..<lastValidIndex])
    }
    
    func truncateToBytes(_ maxBytes: Int, ellipsis: String = "...") -> String {
        let ellipsisBytes = ellipsis.utf8.count
        let targetBytes = maxBytes - ellipsisBytes
        
        guard self.utf8.count > maxBytes, targetBytes > 0 else { return self }
        
        var result = ""
        var currentBytes = 0
        
        for character in self {
            let charBytes = String(character).utf8.count
            if currentBytes + charBytes > targetBytes {
                break
            }
            result.append(character)
            currentBytes += charBytes
        }
        
        return result + ellipsis
    }
    func truncatedToMaxBytesShow() -> String {
        // 检测字符串类型
        let isPureEnglish = self.allSatisfy { $0.isASCII }
        let isPureChinese = self.allSatisfy { !$0.isASCII }
        
        var maxLength: Int
        
        if isPureEnglish {
            // 纯英文：17个字符
            maxLength = maxEnglishCount
        } else if isPureChinese {
            // 纯中文：12个字符
            maxLength = maxChineseCount
        } else {
            // 中英文混合：计算12个中文的物理长度
            maxLength = calculateMixedMaxLength()
        }
        
        guard self.count > maxLength else { return self }
        
        let endIndex = self.index(self.startIndex, offsetBy: maxLength)
        return String(self[..<endIndex]) + "..."
    }
    
    func calculateMixedMaxLength() -> Int {
        var totalLength = 0
        var currentLength = 0
        let targetCount = 24

        for character in self {
            let charLength = character.isASCII ? 1 : 2
            if totalLength + charLength > targetCount {
                break
            }

            totalLength += charLength
            currentLength += 1
        }

        return currentLength
    }
    
    func trimmingWhitespace() -> String {
        return self.trimmingCharacters(in: .whitespaces)
    }
    
    func isLetterNumberAndChinese() -> Bool {
        let pattern = "^[a-zA-Z\\u4E00-\\u9FA5\\d ]*$"
        let pred = NSPredicate(format: "SELF MATCHES %@", pattern)
        let isMatch = pred.evaluate(with: self)
        if !isMatch {
            let other = "➋➌➍➎➏➐➑➒" // 九宫格输入法的字符
            let len = self.count
            for i in 0..<len {
                let tmpStr = self as NSString
                let tmpOther = other as NSString
                let c = tmpStr.character(at: i)
                
                if !((isalpha(Int32(c))) > 0 || (isalnum(Int32(c))) > 0 || ((Int(c) == "_".hashValue)) || (Int(c) == "-".hashValue) || ((c >= 0x4e00 && c <= 0x9fa6)) || (tmpOther.range(of: self).location != NSNotFound)) {
                    return false
                }
                return true
            }
        }
        return isMatch
    }
}

extension String {
    /// 计算单行文字size
    func boundingRect(with constrainedSize: CGSize, font: UIFont, lineSpacing: CGFloat? = nil) -> CGSize {
        let attritube = NSMutableAttributedString(string: self)
        let range = NSRange(location: 0, length: attritube.length)
        attritube.addAttributes([NSAttributedString.Key.font: font], range: range)
        if lineSpacing != nil {
            let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.lineSpacing = lineSpacing!
            attritube.addAttribute(NSAttributedString.Key.paragraphStyle, value: paragraphStyle, range: range)
        }
        
        let rect = attritube.boundingRect(with: constrainedSize, options: [.usesLineFragmentOrigin, .usesFontLeading], context: nil)
        var size = rect.size
        
        if let currentLineSpacing = lineSpacing {
            // 文本的高度减去字体高度小于等于行间距，判断为当前只有1行
            let spacing = size.height - font.lineHeight
            if spacing <= currentLineSpacing && spacing > 0 {
                size = CGSize(width: size.width, height: font.lineHeight)
            }
        }
        size.height = CGFloat(ceilf(Float(size.height)))
        size.width = CGFloat(ceilf(Float(size.width)))
        return size
    }
    
    /// 计算多行文字size
    func boundingRect(with constrainedSize: CGSize, font: UIFont, lineSpacing: CGFloat? = nil, lines: Int) -> CGSize {
        if lines < 0 {
            return .zero
        }
        
        let size = boundingRect(with: constrainedSize, font: font, lineSpacing: lineSpacing)
        if lines == 0 {
            return size
        }
        
        let currentLineSpacing = (lineSpacing == nil) ? (font.lineHeight - font.pointSize) : lineSpacing!
        let maximumHeight = font.lineHeight * CGFloat(lines) + currentLineSpacing * CGFloat(lines - 1)
        if size.height >= maximumHeight {
            return CGSize(width: size.width, height: maximumHeight)
        }
        
        return size
    }
}
