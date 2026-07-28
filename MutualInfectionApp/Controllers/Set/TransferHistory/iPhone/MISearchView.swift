//
//  MISearchView.swift
//  MutualInfectionApp
//
//  Created by Niko on 2025/9/11.
//

import UIKit
import SnapKit
import Hero
import IQKeyboardManagerSwift

class MISearchView: UIView {
    
    var isEdit: Bool! {
        didSet {
            if isEdit {
                searchTextField.becomeFirstResponder()
                removeGestureRecognizer(tap)
            }
            closeButton.isHidden = !isEdit
            searchTextField.isUserInteractionEnabled = isEdit
        }
    }

    var isEnable: Bool = true {
        didSet {
            if isEnable {
                self.isUserInteractionEnabled = true
                searchTextField.placeholderColor("#000000".color.withAlpha(0.6))
                searchTextField.backgroundColor = "#000000".color.withAlpha(0.05)
                searchIconImageView?.tintColor = "#000000".color.withAlpha(0.6)
            } else {
                self.isUserInteractionEnabled = false
                searchTextField.placeholderColor("#C3C3C3".color)
                searchTextField.backgroundColor = "#FAFAFA".color
                searchIconImageView?.tintColor = "#C3C3C3".color
            }
        }
    }
    
    /// 事件点击
    var clickClosure: (() -> Void)?
    
    /// 关闭
    var closeCallBack: (() -> Void)?
    
    /// 文本变化回调
    var textDidChange: ((String) -> Void)?
    
    private let stackView: UIStackView = {
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.alignment = .center
        stack.spacing = 8
        stack.distribution = .fill
        return stack
    }()
    
    var searchIconImageView: UIImageView?
    
    lazy var searchTextField: UITextField = {
        let textField = UITextField()
        textField.placeholder = LocalizedStrings.search
        textField.placeholderColor("#000000".color.withAlpha(0.6))
        textField.font = pingFangSC(17, weight: .semibold)
        textField.backgroundColor = "#000000".color.withAlpha(0.05)
        textField.layer.cornerRadius = 22
        textField.clearButtonMode = .never
        textField.leftViewMode = .always
        textField.borderStyle = .none
        
        textField.hero.id = "search"
        
        // 左侧放大镜
        let icon = UIImageView(image: UIImage(systemName: "magnifyingglass"))
        searchIconImageView = icon
        icon.tintColor = "#000000".color.withAlpha(0.6)
        icon.contentMode = .scaleAspectFit
        icon.frame = CGRect(x: 0, y: 0, width: 24, height: 24)
        
        let leftView = UIView(frame: CGRect(x: 0, y: 0, width: 44, height: 44))
        icon.center = CGPoint(x: 22, y: 22)
        leftView.addSubview(icon)
        textField.leftView = leftView
        
        textField.isUserInteractionEnabled = false
        
        textField.addTarget(self, action: #selector(textFieldDidChange(_:)), for: .editingChanged)
        
        return textField
    }()
    
    let closeButton: UIButton = {
        let button = UIButton(type: .system)
        button.setImage(UIImage.btnClose, for: .normal)
        button.contentMode = .scaleAspectFill
        button.isHidden = true
        button.hero.id = "close"
        return button
    }()
    
    /// 点击手势
    var tap: UITapGestureRecognizer!
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        isEdit = false
        setupViews()
        hero.isEnabled = true
        if !isEdit {
            tap = UITapGestureRecognizer(target: self, action: #selector(tapAction))
            addGestureRecognizer(tap)
        }
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupViews()
    }
    
    private func setupViews() {
        addSubview(stackView)
        stackView.snp.makeConstraints { make in
            make.edges.equalTo(UIEdgeInsets(top: 0, left: 16, bottom: 0, right: 16))
            make.height.equalTo(44)
        }
        
        //configShadow(views: [closeButton], shadowRadius: 22)
        
        stackView.addArrangedSubview(searchTextField)
        stackView.addArrangedSubview(closeButton)
        
        searchTextField.snp.makeConstraints { make in
            make.height.equalTo(44)
        }
        closeButton.snp.makeConstraints { make in
            make.width.height.equalTo(44)
        }
        
        // X按钮点击清空
        closeButton.addTarget(self, action: #selector(closeButtonClick), for: .touchUpInside)
    }
    
    @objc private func closeButtonClick() {
        closeCallBack?()
    }
    
    @objc private func tapAction() {
        clickClosure?()
    }
    
    @objc private func textFieldDidChange(_ textField: UITextField) {
        textDidChange?(textField.text ?? "")
    }
}

extension UITextField {
    /// 修改placeholer文字颜色
    func placeholderColor(_ color: UIColor) {
        let attributes = [NSAttributedString.Key.foregroundColor: color]
        self.attributedPlaceholder = NSAttributedString(string: self.placeholder ?? "", attributes: attributes)
    }
}
