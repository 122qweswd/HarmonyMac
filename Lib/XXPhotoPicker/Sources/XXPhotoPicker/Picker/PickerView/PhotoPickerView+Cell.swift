//
//  PhotoPickerView+Cell.swift
//  HXPhotoPicker
//
//  Created by Slience on 2021/9/17.
//

import UIKit

extension PhotoPickerView: PhotoPickerViewCellDelegate {
    
    public func pickerCell(
        _ cell: PhotoPickerBaseViewCell,
        didSelectControl isSelected: Bool
    ) {
        if isSelected {
            // 取消选中
            let photoAsset = cell.photoAsset!
            manager.removePhotoAsset(photoAsset: photoAsset)
            // 清空视频编辑的数据
          
            cell.updateSelectedState(
                isSelected: false,
                animated: true
            )
            updateCellSelectedTitle()
        } else {
            // 选中
            func addAsset() {
                if manager.addedPhotoAsset(photoAsset: cell.photoAsset) {
                    cell.updateSelectedState(
                        isSelected: true,
                        animated: true
                    )
                    updateCellSelectedTitle()
                }
            }
            let inICloud = cell.photoAsset.checkICloundStatus(
                allowSyncPhoto: manager.config.allowSyncICloudWhenSelectPhoto,
                hudAddedTo: self,
                completion: { _, isSuccess in
                if isSuccess {
                    addAsset()
                }
            })
            if !inICloud {
                addAsset()
            }
        }
    }
}
