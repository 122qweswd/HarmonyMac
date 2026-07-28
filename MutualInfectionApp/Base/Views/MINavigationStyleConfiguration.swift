// SCNavigationStyleConfiguration.swift
import UIKit

class MINavigationStyleConfiguration: NSObject, NSCopying {
    
    static let `default` = MINavigationStyleConfiguration()
    
    var horizontalContentInset: UIEdgeInsets = UIEdgeInsets(top: 0, left: 14, bottom: 0, right: 14)
    var barTintColor: UIColor = .white
    var titleTextAttributes: [NSAttributedString.Key: Any] = [:]
    var numberOfLinesForTitle: Int = 1
    var backButtonImage: UIImage?
    var barButtonTitleAttributes: [NSAttributedString.Key: Any] = [:]
    var imageButtonSize: CGSize = CGSize(width: 40, height: 40)
    var sepratorLineColor: UIColor = .clear
    
    override init() {
        super.init()
        setupDefaultStyleConfigurations()
    }
    
    private func setupDefaultStyleConfigurations() {
        horizontalContentInset = UIEdgeInsets(top: 0, left: 14, bottom: 0, right: 14)
        barTintColor = .clear
        
        backButtonImage = MINavigationStyleConfiguration.defaultBackButtonImage()
        sepratorLineColor = .clear
        
        numberOfLinesForTitle = 1
        
        titleTextAttributes = [
            .font:SFCompact(weight: .semibold,size: 18),
            .foregroundColor: UIColor(white: 0.2, alpha: 1)
        ]
        
        barButtonTitleAttributes = [
            .font:SFCompact(size: 15),
            .foregroundColor: UIColor(white: 0.2, alpha: 1)
        ]
        
        imageButtonSize = CGSize(width: 40, height: 40)
    }
    
    func copy(with zone: NSZone? = nil) -> Any {
        let copy = MINavigationStyleConfiguration()
        copy.barTintColor = barTintColor
        copy.titleTextAttributes = titleTextAttributes
        copy.sepratorLineColor = sepratorLineColor
        copy.backButtonImage = backButtonImage
        copy.barButtonTitleAttributes = barButtonTitleAttributes
        copy.horizontalContentInset = horizontalContentInset
        copy.imageButtonSize = imageButtonSize
        copy.numberOfLinesForTitle = numberOfLinesForTitle
        return copy
    }
    
    static func defaultBackButtonImage() -> UIImage? {
        return UIImage.chevronBackward
    }
    
    static func defaultCloseButtonImage() -> UIImage? {
        return UIImage.btnClose
    }
}
