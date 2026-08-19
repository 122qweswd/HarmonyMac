//
//  PhotoPickerViewProtocol.swift
//  HXPhotoPicker
//
//  Created by Slience on 2021/9/18.
//

import UIKit

public protocol PhotoPickerViewDelegate: AnyObject {
    
    /// 选择完成之后调用
    /// - Parameters:
    ///   - photoPickerView: 对应的 PhotoPickerView
    ///   - result: 选择的结果
    ///     result.photoAssets  选择的资源数组
    func photoPickerView(
        _ photoPickerView: PhotoPickerView,
        didFinishSelection result: PickerResult
    )
    
    /// 选择完成之后调用，如果是在预览界面点击完成。则会在dismiss完成之后触发
    /// - Parameters:
    ///   - photoPickerView: 对应的 PhotoPickerView
    ///   - result: 选择的结果
    func photoPickerView(
        _ photoPickerView: PhotoPickerView,
        dismissCompletion result: PickerResult
    )
    
    /// 开始拖动手势
    /// - Parameters:
    ///   - photoPickerView: 对应的 PhotoPickerView
    ///   - gestureRecognizer: 拖动手势识别器
    ///   - photoAsset: 对应的 PhotoAsset 对象
    func photoPickerView(
        _ photoPickerView: PhotoPickerView,
        gestureRecognizer: UIPanGestureRecognizer,
        beginDrag photoAsset: PhotoAsset,
        dragView: UIView
    )
    
    /// 拖动手势改变中
    func photoPickerView(
        _ photoPickerView: PhotoPickerView,
        gestureRecognizer: UIPanGestureRecognizer,
        changeDrag photoAsset: PhotoAsset
    )
    
    /// 拖动手势已经结束
    /// return 拖拽的视图是否需要返回动画
    func photoPickerView(
        _ photoPickerView: PhotoPickerView,
        gestureRecognizer: UIPanGestureRecognizer,
        endDrag photoAsset: PhotoAsset
    ) -> Bool
    
    /// 即将选择 cell 时调用
    func photoPickerView(
        _ photoPickerView: PhotoPickerView,
        willSelectAsset photoAsset: PhotoAsset,
        at index: Int
    )

    /// 选择了 cell 之后调用
    func photoPickerView(
        _ photoPickerView: PhotoPickerView,
        didSelectAsset photoAsset: PhotoAsset,
        at index: Int
    )

    /// 即将取消选择 cell
    func photoPickerView(
        _ photoPickerView: PhotoPickerView,
        willDeselectAsset photoAsset: PhotoAsset,
        at index: Int
    )

    /// 取消选择 cell
    func photoPickerView(
        _ photoPickerView: PhotoPickerView,
        didDeselectAsset photoAsset: PhotoAsset,
        at index: Int
    )
    
    /// 预览界面点击了原图按钮
    /// - Parameters:
    ///   - photoPickerView: 对应的 PhotoPickerView
    ///   - isSelected: 是否选中
    /// 获取原图大小的方法：manager.requestSelectedAssetFileSize(completion: <#T##(Int, String) -> Void#>)
    func photoPickerView(
        _ photoPickerView: PhotoPickerView,
        previewDidOriginalButton isSelected: Bool
    )
}

public extension PhotoPickerViewDelegate {
    
    func photoPickerView(
        _ photoPickerView: PhotoPickerView,
        didFinishSelection result: PickerResult
    ) { }
    
    func photoPickerView(
        _ photoPickerView: PhotoPickerView,
        dismissCompletion result: PickerResult
    ) { }
    
    func photoPickerView(
        _ photoPickerView: PhotoPickerView,
        gestureRecognizer: UIPanGestureRecognizer,
        beginDrag photoAsset: PhotoAsset,
        dragView: UIView
    ) { }
    
    func photoPickerView(
        _ photoPickerView: PhotoPickerView,
        gestureRecognizer: UIPanGestureRecognizer,
        changeDrag photoAsset: PhotoAsset
    ) { }
    
    func photoPickerView(
        _ photoPickerView: PhotoPickerView,
        gestureRecognizer: UIPanGestureRecognizer,
        endDrag photoAsset: PhotoAsset
    ) -> Bool { true }
    
    func photoPickerView(
        _ photoPickerView: PhotoPickerView,
        willSelectAsset photoAsset: PhotoAsset,
        at index: Int
    ) { }

    func photoPickerView(
        _ photoPickerView: PhotoPickerView,
        didSelectAsset photoAsset: PhotoAsset,
        at index: Int
    ) { }

    func photoPickerView(
        _ photoPickerView: PhotoPickerView,
        willDeselectAsset photoAsset: PhotoAsset,
        at index: Int
    ) { }

    func photoPickerView(
        _ photoPickerView: PhotoPickerView,
        didDeselectAsset photoAsset: PhotoAsset,
        at index: Int
    ) { }
    
    func photoPickerView(
        _ photoPickerView: PhotoPickerView,
        previewDidOriginalButton isSelected: Bool
    ) { }
}
