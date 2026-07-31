//
//  PhotoPickerSelectItemView.swift
//  HXPhotoPicker
//
//  Created by Niko on 2025/9/4.
//  Copyright © 2025 Silence. All rights reserved.
//

import UIKit

public class PhotoPickerSelectItemView: UIView, PhotoNavigationItem {
    public weak var itemDelegate: PhotoNavigationItemDelegate?
    public var isSelected: Bool = false {
        didSet {
            button.isSelected = isSelected
        }
    }
    public var itemType: PhotoNavigationItemType { .select }
    
    let config: PickerConfiguration
    public required init(config: PickerConfiguration) {
        self.config = config
        super.init(frame: .zero)
        initView()
    }
    
    var button: NotHighlightButton!
    func initView() {
        button = NotHighlightButton(type: .custom)
        button.setTitle("全选".localized, for: .normal)
        button.setTitle("取消全选".localized, for: .selected)
        button.titleLabel?.font = .systemFont(ofSize: 16, weight: .semibold)
        button.setTitleColor(UIColor.white, for: .normal)
        button.addTarget(self, action: #selector(didSelectClick), for: .touchUpInside)
        
        button.contentHorizontalAlignment = .right
        button.showsTouchWhenHighlighted = false // 禁用高亮视觉反馈

        addSubview(button)
        
        setColor()
        updateButtonFrame()
    }
    
    public weak var pickerController: PhotoPickerController?
    
    public var assetResult: PhotoFetchAssetResult?
    
    func setColor() {
        guard let color = PhotoManager.isDark ? config.navigationDarkTintColor : config.navigationTintColor else {
            return
        }
        
        button.setTitleColor(color, for: .normal)
    }
    
    @objc
    func didSelectClick() {
        if #available(iOS 13.0, *) {
            if button.isSelected {
                pickerController?.pickerData.removeAll()
            } else {
                pickerController?.pickerData.append(assetResult?.assets.filter { $0.isSelected == false && !$0.inICloud } ?? [])
            }
            
            button.isSelected = !button.isSelected
            updateButtonFrame()
            pickerController?.mi_reloadData()
        } else {
            
        }
    }
    
    deinit {
        print("正常释放")
    }
    
    public func selectedAssetDidChanged(_ photoAssets: [PhotoAsset]) {
        updateSelectButtonStatus()
    }
    
    public func selectedAssetDidChanged(_ pickerController: PhotoPickerController, _ assetResult: PhotoFetchAssetResult) {
        self.pickerController = pickerController
        self.assetResult = assetResult
        updateSelectButtonStatus()
    }
    
    func updateSelectButtonStatus() {
        if let assetResult = self.assetResult {
            
            let totalCount = assetResult.assets.count
            let count = self.pickerController?.selectedAssetArray.count
            
            if count == totalCount {
                button.isSelected = true
            } else {
                button.isSelected = false
            }
            updateButtonFrame()
        }
    }
    
    private func updateButtonFrame() {
        var selectWidth: CGFloat = "取消全选".localized.width(
            ofFont: button.titleLabel!.font,
            maxHeight: 50
        )
        if selectWidth < 40 {
            selectWidth = 40
        }
        button.size = .init(width: selectWidth, height: 40)
        size = button.size
    }
    
    public override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        if #available(iOS 13.0, *) {
            if traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
                setColor()
            }
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
}

public class NotHighlightButton: UIButton {
    public override var isHighlighted: Bool {
        get {
            return false
        }
        set {
            super.isHighlighted = false
        }
    }
}
