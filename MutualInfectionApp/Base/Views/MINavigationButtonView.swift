// SCNavigationButtonView.swift
import UIKit

class MINavigationButtonView: UIStackView {
    
    var buttonArray: [UIButton] = []
    
    private var attributes: [NSAttributedString.Key: Any]?
    private var buttonSize: CGSize = .zero
    
    private static let maximumButtonCount = 4
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        commonSetup()
    }
    
    required init(coder: NSCoder) {
        super.init(coder: coder)
        commonSetup()
    }
    
    private func commonSetup() {
        axis = .horizontal
        alignment = .center
        distribution = .fill
        spacing = 3.0
        isLayoutMarginsRelativeArrangement = false
    }
    
    func setButtonTitleAttributes(_ attributes: [NSAttributedString.Key: Any]?, preferredButtonSize size: CGSize) {
        self.attributes = attributes
        self.buttonSize = size
        
        if !buttonArray.isEmpty {
            for button in buttonArray {
                setTextButtonTitleAttributes(button)
            }
            //refreshButtonLayout()
        }
    }
    
    @discardableResult
    func addButtonWithTitle(_ title: String) -> UIButton? {
        if buttonArray.count >= MINavigationButtonView.maximumButtonCount {
            return nil
        }
        
        let button = NotHighlightButton(type: .custom)
        button.setTitle(title, for: .normal)
        
        button.adjustsImageWhenHighlighted = true
        setTextButtonTitleAttributes(button)
        addArrangedSubview(button)
        
        buttonArray.append(button)
        
        
        return button
    }
    
    private func setTextButtonTitleAttributes(_ button: UIButton) {
        guard let attributes = attributes else { return }
        
        if let font = attributes[.font] as? UIFont {
            button.titleLabel?.font = font
        }
        
        if let color = attributes[.foregroundColor] as? UIColor {
            button.setTitleColor(color, for: .normal)
        }
    }
    
    @discardableResult
    func addButtonItemWithImage(_ image: UIImage,_ selectImg:UIImage = UIImage()) -> UIButton? {
        if buttonArray.count >= MINavigationButtonView.maximumButtonCount {
            return nil
        }
        
        let button = UIButton(type: .custom)
        button.setBackgroundImage(image, for: .normal)
        button.setBackgroundImage(selectImg, for: .selected)
        
        button.adjustsImageWhenHighlighted = true
        addArrangedSubview(button)
        
        buttonArray.append(button)
        
        return button
    }
    
    func removeButton(_ button: UIButton) {
        if buttonArray.contains(button) {
            removeArrangedSubview(button)
            button.removeFromSuperview()
            buttonArray.removeAll { $0 == button }
        }
    }
}
