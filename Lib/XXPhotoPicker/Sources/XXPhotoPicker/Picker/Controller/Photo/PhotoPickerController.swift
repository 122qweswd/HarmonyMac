//
//  PhotoPickerController.swift
//  照片选择器-Swift
//
//  Created by Silence on 2020/11/9.
//  Copyright © 2020 Silence. All rights reserved.
//

import UIKit
import Photos

open class PhotoPickerController: UINavigationController {
    public weak var pickerDelegate: PhotoPickerControllerDelegate?
    public var finishHandler: FinishHandler?
    
    public typealias ActionHandler = (_ result: PickerResult,_ controller: PhotoPickerController, _ completion: @escaping () -> Void) -> Void
    public var actionHandler: ActionHandler?
    
    public var cancelHandler: CancelHandler?
    
    /// 相关配置
    public var config: PickerConfiguration
    
    /// 当前被选择的资源对应的 PhotoAsset 对象数组
    /// 外部预览时的资源数据
    public var selectedAssetArray: [PhotoAsset] {
        get { pickerData.selectedAssets }
        set {
            if previewType == .browser {
                for photoAsset in newValue {
                    photoAsset.isSelected = true
                }
                previewViewController?.previewAssets = newValue
                return
            }
            pickerData.setSelectedAssets(newValue)
        }
    }
    
    open override var childForStatusBarStyle: UIViewController? {
        return topViewController
    }
    
    public var selectedPhotoAssets: [PhotoAsset] { pickerData.selectedPhotoAssets }
    public var selectedVideoAssets: [PhotoAsset] { pickerData.selectedVideoAssets }
    
    /// 是否选中了原图，配置不显示原图按钮时，内部也是根据此属性来判断是否获取原图数据
    public var isOriginal: Bool = false
    
    /// fetch Assets 时的选项配置
    public var options: PHFetchOptions {
        get { fetchData.options }
        set { fetchData.options = newValue }
    }
    
    /// 完成/取消时自动 dismiss ,为false需要自己在代理回调里手动 dismiss
    public var autoDismiss: Bool = true
    
    /// 本地资源数组
    /// 创建本地资源的PhotoAsset然后赋值即可添加到照片列表，如需选中也要添加到selectedAssetArray中
    public var localAssetArray: [PhotoAsset] {
        get { pickerData.localAssets }
        set { pickerData.localAssets = newValue }
    }
    
    /// 相机拍摄存在本地的资源数组（通过相机拍摄的但是没有保存到系统相册）
    /// 可以通过 pickerControllerDidDismiss 得到上一次相机拍摄的资源，然后赋值即可显示上一次相机拍摄的资源
    public var localCameraAssetArray: [PhotoAsset] {
        get { pickerData.localCameraAssets }
        set { pickerData.localCameraAssets = newValue }
    }
    
    /// 刷新数据
    /// 可以在传入 selectedAssetArray 之后重新加载数据将重新设置的被选择的 PhotoAsset 选中
    /// - Parameter assetCollection: 切换显示其他资源集合
    public func reloadData(assetCollection: PhotoAssetCollection?) {
        pickerViewController?.updateAssetCollection(assetCollection)
        reloadAlbumData()
    }
    
    public func mi_reloadData() {
        pickerViewController?.listView.reloadData()
        pickerViewController?.photoToolbar.selectedAssetDidChanged(selectedAssetArray)
        reloadAlbumData()
    }
    
    /// 刷新相册数据，只对单独控制器展示的有效
    public func reloadAlbumData() {
        if splitType.isSplit {
            albumViewController?.listView.reloadData()
        }else {
            if config.albumShowMode.isPopView {
                pickerViewController?.reloadAlbumData()
            }else {
                photoAlbumViewController?.reloadData()
            }
        }
    }
    
    /// 使用其他相机拍摄完之后调用此方法添加
    /// - Parameter photoAsset: 对应的 PhotoAsset 数据
    public func addedCameraPhotoAsset(_ photoAsset: PhotoAsset) {
        pickerViewController?.addedCameraPhotoAsset(photoAsset)
        previewViewController?.addedCameraPhotoAsset(photoAsset)
    }
    
    /// 删除当前预览的 Asset
    public func deleteCurrentPreviewPhotoAsset() {
        previewViewController?.deleteCurrentPhotoAsset()
    }
    
    /// 预览界面添加本地资源
    /// - Parameter photoAsset: 对应的 PhotoAsset 数据
    public func previewAddedCameraPhotoAsset(_ photoAsset: PhotoAsset) {
        previewViewController?.addedCameraPhotoAsset(photoAsset)
    }
    
    /// 获取预览界面当前显示的 image 视图
    /// - Returns: 对应的 UIImageView
    public func getCurrentPreviewImageView() -> UIImageView? {
        if let previewVC = previewViewController,
           let cell = previewVC.getCell(for: previewVC.currentPreviewIndex) {
            return cell.scrollContentView.imageView
        }
        return nil
    }
    
    /// 预览界面的数据
    public var previewAssets: [PhotoAsset] {
        if let assets = previewViewController?.previewAssets {
            return assets
        }
        return []
    }
    
    /// 预览界面当前显示的页数
    public var currentPreviewIndex: Int {
        if let index = previewViewController?.currentPreviewIndex {
            return index
        }
        return 0
    }
    
    /// 获取预览界面当前显示的 image 视图
    /// - Returns: 对应的 UIImageView
    public var currentPreviewImageView: UIImageView? {
        getCurrentPreviewImageView()
    }
    
    /// UISplitViewController 中的相册列表控制器
    public var albumViewController: AlbumViewController? {
        getViewController(
            for: AlbumViewController.self
        ) as? AlbumViewController
    }
    
    /// 相册列表
    public var photoAlbumViewController: PhotoAlbumController? {
        for case let vc as PhotoAlbumController in viewControllers {
            return vc
        }
        return nil
    }
    
    /// 照片列表
    public var pickerViewController: PhotoPickerViewController? {
        getViewController(
            for: PhotoPickerViewController.self
        ) as? PhotoPickerViewController
    }
    
    /// 照片预览
    public var previewViewController: PhotoPreviewViewController? {
        getViewController(
            for: PhotoPreviewViewController.self
        ) as? PhotoPreviewViewController
    }
    
    public var dismissPanGestureRecognizer: UIGestureRecognizer? {
        dismissInteractiveTransition?.gestureRecognizer
    }
    
    public var isBrowserTransitioning: Bool = false {
        didSet {
            previewViewController?.isTransitioning = isBrowserTransitioning
        }
    }
    
    /// 当前处于的外部预览
    public let previewType: PhotoPreviewType
    
    public override var modalPresentationStyle: UIModalPresentationStyle {
        didSet {
            if previewType != .none && modalPresentationStyle == .custom && !splitType.isSplit {
                transitioningDelegate = self
                modalPresentationCapturesStatusBarAppearance = true
            }
        }
    }
    
    public override var preferredStatusBarStyle: UIStatusBarStyle {
        if PhotoManager.isDark {
            return .lightContent
        }
        return config.statusBarStyle
    }
    
    public override var prefersStatusBarHidden: Bool {
        if config.prefersStatusBarHidden {
            return true
        }else {
            if let prefersStatusBarHidden = topViewController?.prefersStatusBarHidden {
                return prefersStatusBarHidden
            }
            return false
        }
    }
    
    open override var shouldAutorotate: Bool {
        config.shouldAutorotate
    }
    
    open override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        config.supportedInterfaceOrientations
    }
    
    public override var preferredStatusBarUpdateAnimation: UIStatusBarAnimation {
        if let animation = topViewController?.preferredStatusBarUpdateAnimation {
            return animation
        }
        return .fade
    }
    
    public override func viewDidLoad() {
        super.viewDidLoad()
        if PhotoManager.isRTL {
            navigationBar.semanticContentAttribute = .forceRightToLeft
        }else {
            navigationBar.semanticContentAttribute = .forceLeftToRight
        }
        setupDelegate()
        PhotoManager.shared.indicatorType = config.indicatorType
        PhotoManager.shared.loadNetworkVideoMode = config.previewView.loadNetworkVideoMode
        PhotoManager.shared.thumbnailLoadMode = .complete
        initViews()
        if splitType.isSplit, splitType == .picker {
            requestAuthorization()
            return
        }
        if previewType == .none {
            requestAuthorization()
        }
        setupInteractiveTransition()
    }
    
    public override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        let status = AssetPermissionsUtil.authorizationStatus
        if status.rawValue >= 1 && status.rawValue < 3 {
            if let view = splitViewController?.view {
                deniedView.frame = view.bounds
            }else {
                deniedView.frame = view.bounds
            }
        }
    }
    
    public override func present(
        _ viewControllerToPresent: UIViewController,
        animated flag: Bool,
        completion: (() -> Void)? = nil
    ) {
        if isFirstAuthorization &&
            viewControllerToPresent is UIImagePickerController {
            viewControllerToPresent.modalPresentationStyle = .fullScreen
            isFirstAuthorization = false
        }
        super.present(
            viewControllerToPresent,
            animated: flag,
            completion: completion
        )
    }
    
    public func dismiss(_ animated: Bool, completion: (() -> Void)? = nil) {
        dismiss(animated: animated, completion: completion)
    }
    
    open override func dismiss(animated flag: Bool, completion: (() -> Void)? = nil) {
        if let viewController = presentedViewController as? PhotoPickerController,
           config.photoList.previewStyle == .present {
            presentingViewController?.dismiss(animated: flag, completion: completion)
            return
        }
        super.dismiss(animated: flag, completion: completion)
    }
    
    public override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        if #available(iOS 13.0, *) {
            if traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
                setupColor()
            }
        }
    }
    
    public override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        if previewType == .none && presentingViewController == nil {
            didDismiss()
        }
    }
    
    let splitType: SplitContentType
    let fetchData: PhotoFetchData
    let pickerData: PhotoPickerData
    var deniedView: PhotoDeniedAuthorization!
    var disablesCustomDismiss = false
    var interactiveTransition: PhotoBrowserInteractiveTransition?
    var dismissInteractiveTransition: PhotoPickerControllerInteractiveTransition?
    var isDismissed: Bool = false
    private var pickerTask: Any?
    private var isFirstAuthorization: Bool = false
    var isFetchAssetCollection: Bool = false
    private var isAsyncPicker: Bool = false
    private var isAsyncPickerAutoDismiss: Bool = false
    
    init() {
        self.config = .init()
        previewType = .none
        pickerData = config.pickerData.init(config: config)
        fetchData = config.fetchdata.init(config: config, pickerData: pickerData)
        splitType = .none
        super.init(nibName: nil, bundle: nil)
    }
    
    /// 选择资源初始化
    /// - Parameter config: 相关配置
    public convenience init(config: PickerConfiguration, finish: FinishHandler? = nil, cancel: CancelHandler? = nil) {
        self.init(picker: config)
        self.finishHandler = finish
        self.cancelHandler = cancel
    }
    
    /// 选择资源初始化
    /// - Parameter config: 相关配置
    public init(picker config: PickerConfiguration, delegate: PhotoPickerControllerDelegate? = nil) {
        PhotoManager.shared.appearanceStyle = config.appearanceStyle
        PhotoManager.shared.createLanguageBundle(languageType: config.languageType)
        self.config = config
        previewType = .none
        pickerData = config.pickerData.init(config: config)
        fetchData = config.fetchdata.init(config: config, pickerData: pickerData)
        splitType = .none
        super.init(nibName: nil, bundle: nil)
        pickerData.delegate = self
        fetchData.delegate = self
        if config.selectMode == .single {
            if config.previewView.bottomView.isHiddenOriginalButton {
                isOriginal = true
            }else {
                isOriginal = config.isSelectedOriginal
            }
        }else {
            if config.photoList.bottomView.isHiddenOriginalButton, config.previewView.bottomView.isHiddenOriginalButton {
                isOriginal = true
            }else {
                isOriginal = config.isSelectedOriginal
            }
        }
        autoDismiss = config.isAutoBack
        modalPresentationStyle = config.modalPresentationStyle
        pickerDelegate = delegate
        var photoVC: UIViewController
        switch config.albumShowMode {
        case .normal:
            let vc = config.albumController.albumController.init(config: config)
            vc.delegate = self
            photoVC = vc
        default:
            photoVC = PhotoPickerViewController(config: config)
        }
        self.viewControllers = [photoVC]
    }
    
    /// 外部预览资源初始化
    /// - Parameters:
    ///   - config: 相关配置
    ///   - currentIndex: 当前预览的下标
    ///   - modalPresentationStyle: 默认 custom 样式，框架自带动画效果
    public init(
        preview config: PickerConfiguration,
        previewAssets: [PhotoAsset],
        currentIndex: Int,
        selectedAssets: [PhotoAsset] = [],
        previewType: PhotoPreviewType = .browser,
        modalPresentationStyle: UIModalPresentationStyle = .custom,
        delegate: PhotoPickerControllerDelegate? = nil
    ) {
        PhotoManager.shared.appearanceStyle = config.appearanceStyle
        PhotoManager.shared.createLanguageBundle(languageType: config.languageType)
        self.config = config
        self.previewType = previewType
        pickerData = config.pickerData.init(config: config)
        fetchData = config.fetchdata.init(config: config, pickerData: pickerData)
        splitType = .none
        super.init(nibName: nil, bundle: nil)
        self.config.adaptiveBarAppearance = false
        pickerData.delegate = self
        fetchData.delegate = self
        if config.selectMode == .single {
            if config.previewView.bottomView.isHiddenOriginalButton {
                isOriginal = true
            }else {
                isOriginal = config.isSelectedOriginal
            }
        }else {
            if config.photoList.bottomView.isHiddenOriginalButton, config.previewView.bottomView.isHiddenOriginalButton {
                isOriginal = true
            }else {
                isOriginal = config.isSelectedOriginal
            }
        }
        autoDismiss = config.isAutoBack
        pickerDelegate = delegate
        selectedAssetArray = selectedAssets
        let vc = PhotoPreviewViewController(config: self.config)
        vc.previewType = previewType
        vc.previewAssets = previewAssets
        vc.currentPreviewIndex = currentIndex
        self.viewControllers = [vc]
        self.modalPresentationStyle = modalPresentationStyle
        if modalPresentationStyle == .custom {
            transitioningDelegate = self
            modalPresentationCapturesStatusBarAppearance = true
        }
    }
    
    public init(
        splitPicker config: PickerConfiguration,
        delegate: PhotoPickerControllerDelegate? = nil
    ) {
        var tmpConfig = config
        tmpConfig.albumShowMode = .popup
        if tmpConfig.modalPresentationStyle == .fullScreen {
            tmpConfig.photoList.previewStyle = .present
            #if HXPICKER_ENABLE_EDITOR
            tmpConfig.editorJumpStyle = .present(.custom)
            #endif
        }
        self.config = tmpConfig
        PhotoManager.shared.appearanceStyle = self.config.appearanceStyle
        PhotoManager.shared.createLanguageBundle(languageType: self.config.languageType)
        splitType = .picker
        previewType = .none
        pickerData = self.config.pickerData.init(config: self.config)
        fetchData = self.config.fetchdata.init(config: self.config, pickerData: pickerData)
        super.init(nibName: nil, bundle: nil)
        pickerData.delegate = self
        fetchData.delegate = self
        if config.selectMode == .single {
            if config.previewView.bottomView.isHiddenOriginalButton {
                isOriginal = true
            }else {
                isOriginal = self.config.isSelectedOriginal
            }
        }else {
            if config.photoList.bottomView.isHiddenOriginalButton, config.previewView.bottomView.isHiddenOriginalButton {
                isOriginal = true
            }else {
                isOriginal = self.config.isSelectedOriginal
            }
        }
        autoDismiss = self.config.isAutoBack
        pickerDelegate = delegate
        modalPresentationStyle = config.modalPresentationStyle
        let vc = PhotoPickerViewController(config: self.config)
        self.viewControllers = [vc]
    }
    
    init(
        splitAlbum config: PickerConfiguration
    ) {
        splitType = .album
        self.config = config
        previewType = .none
        pickerData = config.pickerData.init(config: config)
        fetchData = config.fetchdata.init(config: config, pickerData: pickerData)
        super.init(nibName: nil, bundle: nil)
        fetchData.delegate = self
        modalPresentationStyle = config.modalPresentationStyle
        let vc = AlbumViewController(config: config)
        self.viewControllers = [vc]
    }
    
    required public init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        PhotoManager.shared.thumbnailLoadMode = .complete
        PhotoManager.shared.firstLoadAssets = false
        PHPhotoLibrary.shared().unregisterChangeObserver(self)
        HXLog("PhotoPickerController deinited 👍")
    }
}

extension PhotoPickerController {
    func initViews() {
        setupColor()
        deniedView = config.notAuthorized.notAuthorizedView.init(config: config)
        deniedView.pickerDelegate = self
        if let view = splitViewController?.view {
            deniedView.frame = view.bounds
        }else {
            deniedView.frame = view.bounds
        }
    }
    
    func setupDelegate() {
        delegate = self
    }
    
    func setupColor() {
        if #available(iOS 13.0, *), config.appearanceStyle == .normal {
            overrideUserInterfaceStyle = .light
        }
        if modalPresentationStyle != .custom {
            setupBackgroundColor()
        }
        let isDark = PhotoManager.isDark
        let titleTextAttributes: [NSAttributedString.Key : Any] = [
            .foregroundColor:
                isDark ? config.navigationTitleDarkColor : config.navigationTitleColor
        ]
        navigationBar.titleTextAttributes = titleTextAttributes
        let tintColor = isDark ? config.navigationDarkTintColor : config.navigationTintColor
        navigationBar.tintColor = tintColor
        let barStyle = isDark ? config.navigationBarDarkStyle : config.navigationBarStyle
        navigationBar.barStyle = barStyle
        navigationBar.isTranslucent = config.navigationBarIsTranslucent
        
        let navigationBackgroundImage = isDark ? config.navigationBackgroundDarkImage : config.navigationBackgroundImage
        let navigationBackgroundColor = isDark ? config.navigationBackgroundDarkColor : config.navigationBackgroundColor
        if let image = navigationBackgroundImage {
            navigationBar.setBackgroundImage(image, for: .default)
        }
        if let color = navigationBackgroundColor {
            navigationBar.backgroundColor = color
        }
        if #available(iOS 15.0, *), config.adaptiveBarAppearance {
            let appearance = UINavigationBarAppearance()
            appearance.titleTextAttributes = titleTextAttributes
            switch barStyle {
            case .`default`:
                appearance.backgroundEffect = UIBlurEffect(style: .extraLight)
            default:
                appearance.backgroundEffect = UIBlurEffect(style: .dark)
            }
            if let image = navigationBackgroundImage {
                appearance.backgroundImage = image
            }
            if let color = navigationBackgroundColor {
                appearance.backgroundColor = color
            }
            navigationBar.standardAppearance = appearance
            navigationBar.scrollEdgeAppearance = appearance
        }
    }
    
    func setupBackgroundColor() {
        view.backgroundColor = PhotoManager.isDark ?
            config.navigationViewBackgroudDarkColor :
            config.navigationViewBackgroundColor
    }
    
    func setupInteractiveTransition() {
        if previewType == .none {
            if modalPresentationStyle == .fullScreen &&
                config.albumShowMode.isPop &&
                config.allowCustomTransitionAnimation {
                modalPresentationCapturesStatusBarAppearance = true
                switch config.pickerPresentStyle {
                case .present(let rightSwipe):
                    transitioningDelegate = self
                    if let rightSwipe = rightSwipe {
                        dismissInteractiveTransition = config.pickerInteractiveTransitionAnimator.init(
                            type: .dismiss,
                            pickerController: self,
                            triggerRange: rightSwipe.triggerRange
                        )
                    }
                case .push(let rightSwipe):
                    transitioningDelegate = self
                    if let rightSwipe = rightSwipe {
                        dismissInteractiveTransition = config.pickerInteractiveTransitionAnimator.init(
                            type: .pop,
                            pickerController: self,
                            triggerRange: rightSwipe.triggerRange
                        )
                    }
                default:
                    break
                }
            }
        }else {
            if modalPresentationStyle == .custom && config.allowCustomTransitionAnimation {
                interactiveTransition = config.browserInteractiveTransitionAnimator.init(pickerController: self)
            }
        }
    }
}

extension PhotoPickerController {
    private func requestAuthorization() {
        if splitType == .album {
            return
        }
        if !config.allowLoadPhotoLibrary {
            fetchData.fetchCameraAssetCollection()
            return
        }
        let status = AssetPermissionsUtil.authorizationStatus
        if status.rawValue >= 3 {
            // 有权限
            PHPhotoLibrary.shared().register(self)
            if !PhotoManager.shared.didRegisterObserver {
                PhotoManager.HUDView.show(with: nil, delay: 0, animated: true, addedTo: view)
            }else {
                PhotoManager.HUDView.show(with: nil, delay: 0.15, animated: true, addedTo: view)
            }
            fetchData.fetchCameraAssetCollection()
        }else if status.rawValue >= 1 {
            // 无权限
            if splitType.isSplit {
                splitViewController?.view.addSubview(deniedView)
            }else {
                view.addSubview(deniedView)
            }
        }else {
            // 用户还没做出选择，请求权限
            isFirstAuthorization = true
            AssetPermissionsUtil.requestAuthorization { _ in
                self.requestAuthorization()
                if self.config.albumShowMode.isPop {
                    self.pickerViewController?.initToolbar()
                }
                self.albumViewController?.reloadData()
                self.pickerViewController?.reloadAlbumData()
                PhotoManager.shared.registerPhotoChangeObserver()
            }
        }
    }
    private func getViewController(for viewControllerClass: UIViewController.Type) -> UIViewController? {
        for vc in viewControllers where vc.isMember(of: viewControllerClass) {
            return vc
        }
        return nil
    }
    private func didDismiss() {
        if #available(iOS 13.0, *) {
            if let task = pickerTask as? Task<(), Never> {
                task.cancel()
                pickerTask = nil
            }
        }
        #if HXPICKER_ENABLE_EDITOR
        pickerData.removeAllEditedPhotoAsset()
        #endif
        var cameraAssetArray: [PhotoAsset] = []
        for photoAsset in localCameraAssetArray {
            if let cameraAsset = photoAsset.cameraAsset {
                cameraAssetArray.append(cameraAsset)
            }
        }
        PhotoManager.shared.saveCameraPreview()
        pickerDelegate?.pickerController(self, didDismissComplete: cameraAssetArray)
        if !isDismissed {
            cancelHandler?(self)
        }
    }
}

extension PhotoPickerController: UINavigationControllerDelegate, PhotoAlbumControllerDelegate {
    public func navigationController(_ navigationController: UINavigationController, didShow viewController: UIViewController, animated: Bool) {
        if viewController is PhotoAlbumController {
            if fetchData.assetCollections.isEmpty, !isFetchAssetCollection {
                isFetchAssetCollection = true
                PhotoManager.HUDView.show(with: nil, delay: 0, animated: true, addedTo: viewController.view)
                fetchData.fetchAssetCollections()
            }
        }
    }
    
    public func albumController(_ albumController: PhotoAlbumController, didSelectedWith assetCollection: PhotoAssetCollection) {
        let vc = PhotoPickerViewController(config: config)
        vc.assetCollection = assetCollection
        vc.showLoading = true
        pushViewController(vc, animated: true)
    }
    
    public func albumController(willAppear viewController: PhotoAlbumController) {
        viewControllersWillAppear(viewController)
    }
    public func albumController(didAppear viewController: PhotoAlbumController) {
        viewControllersDidAppear(viewController)
    }
    public func albumController(willDisappear viewController: PhotoAlbumController) {
        viewControllersWillDisappear(viewController)
    }
    public func albumController(didDisappear viewController: PhotoAlbumController) {
        viewControllersDidDisappear(viewController)
    }
}

@available(iOS 13.0.0, *)
public extension PhotoPickerController {
    /// 选择资源
    /// - Parameters:
    ///   - config: 选择器配置
    ///   - delegate: 选择器代理回调
    ///   - compression: 压缩参数，不传则根据内部 isOriginal 判断是否压缩
    ///   - fromVC: 来源控制器
    ///   - fileConfig: 指定获取URL的路径
    /// - Returns: 获取对应的对象数组
    @MainActor
    static func picker<T: PhotoAssetObject>(
        _ config: PickerConfiguration,
        selectedAssets: [PhotoAsset] = [],
        delegate: PhotoPickerControllerDelegate? = nil,
        compression: PhotoAsset.Compression? = nil,
        fromVC: UIViewController? = nil,
        toFile fileConfig: PickerResult.FileConfigHandler? = nil
    ) async throws -> [T] {
        let vc = show(config, selectedAssets: selectedAssets, isSplit: UIDevice.isPad, delegate: delegate, fromVC: fromVC)
        vc.isAsyncPicker = true
        return try await vc.pickerAsset(compression, toFile: fileConfig)
    }
    
    @MainActor
    static func picker(
        _ config: PickerConfiguration,
        selectedAssets: [PhotoAsset] = [],
        delegate: PhotoPickerControllerDelegate? = nil,
        fromVC: UIViewController? = nil
    ) async throws -> PickerResult {
        let vc = show(config, selectedAssets: selectedAssets, isSplit: UIDevice.isPad, delegate: delegate, fromVC: fromVC)
        vc.isAsyncPicker = true
        return try await vc.picker()
    }
    
    @MainActor
    static func picker(
        _ config: PickerConfiguration,
        selectedAssets: [PhotoAsset] = [],
        delegate: PhotoPickerControllerDelegate? = nil,
        targetSize: CGSize,
        targetMode: HX.ImageTargetMode = .fill,
        fromVC: UIViewController? = nil,
        toFile fileConfig: PickerResult.FileConfigHandler? = nil
    ) async throws -> [UIImage] {
        let vc = show(config, selectedAssets: selectedAssets, isSplit: UIDevice.isPad, delegate: delegate, fromVC: fromVC)
        vc.isAsyncPicker = true
        return try await vc.pickerImage(targetSize: targetSize, targetMode: targetMode, toFile: fileConfig)
    }
    
    @MainActor
    static func show(
        _ config: PickerConfiguration,
        selectedAssets: [PhotoAsset] = [],
        isSplit: Bool = false,
        delegate: PhotoPickerControllerDelegate? = nil,
        fromVC: UIViewController? = nil
    ) -> PhotoPickerController {
        let topVC: UIViewController?
        if let fromVC = fromVC {
            topVC = fromVC
        }else {
            topVC = UIViewController.topViewController
        }
        let pickerController: PhotoPickerController
        if !isSplit {
            pickerController = PhotoPickerController(picker: config, delegate: delegate)
            pickerController.selectedAssetArray = selectedAssets
            topVC?.present(pickerController, animated: true)
        }else {
            pickerController = PhotoPickerController(splitPicker: config, delegate: delegate)
            pickerController.selectedAssetArray = selectedAssets
            let splitController = PhotoSplitViewController(picker: pickerController)
            topVC?.present(splitController, animated: true)
        }
        if pickerController.autoDismiss {
            pickerController.isAsyncPickerAutoDismiss = true
        }
        pickerController.autoDismiss = false
        return pickerController
    }
    
    func picker() async throws -> PickerResult {
        try await withCheckedThrowingContinuation { continuation in
            var isDimissed: Bool = false
            let isAsyncPicker = isAsyncPicker
            let isAsyncPickerAutoDismiss = isAsyncPickerAutoDismiss
            finishHandler = {
                if isDimissed { return }
                isDimissed = true
                continuation.resume(with: .success($0))
                if isAsyncPicker || isAsyncPickerAutoDismiss {
                    $1.dismiss(true)
                }
            }
            cancelHandler = {
                if isDimissed { return }
                isDimissed = true
                continuation.resume(with: .failure(PickerError.canceled))
                $0.dismiss(true)
            }
        }
    }
    
    /// 获取资源
    /// - Parameters:
    ///   - compression: 压缩参数，不传则根据内部 isOriginal 判断是否压缩
    ///   - fileConfig: 指定获取URL的路径
    /// - Returns: 获取对应的对象数组
    func pickerAsset<T: PhotoAssetObject>(
       _ compression: PhotoAsset.Compression? = nil,
       toFile fileConfig: PickerResult.FileConfigHandler? = nil
    ) async throws -> [T] {
       try await withCheckedThrowingContinuation { continuation in
           var isDimissed: Bool = false
           let isAsyncPicker = isAsyncPicker
           let isAsyncPickerAutoDismiss = isAsyncPickerAutoDismiss
           finishHandler = { [weak self] result, controller in
               guard let self = self else { return }
               if isDimissed { return }
               isDimissed = true
               if result.photoAssets.isEmpty {
                   continuation.resume(with: .failure(PickerError.canceled))
                   controller.dismiss(true)
                   return
               }
               PhotoManager.HUDView.show(with: nil, delay: 0, animated: true, addedTo: self.view)
               self.pickerTask = Task {
                   do {
                       let objects: [T] = try await result.objects(compression, toFile: fileConfig)
                       if !Task.isCancelled {
                           continuation.resume(with: .success(objects))
                       }else {
                           self.pickerTask = nil
                           continuation.resume(with: .failure(PickerError.canceled))
                           return
                       }
                   } catch {
                       continuation.resume(with: .failure(error))
                   }
                   self.pickerTask = nil
                   PhotoManager.HUDView.dismiss(delay: 0, animated: true, for: self.view)
                   if isAsyncPicker || isAsyncPickerAutoDismiss {
                       controller.dismiss(true)
                   }
               }
           }
           cancelHandler = { controller in
               if isDimissed { return }
               isDimissed = true 
               continuation.resume(with: .failure(PickerError.canceled))
               controller.dismiss(true)
           }
       }
    }
    
    /// 获取 UIImage 对象数组
    /// - Parameters:
    ///   - targetSize: 指定`imageSize`
    ///   - targetMode: 裁剪模式
    /// - Returns: `UIImage` 对象数组
    func pickerImage(
        targetSize: CGSize,
        targetMode: HX.ImageTargetMode = .fill,
        toFile fileConfig: PickerResult.FileConfigHandler? = nil
    ) async throws -> [UIImage] {
       try await withCheckedThrowingContinuation { continuation in
           var isDimissed: Bool = false
           let isAsyncPicker = isAsyncPicker
           let isAsyncPickerAutoDismiss = isAsyncPickerAutoDismiss
           finishHandler = { [weak self] result, controller in
               guard let self = self else { return }
               if isDimissed { return }
               isDimissed = true
               if result.photoAssets.isEmpty {
                   continuation.resume(with: .failure(PickerError.canceled))
                   controller.dismiss(true)
                   return
               }
               PhotoManager.HUDView.show(with: nil, delay: 0, animated: true, addedTo: self.view)
               self.pickerTask = Task {
                   do {
                       let images: [UIImage] = try await result.images(targetSize: targetSize, targetMode: targetMode)
                       if !Task.isCancelled {
                           continuation.resume(with: .success(images))
                       }else {
                           self.pickerTask = nil
                           continuation.resume(with: .failure(PickerError.canceled))
                           return
                       }
                   } catch {
                       continuation.resume(with: .failure(error))
                   }
                   self.pickerTask = nil
                   PhotoManager.HUDView.dismiss(delay: 0, animated: true, for: self.view)
                   if isAsyncPicker || isAsyncPickerAutoDismiss {
                       controller.dismiss(true)
                   }
               }
           }
           cancelHandler = { controller in
               if isDimissed { return }
               isDimissed = true
               continuation.resume(with: .failure(PickerError.canceled))
               controller.dismiss(true)
           }
       }
   }
}

extension PhotoPickerController {
    public typealias FinishHandler = (PickerResult, PhotoPickerController) -> Void
    public typealias CancelHandler = (PhotoPickerController) -> Void
    
    enum SplitContentType {
        case none
        case album
        case picker
        
        var isSplit: Bool {
            self != .none
        }
    }
}
