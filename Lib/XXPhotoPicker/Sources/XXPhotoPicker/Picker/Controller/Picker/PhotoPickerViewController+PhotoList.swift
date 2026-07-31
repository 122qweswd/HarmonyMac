//
//  PhotoPickerViewController+PhotoList.swift.swift
//  HXPhotoPicker
//
//  Created by Slience on 2021/8/27.
//

import UIKit
import Photos


extension PhotoPickerViewController: PhotoPickerListDelegate {
    
    func initListView() {
        listView = config.listView.init(config: pickerConfig)
        listView.delegate = self
        addChild(listView)
        view.addSubview(listView.view)
    }
    
    public func photoList(_ photoList: PhotoPickerList, didSelectCell asset: PhotoAsset, at index: Int, animated: Bool) {
        if !pickerController.shouldClickCell(photoAsset: asset, index: index) {
            return
        }
        let selectionTapAction: SelectionTapAction
        if let tapAction = pickerController.cellTapAction(photoAsset: asset, index: index) {
            selectionTapAction = tapAction
        }else {
            if asset.mediaType == .photo {
                selectionTapAction = pickerConfig.photoSelectionTapAction
            }else {
                selectionTapAction = pickerConfig.videoSelectionTapAction
            }
        }
        switch selectionTapAction {
        case .preview:
            pushPreviewViewController(previewAssets: listView.assets, currentPreviewIndex: index, animated: animated)
        case .quickSelect:
            asset.playerTime = 0
            quickSelect(asset)
        case .openEditor:
            asset.playerTime = 0
            let cell = listView.getCell(for: asset)
            openEditor(asset, image: cell?.photoView.image, animated: animated)
        }
    }
    
    public func photoList(didLimitCell photoList: PhotoPickerList) {
        if #available(iOS 14, *) {
            PHPhotoLibrary.shared().presentLimitedLibraryPicker(from: pickerController)
        }
    }
    
    public func photoList(_ photoList: PhotoPickerList, didSelectedAsset asset: PhotoAsset) {
        
        if isShowToolbar {
            photoToolbar.insertSelectedAsset(asset)
            updateToolbarFrame()
        }
    }
    
    public func photoList(_ photoList: PhotoPickerList, didDeselectedAsset asset: PhotoAsset) {
        if isShowToolbar {
            photoToolbar.removeSelectedAssets([asset])
            updateToolbarFrame()
        }
    }
    
    public func photoList(_ photoList: PhotoPickerList, updateAsset asset: PhotoAsset) {
        if isShowToolbar {
            photoToolbar.reloadSelectedAsset(asset)
            requestSelectedAssetFileSize()
        }
    }
    
    public func photoList(selectedAssetDidChanged photoList: PhotoPickerList) {
        if isShowToolbar {
            photoToolbar.selectedAssetDidChanged(pickerController.selectedAssetArray)
            requestSelectedAssetFileSize()
        }
        finishItem?.selectedAssetDidChanged(pickerController.selectedAssetArray)
        selectItem?.selectedAssetDidChanged(pickerController.selectedAssetArray)
    }
    
    public func photoList(_ photoList: PhotoPickerList, openEditor asset: PhotoAsset, with image: UIImage?) {
        asset.playerTime = 0
        openEditor(asset, image: image)
    }
    
    public func photoList(_ photoList: PhotoPickerList, openPreview assets: [PhotoAsset], with page: Int, animated: Bool) {
        pushPreviewViewController(previewAssets: assets, currentPreviewIndex: page, animated: animated)
    }
    
    public func photoList(presentCamera photoList: PhotoPickerList) {
        presentCameraViewController()
    }
    
    public func photoList(presentFilter photoList: PhotoPickerList, modalPresentationStyle: UIModalPresentationStyle) {
        didFilterItemClick(modalPresentationStyle: modalPresentationStyle)
    }
    
    public func quickSelect(_ photoAsset: PhotoAsset, isCapture: Bool = false) {
        if !photoAsset.isSelected {
            if !pickerConfig.isMultipleSelect || (pickerConfig.isSingleVideo && photoAsset.mediaType == .video) {
                if pickerController.pickerData.canSelect(
                    photoAsset,
                    isShowHUD: true,
                    isFilterEditor: isCapture
                ) {
                    pickerController.singleFinishCallback(for: photoAsset)
                }
                return
            }
        }
        if let cell = listView.getCell(for: photoAsset) as? PhotoPickerViewCell {
            cell.selectedAction(photoAsset.isSelected)
        }
    }
    
    public func openEditor(
        _ photoAsset: PhotoAsset,
        image: UIImage?,
        animated: Bool = true
    ) {
        if photoAsset.mediaType == .video {
            openVideoEditor(
                photoAsset: photoAsset,
                coverImage: image,
                animated: animated
            )
        }else {
            openPhotoEditor(
                photoAsset: photoAsset,
                animated: animated
            )
        }
    }
    
    @discardableResult
    public func openPhotoEditor(
        photoAsset: PhotoAsset,
        animated: Bool = true
    ) -> Bool {
       if photoAsset.mediaType != .photo {
            return false
        }
        let editIndex: Int
        if let index = listView.assets.firstIndex(of: photoAsset) {
            editIndex = index
        }else {
            editIndex = 0
        }
        if !pickerController.shouldEditAsset(photoAsset: photoAsset, atIndex: editIndex) {
            return false
        }
        return false
    }
    
    @discardableResult
    public func openVideoEditor(
        photoAsset: PhotoAsset,
        coverImage: UIImage? = nil,
        animated: Bool = true
    ) -> Bool {
        if photoAsset.mediaType != .video {
            return false
        }
        let editIndex: Int
        if let index = listView.assets.firstIndex(of: photoAsset) {
            editIndex = index
        }else {
            editIndex = 0
        }
        if !pickerController.shouldEditAsset(photoAsset: photoAsset, atIndex: editIndex) {
            return false
        }
        return false
    }
}
