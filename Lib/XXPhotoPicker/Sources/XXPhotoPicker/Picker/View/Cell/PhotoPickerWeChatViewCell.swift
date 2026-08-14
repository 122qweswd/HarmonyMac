//
//  PhotoPickerSelectableViewCell.swift
//  HXPhotoPicker
//
//  Created by Slience on 2021/3/12.
//

import UIKit
import PhotosUI

open class PhotoPickerWeChatViewCell: PhotoPickerViewCell {
    
    public var selectButton: NotHighlightButton!
    
    /// 添加视图
    open override func initView() {
        super.initView()
        selectButton = NotHighlightButton(type: .custom)
        selectButton.setImage(UIImage(named: "select"), for: .normal)
        selectButton.isSelected = false
        selectButton.isHidden = true
        selectButton.isUserInteractionEnabled = false
        //selectButton.addTarget(self, action: #selector(didSelectControlClick(sender:)), for: .touchUpInside)
        contentView.addSubview(selectButton)
    }
    
    /// 更新选择状态
    open override func updateSelectedState(isSelected: Bool, animated: Bool) {
        super.updateSelectedState(isSelected: isSelected, animated: animated)
        let boxWidth = config.selectBox.size.width
        let boxHeight = config.selectBox.size.height
        if isSelected {
            selectButton.isHidden = false
            updateSelectControlSize(width: boxWidth, height: boxHeight)
        } else {
            selectButton.isHidden = true
            updateSelectControlSize(width: boxWidth, height: boxHeight)
        }
        
        if animated {
            selectButton.layer.removeAnimation(forKey: "SelectControlAnimation")
            let keyAnimation = CAKeyframeAnimation.init(keyPath: "transform.scale")
            keyAnimation.duration = 0.3
            keyAnimation.values = [1.2, 0.8, 1.1, 0.9, 1.0]
            selectButton.layer.add(keyAnimation, forKey: "SelectControlAnimation")
        }
    }
    
    /// 更新选择框大小
    open func updateSelectControlSize(width: CGFloat, height: CGFloat) {
        let topMargin = config.selectBoxTopMargin
        let rightMargin = config.selectBoxRightMargin
        let rect = CGRect(x: self.width - rightMargin - width, y: topMargin, width: width, height: height)
        if selectButton.hxPicker_frame.equalTo(rect) {
            return
        }
        if let photoAsset = photoAsset, photoAsset.isScrolling {
            let x = selectButton.x
            selectButton.hxPicker_frame = rect
            selectButton.hxPicker_x = x
        }else {
            selectButton.hxPicker_frame = rect
        }
    }
    
    open override func layoutView() {
        super.layoutView()
        updateSelectControlSize()
    }
    
    open func setupLivePhotoState() {
        if photoAsset.isEdited {
            return
        }
        assetTypeIcon.image = .imageResource.picker.photoList.cell.livePhoto.image
        assetTypeMaskView.isHidden = false
        if photoAsset.isSelected {
            assetTypeLb.text = ""
        }else {
            assetTypeIcon.isHidden = false
            assetTypeLb.text = .textPhotoList.cell.LivePhotoTitle.text
            setupAssetTypeFrame()
        }
    }
    
    
    func updateSelectControlSize() {
        updateSelectControlSize(width: selectButton.width, height: selectButton.height)
    }
}


