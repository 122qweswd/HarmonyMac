//
//  MenuCardView.swift
//  nshareIos
//
//  Created by Assistant on 2025/09/01.
//

import UIKit
import SnapKit

/// A simple rounded menu card with vertically stacked rows and separators.
/// Rows are selectable and reported via the `onSelectItem` callback.
final class MenuCardView: UIView {
    
    var closeAction:ClickBlockVoid?
    // MARK: - Types
    struct MenuItem {
        let title: String
        let identifier: String
        
        init(title: String, identifier: String, icon: UIImage? = nil) {
            self.title = title
            self.identifier = identifier
        }
    }

    // MARK: - Public API
    var onSelectItem: ((MenuItem, Int) -> Void)?
    var isChange:Bool = true
    // MARK: - UI
     let stackView: UIStackView = {
        let s = UIStackView()
        s.axis = .vertical
        s.alignment = .fill
        s.distribution = .fillEqually // 平分行高，便于整体高度固定
        s.spacing = 0
        return s
    }()

    // MARK: - Data
    private var items: [MenuItem] = []

    // MARK: - Init
    init(items: [MenuItem] = [],newFram :CGRect = .zero,isAllowChange:Bool = true) {
        super.init(frame: .zero)
        self.isChange = isAllowChange
       
        commonInit()
        setItems(items)
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        commonInit()
    }

    // 固定组件整体尺寸：宽127，高174
    override var intrinsicContentSize: CGSize {
        return CGSize(width: phoneToPad(190), height: phoneToPad(304))
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        closeAction?()
        dismissSelf()
    }

    // MARK: - Setup
    private func commonInit() {
        backgroundColor = .clear
    
        stackView.layer.masksToBounds = false
        stackView.layer.shadowColor = UIColor.black.cgColor
        stackView.layer.shadowOpacity = 0.08
        stackView.layer.shadowRadius = 10
        stackView.layer.shadowOffset = CGSize(width: 0, height: 4)
//        stackView.backgroundColor = .white
        stackView.addBackground(color: .white,cornerRadius: 34)
        addSubview(stackView)
      
    }

    // MARK: - Public
    func setItems(_ newItems: [MenuItem]) {
        items = newItems
        rebuildRows()
    }

    // MARK: - Rows
    private func rebuildRows() {
        stackView.arrangedSubviews.forEach { $0.removeFromSuperview() }

        for (index, item) in items.enumerated() {
            let rowContainer = UIView()

            let button = UIButton(type: .system)
            button.setTitle(item.title, for: .normal)
            button.setTitleColor("#000000".color.withAlpha(0.9), for: .normal)
            if isChange == false && item.title ==  "设备名称".localized {
                button.setTitleColor("#000000".color.withAlpha(0.3), for: .normal)
            }
            button.contentHorizontalAlignment = .left
            button.titleLabel?.font = SFCompact(weight: .medium,size: 17)
            button.contentEdgeInsets = UIEdgeInsets(top: 0, left: 16, bottom: 0, right: 16)
            button.tag = index
            if isChange {
                button.addTarget(self, action: #selector(handleTap(_:)), for: .touchUpInside)
            }else{
                if item.title !=  "设备名称".localized {
                    button.addTarget(self, action: #selector(handleTap(_:)), for: .touchUpInside)
                }
            }

            rowContainer.addSubview(button)
            button.snp.makeConstraints { make in
                if UIDevice.current.userInterfaceIdiom == .pad {
                    make.width.equalTo(139)
                    make.centerX.equalToSuperview()
                    make.centerY.equalToSuperview()
                }else {
                    make.edges.equalToSuperview()
                }
            }

            // Separator (skip last row)
            if index < items.count - 1 {
                let separator = UIView()
                separator.backgroundColor = UIColor(white: 0.85, alpha: 1.0)
                rowContainer.addSubview(separator)
                separator.snp.makeConstraints { make in
                    make.height.equalTo(0.5)
                    if UIDevice.current.userInterfaceIdiom == .pad {
                        make.leading.equalToSuperview().offset(28)
                        make.trailing.equalToSuperview().inset(28)
                    }else {
                        make.leading.equalToSuperview().offset(16)
                        make.trailing.equalToSuperview().inset(16)
                    }
                    make.bottom.equalToSuperview()
                }
            }

            stackView.addArrangedSubview(rowContainer)
        }
    }

    // MARK: - Actions
    @objc private func handleTap(_ sender: UIButton) {
        let idx = sender.tag
        guard idx >= 0, idx < items.count else { return }
        onSelectItem?(items[idx], idx)
        dismissSelf()
    }

    private func dismissSelf() {
        if let overlay = superview as? UIControl { // 如果包在遮罩容器里
            overlay.removeFromSuperview()
        } else {
            removeFromSuperview()
        }
    }
    deinit {
        print("deinit:释放============\(self)")
    }
}

extension UIStackView {
    func addBackground(color: UIColor, cornerRadius: CGFloat) {
       if #available(iOS 14.0, *) {
           backgroundColor = color
           layer.cornerRadius = cornerRadius
        } else {
            let subView = UIView(frame: bounds)
            subView.backgroundColor = color
            subView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            subView.layer.cornerRadius = cornerRadius
            subView.layer.masksToBounds = true
            insertSubview(subView, at: 0)
        }
    }
}
// MARK: - Convenience Factory
extension MenuCardView {
    /// Default Huawei-Share style menu items
    static func defaultMenu(isAllowChange:Bool = true) -> MenuCardView {
       
        let defaults: [MenuCardView.MenuItem] = [
            .init(title: "设备名称".localized, identifier: "device_name"),
            .init(title: "互传记录".localized, identifier: "share_record"),
            .init(title: "帮助与反馈".localized, identifier: "help_feedback"),
            .init(title: "系统权限管理".localized, identifier: "permissions"),
            .init(title: "关于".localized, identifier: "about")
        ]
        let menuView = MenuCardView(items: defaults,newFram:.zero,isAllowChange:isAllowChange)
        print("menuView.frame.width \(menuView.frame.width)")
        print("menuView.frame.height \(menuView.frame.height)")
       
        return menuView
    }
    
    /// Default Huawei-Share style menu items
    static func historyMenu() -> MenuCardView {
        
        let defaults: [MenuCardView.MenuItem] = [
            .init(title: "设备名称".localized, identifier: "device_name"),
            .init(title: "互传记录".localized, identifier: "share_record"),
            .init(title: "帮助与反馈".localized, identifier: "help_feedback"),
            .init(title: "系统权限管理".localized, identifier: "permissions"),
            .init(title: "关于".localized, identifier: "about")
        ]
        let menuView = MenuCardView(items: defaults)
        print("menuView.frame.width \(menuView.frame.width)")
        print("menuView.frame.height \(menuView.frame.height)")
        return menuView
    }
    
}

// MARK: - dismiss
extension MenuCardView {
    
    /// 隐藏view
    static func dismissMenuCardView() {
        let window =  (UIApplication.shared.connectedScenes.first as? UIWindowScene)?.windows.first
        guard let views = window?.subviews else {
            return
        }
        for view in views {
            if view is MenuCardView {
                let cardview: MenuCardView? = view as? MenuCardView
                cardview?.dismissSelf()
                break
            }
        }
    }
}
